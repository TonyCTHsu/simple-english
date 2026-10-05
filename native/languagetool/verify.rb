#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "net/http"
require "rexml/document"
require "socket"
require "tempfile"
require "uri"

require_relative "../../lib/simple_english/setup/languagetool"
require_relative "../../lib/simple_english/lint/markdown"

unless (1..2).cover?(ARGV.length)
  abort "usage: verify.rb CLASSPATH [NATIVE_EXECUTABLE]"
end

root = File.expand_path("../..", __dir__)
rules_file = File.join(root, "rules/simple-english.xml")
document = REXML::Document.new(File.read(rules_file))
rules = {}
REXML::XPath.match(document, "//rulegroup | //rule").each do |rule|
  id = rule.attributes["id"]
  next if id.nil?

  rules[id] = {incorrect: [], correct: []}
  REXML::XPath.match(rule, ".//example").each do |example|
    type = (example.attributes["type"] == "incorrect") ? :incorrect : :correct
    rules[id][type] << REXML::XPath.match(example, ".//text()").join
  end
end

class HTTPRunner
  def initialize(*command)
    @port = available_port
    @log = Tempfile.new("languagetool-server")
    @pid = Process.spawn(*command, "--port", @port.to_s, out: @log, err: @log)
    wait_until_ready
  end

  def check(payload)
    params = {
      "language" => "en",
      "enabledRules" => SimpleEnglish::LanguageTool.rule_ids.join(","),
      "enabledOnly" => "true"
    }
    if payload.key?("text")
      params["text"] = payload.fetch("text")
    elsif payload.key?("annotation")
      params["data"] = JSON.generate(payload)
    end
    response = Net::HTTP.post_form(URI("http://localhost:#{@port}/v2/check"), params)
    body = begin
      JSON.parse(response.body)
    rescue JSON::ParserError
      response.body
    end
    {"status" => response.code.to_i, "body" => body}
  end

  def close
    Process.kill("TERM", @pid)
    Process.wait(@pid)
  rescue Errno::ESRCH, Errno::ECHILD
    nil
  ensure
    @log.close!
  end

  private

  def available_port
    server = TCPServer.new("127.0.0.1", 0)
    server.addr[1]
  ensure
    server&.close
  end

  def wait_until_ready
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 60
    loop do
      TCPSocket.open("127.0.0.1", @port, &:close)
      return
    rescue Errno::ECONNREFUSED
      unless running?
        @log.rewind
        abort "#{@pid} exited during startup:\n#{@log.read}"
      end
      if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
        @log.rewind
        abort "#{@pid} did not start:\n#{@log.read}"
      end
      sleep 0.1
    end
  end

  def running?
    Process.kill(0, @pid)
    true
  rescue Errno::ESRCH
    false
  end
end

incorrect = rules.values.flat_map { |examples| examples[:incorrect] }.join("\n\n")
correct = rules.values.flat_map { |examples| examples[:correct] }.join("\n\n")
annotation = {
  "annotation" => [
    {"markup" => "#", "interpretAs" => " "},
    {"text" => " Load the config from the path"},
    {"markup" => "\nconfig = load(path)\n", "interpretAs" => "\n\n"},
    {"markup" => "#", "interpretAs" => " "},
    {"text" => " The worker didn't write the file."},
    {"markup" => "\n"}
  ]
}
requests = [{"text" => incorrect}, {"text" => correct}, annotation, {"invalid" => true}, annotation]
corpus_pairs = Dir[File.join(root, "test/corpus/*-before.md")].sort.map do |before|
  after = before.sub("-before.md", "-after.md")
  [before, after]
end
corpus_pairs.each do |before, after|
  requests << {"text" => SimpleEnglish::Markdown.strip(File.read(before))}
  requests << {"text" => SimpleEnglish::Markdown.strip(File.read(after))}
end
classpath, executable = ARGV
java = ENV.fetch("JAVA_HOME") { abort "JAVA_HOME must select Java 17 or newer" }
jvm_options = JSON.parse(ENV.fetch("SE_VERIFY_JVM_OPTIONS", "[]"))
unless jvm_options.is_a?(Array) && jvm_options.all? { |option| option.is_a?(String) }
  abort "SE_VERIFY_JVM_OPTIONS must be a JSON array of strings"
end
jvm = HTTPRunner.new(File.join(java, "bin/java"), *jvm_options, "-Dfile.encoding=UTF-8", "-cp", classpath,
  "org.languagetool.server.HTTPServer")
native = HTTPRunner.new(executable) if executable

responses = requests.map.with_index do |request, index|
  jvm_response = jvm.check(request)
  if native
    native_response = native.check(request)
    unless native_response == jvm_response
      abort "Native response #{index + 1} differs from JVM response"
    end
  end
  jvm_response
end
jvm.close
native&.close

incorrect_matches = responses[0].dig("body", "matches")
abort "Correct examples produced findings" unless responses[1].dig("body", "matches").empty?
abort "Malformed request did not produce HTTP 400" unless responses[3].fetch("status") == 400
abort "Process did not recover after malformed request" unless responses[2] == responses[4]
corpus_pairs.each_with_index do |(before, after), index|
  before_matches = responses[5 + (index * 2)].dig("body", "matches")
  after_matches = responses[6 + (index * 2)].dig("body", "matches")
  abort "Corpus after file produced findings: #{File.basename(after)}" unless after_matches.empty?
  next if File.basename(before).start_with?("06-")
  abort "Corpus before file produced no pattern findings: #{File.basename(before)}" if before_matches.empty?
end

fired = incorrect_matches.map { |match| match.fetch("rule").fetch("id") }
missing = rules.keys.reject { |id| fired.include?(id) }
abort "Rules missing from incorrect-example output: #{missing.join(", ")}" unless missing.empty?

annotated_matches = responses[2].dig("body", "matches")
contraction = annotated_matches.find { |match| match.fetch("rule").fetch("id") == "SE_NO_CONTRACTIONS" }
abort "Annotated text did not produce SE_NO_CONTRACTIONS" if contraction.nil?
abort "Annotated UTF-16 range changed" unless [contraction.fetch("offset"), contraction.fetch("length")] == [68, 3]
context = contraction.fetch("context")
matched = context.fetch("text").encode("UTF-16LE").byteslice(context.fetch("offset") * 2,
  context.fetch("length") * 2).force_encoding("UTF-16LE").encode("UTF-8")
abort "Annotated matched text changed" unless matched == "n't"

incorrect_count = rules.values.sum { |examples| examples[:incorrect].size }
correct_count = rules.values.sum { |examples| examples[:correct].size }
mode = native ? "stock HTTP native/JVM parity" : "stock HTTP JVM exercise"
puts "#{rules.size} rules: #{incorrect_count} incorrect examples, #{correct_count} correct examples, #{corpus_pairs.size} corpus pairs, #{mode} PASS"
