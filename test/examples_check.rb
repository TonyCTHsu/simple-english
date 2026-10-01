# frozen_string_literal: true

# Check that every rule in rules/simple-english.xml fires on its own
# incorrect example and stays silent on its correct example.
#
# Stands in for LanguageTool's testrules, which cannot test external
# rule files.
#
# Usage: run `se serve` (or let the first lint start it), then
#   ruby test/examples_check.rb

require "rexml/document"
require_relative "../lib/simple_english"

module ExampleChecks
  module_function

  def rule_examples
    document = REXML::Document.new(File.read(SimpleEnglish::LanguageTool::RULES_FILE))
    rules = {}
    REXML::XPath.match(document, "//rulegroup | //rule").each do |rule|
      id = rule.attributes["id"]
      next if id.nil? # rules nested inside a rulegroup

      rules[id] = {incorrect: [], correct: []}
      REXML::XPath.match(rule, ".//example").each do |example|
        text = REXML::XPath.match(example, ".//text()").join
        type = (example.attributes["type"] == "incorrect") ? :incorrect : :correct
        rules[id][type] << text
      end
    end
    rules
  end

  def check
    SimpleEnglish::Client.ensure_up
    rules = rule_examples
    # rule_ids feeds enabledRules on every lint request. It is a regex
    # scan and this is the real parser. If the two disagree, the daemon
    # enables a rule set the XML does not define, or misses one it does.
    ids = rules.keys
    regex_ids = SimpleEnglish::LanguageTool.rule_ids
    unless ids.sort == regex_ids.sort
      puts "FAIL rule_ids and the rules XML disagree: " \
        "#{(ids - regex_ids).inspect} vs #{(regex_ids - ids).inspect}"
      return false
    end
    fired = SimpleEnglish::Client.lint(rules.values.flat_map { |e| e[:incorrect] }.join("\n\n"))
      .map(&:rule).uniq
    silent = SimpleEnglish::Client.lint(rules.values.flat_map { |e| e[:correct] }.join("\n\n"))
      .map(&:rule).uniq

    failures = []
    rules.each_key do |id|
      failures << "#{id} does not fire on its incorrect example" unless fired.include?(id)
    end
    silent.each do |id|
      failures << "#{id} fires on correct example text"
    end
    failures.each { |failure| puts "FAIL #{failure}" }
    incorrect_count = rules.values.sum { |examples| examples[:incorrect].size }
    correct_count = rules.values.sum { |examples| examples[:correct].size }
    puts "#{rules.size} rules: #{incorrect_count} incorrect examples, " \
         "#{correct_count} correct examples, #{failures.empty? ? "ALL PASS" : "FAILURES"}"
    failures.empty?
  end
end

exit(ExampleChecks.check ? 0 : 1) if $PROGRAM_NAME == __FILE__
