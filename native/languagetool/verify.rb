#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "open3"
require "rexml/document"

abort "usage: verify.rb SHADED_JAR NATIVE_EXECUTABLE" unless ARGV.length == 2

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

incorrect = rules.values.flat_map { |examples| examples[:incorrect] }.join("\n\n")
correct = rules.values.flat_map { |examples| examples[:correct] }.join("\n\n")
java = File.join(ENV.fetch("JAVA_HOME"), "bin/java")
jar, executable = ARGV

def run(*command)
  stdout, stderr, status = Open3.capture3(*command)
  abort "Command failed: #{command.first}\n#{stderr}" unless status.success?
  abort "Unexpected stderr from #{command.first}:\n#{stderr}" unless stderr.empty?

  stdout
end

def check_both(java, jar, executable, rules_file, mode, input)
  jvm = run(java, "-Dfile.encoding=UTF-8", "-jar", jar, rules_file, mode, input)
  native = run(executable, rules_file, mode, input)
  abort "Native #{mode} output differs from JVM output" unless native == jvm

  JSON.parse(native).fetch("matches")
end

incorrect_matches = check_both(java, jar, executable, rules_file, "--text", incorrect)
correct_matches = check_both(java, jar, executable, rules_file, "--text", correct)
abort "Correct examples produced findings" unless correct_matches.empty?

fired = incorrect_matches.map { |match| match.fetch("rule").fetch("id") }
missing = rules.keys.reject { |id| fired.include?(id) }
abort "Rules missing from incorrect-example output: #{missing.join(", ")}" unless missing.empty?

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
annotated_matches = check_both(java, jar, executable, rules_file, "--data", JSON.generate(annotation))
contraction = annotated_matches.find { |match| match.fetch("rule").fetch("id") == "SE_NO_CONTRACTIONS" }
abort "Annotated text did not produce SE_NO_CONTRACTIONS" if contraction.nil?
abort "Annotated UTF-16 range changed" unless [contraction.fetch("offset"), contraction.fetch("length")] == [68, 3]
abort "Annotated context is missing" unless contraction.dig("context", "text")&.include?("didn't")

incorrect_count = rules.values.sum { |examples| examples[:incorrect].size }
correct_count = rules.values.sum { |examples| examples[:correct].size }
puts "#{rules.size} rules: #{incorrect_count} incorrect examples, #{correct_count} correct examples, plain and annotated native/JVM parity PASS"
