# frozen_string_literal: true

require "minitest/autorun"
require "fileutils"
require_relative "test_helper"

class ConfigTest < Minitest::Test
  def test_missing_file_is_defaults
    in_tmpdir do |dir|
      assert_equal({ignore: [], disabled_rules: []}, SimpleEnglish::Config.load(dir))
    end
  end

  def test_reads_ignore_and_disabled_rules
    in_tmpdir do |dir|
      File.write(File.join(dir, ".simple-english.yml"), <<~YML)
        ignore:
          - vendor/**
        disabled-rules:
          - SE_NO_EMDASH
      YML
      config = SimpleEnglish::Config.load(dir)
      assert_equal ["vendor/**"], config[:ignore]
      assert_equal ["SE_NO_EMDASH"], config[:disabled_rules]
    end
  end

  def test_warns_when_the_rules_key_is_present
    in_tmpdir do |dir|
      File.write(File.join(dir, "team.xml"), "<rules lang=\"en\"/>")
      File.write(File.join(dir, ".simple-english.yml"), "rules: [team.xml]\n")
      config = nil
      _out, err = capture_io do
        config = SimpleEnglish::Config.load(dir)
      end
      assert_match(/`rules:` is no longer supported and is ignored/, err)
      refute config.key?(:rules)
    end
  end

  def test_filter_ignores_paths_and_drops_disabled_rules
    config = {ignore: ["vendor/**"], disabled_rules: ["SE_NO_EMDASH"]}
    dropped = SimpleEnglish::Finding.new(line: 1, column: 3, rule: "SE_NO_EMDASH", message: "x")
    kept = SimpleEnglish::Finding.new(line: 1, column: 3, rule: "SE_NO_CONTRACTIONS", message: "x")
    assert_empty SimpleEnglish::Config.filter(config, "vendor/lib/a.py", [dropped, kept])
    assert_equal [kept], SimpleEnglish::Config.filter(config, "lib/a.py", [dropped, kept])
  end

  def test_invalid_yaml_raises_config_error
    in_tmpdir do |dir|
      File.write(File.join(dir, ".simple-english.yml"), "ignore: [unclosed\n")
      error = assert_raises(SimpleEnglish::Config::ConfigError) { SimpleEnglish::Config.load(dir) }
      assert_match(/\.simple-english\.yml/, error.message)
    end
  end

  def test_single_star_does_not_cross_directories
    config = {ignore: ["*.md"], disabled_rules: []}
    finding = SimpleEnglish::Finding.new(line: 1, column: nil, rule: "R", message: "x")
    assert_empty SimpleEnglish::Config.filter(config, "doc.md", [finding])
    assert_equal [finding], SimpleEnglish::Config.filter(config, "sub/dir/doc.md", [finding])
  end
end
