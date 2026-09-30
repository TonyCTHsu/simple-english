# frozen_string_literal: true

require "minitest/autorun"
require "fileutils"
require_relative "test_helper"

class ConfigTest < Minitest::Test
  def test_missing_file_is_defaults
    in_tmpdir do |dir|
      assert_equal({ignore: [], disabled_rules: [], rules: []}, SimpleEnglish::Config.load(dir))
    end
  end

  def test_reads_ignore_disabled_rules_and_rules
    in_tmpdir do |dir|
      File.write(File.join(dir, "team.xml"), "<rules lang=\"en\"/>")
      File.write(File.join(dir, ".simple-english.yml"), <<~YML)
        ignore:
          - vendor/**
        disabled-rules:
          - SE_NO_EMDASH
        rules:
          - team.xml
      YML
      config = SimpleEnglish::Config.load(dir)
      assert_equal ["vendor/**"], config[:ignore]
      assert_equal ["SE_NO_EMDASH"], config[:disabled_rules]
      assert_equal [File.expand_path("team.xml", dir)], config[:rules]
    end
  end

  def test_missing_rules_file_raises_config_error
    in_tmpdir do |dir|
      File.write(File.join(dir, ".simple-english.yml"), "rules: [nope.xml]\n")
      error = assert_raises(SimpleEnglish::Config::ConfigError) { SimpleEnglish::Config.load(dir) }
      assert_match(/nope\.xml/, error.message)
    end
  end

  def test_non_string_rules_entry_raises_config_error
    in_tmpdir do |dir|
      File.write(File.join(dir, ".simple-english.yml"), "rules: [42]\n")
      error = assert_raises(SimpleEnglish::Config::ConfigError) { SimpleEnglish::Config.load(dir) }
      assert_match(/rules entries must be file paths/, error.message)
    end
  end

  def test_blank_rules_entry_raises_config_error
    in_tmpdir do |dir|
      File.write(File.join(dir, ".simple-english.yml"), "rules: [\"\"]\n")
      error = assert_raises(SimpleEnglish::Config::ConfigError) { SimpleEnglish::Config.load(dir) }
      assert_match(/rules entries must be file paths/, error.message)
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
