# frozen_string_literal: true

# Run the corpus pairs in test/corpus through the daemon.
#
# Usage: run `se serve` (or let the first lint start it), then
#   ruby test/corpus_check.rb

require_relative "../lib/simple_english"

pairs = Dir.glob(File.expand_path("corpus/*-before.md", __dir__)).sort
failed = pairs.flat_map do |before|
  after = before.sub(/-before\.md\z/, "-after.md")
  before_findings = SimpleEnglish.lint_text(File.read(before))
  after_findings = SimpleEnglish.lint_text(File.read(after))
  messages = []
  if before_findings.nil? || after_findings.nil?
    messages << "#{before}: daemon unreachable"
  else
    messages << "#{before}: no findings, the rule set misses this case" if before_findings.empty?
    unless after_findings.empty?
      messages << "#{after}: still flagged: #{after_findings.map(&:rule).join(", ")}"
    end
  end
  messages
end
failed.each { |failure| puts "FAIL #{failure}" }
puts "corpus: #{pairs.size} pairs, #{failed.size} failures"
exit(failed.empty? ? 0 : 1)
