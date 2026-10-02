#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "open3"
require "rexml/document"

require_relative "../../lib/simple_english/markdown"

abort "usage: verify.rb CLASSPATH NATIVE_EXECUTABLE" unless ARGV.length == 2

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

class PersistentRunner
  def initialize(*command)
    @input, @output, @error, @wait = Open3.popen3(*command)
  end

  def check(request)
    @input.puts(JSON.generate(request))
    response = @output.gets
    abort "#{@wait.pid} closed stdout before responding" if response.nil?

    JSON.parse(response)
  end

  def close
    @input.close
    extra_output = @output.read
    stderr = @error.read
    status = @wait.value
    abort "Unexpected extra output: #{extra_output}" unless extra_output.empty?
    abort "Process failed:\n#{stderr}" unless status.success? && stderr.empty?
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
jvm = PersistentRunner.new(File.join(java, "bin/java"), "-Dfile.encoding=UTF-8", "-cp", classpath,
  "org.simpleenglish.NativeLanguageTool")
native = PersistentRunner.new(executable)

responses = requests.map.with_index do |request, index|
  jvm_response = jvm.check(request)
  native_response = native.check(request)
  abort "Native response #{index + 1} differs from JVM response" unless native_response == jvm_response

  native_response
end
jvm.close
native.close

incorrect_matches = responses[0].fetch("matches")
abort "Correct examples produced findings" unless responses[1].fetch("matches").empty?
abort "Malformed request did not produce an error" unless responses[3].key?("error")
abort "Process did not recover after malformed request" unless responses[2] == responses[4]
corpus_pairs.each_with_index do |(before, after), index|
  before_matches = responses[5 + (index * 2)].fetch("matches")
  after_matches = responses[6 + (index * 2)].fetch("matches")
  abort "Corpus after file produced findings: #{File.basename(after)}" unless after_matches.empty?
  next if File.basename(before).start_with?("06-")
  abort "Corpus before file produced no pattern findings: #{File.basename(before)}" if before_matches.empty?
end

fired = incorrect_matches.map { |match| match.fetch("rule").fetch("id") }
missing = rules.keys.reject { |id| fired.include?(id) }
abort "Rules missing from incorrect-example output: #{missing.join(", ")}" unless missing.empty?

annotated_matches = responses[2].fetch("matches")
contraction = annotated_matches.find { |match| match.fetch("rule").fetch("id") == "SE_NO_CONTRACTIONS" }
abort "Annotated text did not produce SE_NO_CONTRACTIONS" if contraction.nil?
abort "Annotated UTF-16 range changed" unless [contraction.fetch("offset"), contraction.fetch("length")] == [68, 3]
abort "Annotated matched text changed" unless contraction.dig("context", "text") == "n't"

incorrect_count = rules.values.sum { |examples| examples[:incorrect].size }
correct_count = rules.values.sum { |examples| examples[:correct].size }
puts "#{rules.size} rules: #{incorrect_count} incorrect examples, #{correct_count} correct examples, #{corpus_pairs.size} corpus pairs, persistent native/JVM parity PASS"
