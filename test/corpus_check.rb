# frozen_string_literal: true

# Run the corpus pairs in test/corpus through the daemon. Pairs are
# NN-before.md / NN-after.md for Markdown, NN-before.rb / NN-after.rb
# for the comment pipeline.
#
# Usage: run `se serve` (or let the first lint start it), then
#   ruby test/corpus_check.rb
#
# CI lints the corpus in the native job, from the installed gem. This
# runner stays for local use.

require_relative "../lib/simple_english"

pairs = Dir.glob(File.expand_path("corpus/*-before.*", __dir__)).sort
failed = pairs.flat_map do |before|
  after = before.sub(/-before\.(\w+)\z/, "-after.\\1")
  language = SimpleEnglish::Extractor.language_for(before)
  before_findings = SimpleEnglish.lint(File.read(before), language: language)
  after_findings = SimpleEnglish.lint(File.read(after), language: language)
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
