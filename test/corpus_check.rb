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
# Clean net: real third-party prose in test/corpus/clean, written for
# readers and not for these rules. Every file must stay silent. Each
# file name names its public-domain source.
clean = Dir.glob(File.expand_path("corpus/clean/*.md", __dir__)).sort
clean_failures = clean.flat_map do |path|
  findings = SimpleEnglish.lint(File.read(path))
  if findings.nil?
    ["#{path}: daemon unreachable"]
  else
    findings.map { |f| "#{path}: clean prose flagged #{f.rule}" }
  end
end
failed = (failed + clean_failures).uniq
failed.each { |failure| puts "FAIL #{failure}" }
puts "corpus: #{pairs.size} pairs, #{clean.size} clean files, #{failed.size} failures"
exit(failed.empty? ? 0 : 1)
