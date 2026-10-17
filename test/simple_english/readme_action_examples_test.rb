# frozen_string_literal: true

# The README's GitHub Actions examples must stay truthful against
# action.yml: one pin everywhere, inputs the action declares, an
# upload path the action really writes.

require_relative "test_helper"
require "yaml"

class ReadmeActionExamplesTest < Minitest::Test
  README = File.read(File.expand_path("../../README.md", __dir__))
  ACTION_FILE = File.expand_path("../../action.yml", __dir__)
  HOOKS_FILE = File.expand_path("../../.pre-commit-hooks.yaml", __dir__)
  PIN = %r{TonyCTHsu/simple-english@v(\d+\.\d+\.\d+)}

  def test_pins_agree
    pins = (README.scan(PIN).map(&:first) +
      README.scan(/^\s*rev: v(\d+\.\d+\.\d+)$/).flatten).uniq
    assert_equal 1, pins.size,
      "README must pin the action at exactly one version, found #{pins.inspect}"
  end

  def test_pin_never_lags_the_gem
    pin = README[PIN, 1]
    assert_operator Gem::Version.new(pin), :>=,
      Gem::Version.new(SimpleEnglish::VERSION),
      "README pins an action older than the gem. Run rake release:prepare."
  end

  def test_example_inputs_exist
    declared = YAML.load_file(ACTION_FILE).fetch("inputs").keys
    steps = action_steps
    refute_empty steps, "README shows no simple-english example"
    steps.each do |step|
      step.fetch("with", {}).each_key do |key|
        assert_includes declared, key,
          "README passes #{key}, which action.yml does not declare"
      end
    end
  end

  def test_upload_reads_a_written_report
    report = YAML.load_file(ACTION_FILE).dig("outputs", "sarif", "value")
    assert_includes README, "sarif_file: #{report}",
      "README uploads a SARIF path the action never writes"
  end

  def test_precommit_example_selects_a_real_hook
    ids = YAML.load_file(HOOKS_FILE).map { |hook| hook.fetch("id") }.sort
    selected = precommit_repos.flat_map { |entry| entry.fetch("hooks") }
      .map { |hook| hook.fetch("id") }.sort
    assert_equal ids, selected,
      "README's pre-commit example selects #{selected.inspect}, " \
      "the manifest offers #{ids.inspect}"
  end

  private

  def yaml_blocks
    README.scan(/^```yaml\n(.*?)^```$/m)
  end

  def precommit_repos
    yaml_blocks
      .map { |(body)| YAML.safe_load(body) }
      .compact
      .select { |config| config.is_a?(Hash) && config.key?("repos") }
      .flat_map { |config| config.fetch("repos") }
      .select { |entry| entry["repo"] == "https://github.com/TonyCTHsu/simple-english" }
  end

  def action_steps
    yaml_blocks
      .map { |(body)| YAML.safe_load(body) }
      .compact
      .select { |workflow| workflow.is_a?(Hash) && workflow.key?("jobs") }
      .flat_map { |workflow| workflow.fetch("jobs").values }
      .flat_map { |job| job.fetch("steps") }
      .select { |step| step.is_a?(Hash) && step["uses"].to_s.start_with?("TonyCTHsu/simple-english@") }
  end
end
