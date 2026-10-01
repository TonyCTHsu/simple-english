# frozen_string_literal: true

# Runs the corpus pairs through the Vale edition and asserts the
# same contract as test/corpus_check.rb: every before file flags,
# every after file stays clean. Pair 06 is the counting pair, and
# the counting rules are not in the edition, so it is skipped.
#
# Needs the vale binary on PATH. CI installs a pinned version.
#
# Usage: ruby test/vale_corpus_check.rb

require "json"
require "open3"
require "tmpdir"

VALE = ENV.fetch("VALE", "vale")
ROOT = File.expand_path("..", __dir__)
SKIP_PAIRS = ["06"].freeze # counting rules live in the CLI, not in styles

module ValeCorpusCheck
  module_function

  def config(dir)
    File.write(File.join(dir, ".vale.ini"), <<~INI)
      StylesPath = #{File.join(ROOT, "vale/styles")}
      MinAlertLevel = error
      [*.md]
      BasedOnStyles = SimpleEnglish
    INI
    File.join(dir, ".vale.ini")
  end

  def findings(config_path, path)
    out, _err, status = Open3.capture3(VALE, "--config", config_path,
      "--output=JSON", path)
    # Vale exits 1 when it reports findings, 2 and up for real errors.
    raise "vale exited #{status.exitstatus}: check the config and styles" unless status.exitstatus <= 1

    JSON.parse(out).values.flat_map do |alerts|
      alerts.select { |alert| alert["Check"].start_with?("SimpleEnglish.") }
        .map { |alert| alert["Check"].delete_prefix("SimpleEnglish.") }
    end
  end

  def check
    failures = []
    Dir.mktmpdir do |dir|
      config_path = config(dir)
      pairs = Dir.glob(File.join(ROOT, "test/corpus/*-before.md")).sort
      pairs.each do |before|
        pair = File.basename(before).split("-").first
        next if SKIP_PAIRS.include?(pair)

        after = before.sub(/-before\.md\z/, "-after.md")
        failures << "#{before}: no findings, the edition misses this case" if findings(config_path, before).empty?
        after_findings = findings(config_path, after)
        failures << "#{after}: still flagged: #{after_findings.join(", ")}" unless after_findings.empty?
      end
    end
    failures.each { |failure| puts "FAIL #{failure}" }
    puts "vale corpus: #{failures.empty? ? "ALL PASS" : "FAILURES"}"
    failures.empty?
  end
end

exit(ValeCorpusCheck.check ? 0 : 1) if $PROGRAM_NAME == __FILE__
