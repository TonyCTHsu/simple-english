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

  def test_ignore_matches_globs
    config = {ignore: ["vendor/**"], disabled_rules: []}
    assert SimpleEnglish::Config.ignore?(config, "vendor/lib/a.py")
    refute SimpleEnglish::Config.ignore?(config, "lib/a.py")
  end

  def test_filter_drops_disabled_rules
    config = {ignore: [], disabled_rules: ["SE_NO_EMDASH"]}
    dropped = SimpleEnglish::Finding.new(line: 1, column: 3, rule: "SE_NO_EMDASH", message: "x")
    kept = SimpleEnglish::Finding.new(line: 1, column: 3, rule: "SE_NO_CONTRACTIONS", message: "x")
    assert_equal [kept], SimpleEnglish::Config.filter(config, [dropped, kept])
  end

  def test_absolute_path_under_cwd_matches_relative_glob
    config = {ignore: ["docs/**"], disabled_rules: []}
    in_tmpdir(chdir: true) do |dir|
      absolute = File.join(dir, "docs", "a.md")
      FileUtils.mkdir_p(File.dirname(absolute))
      FileUtils.touch(absolute)
      assert SimpleEnglish::Config.ignore?(config, absolute)
    end
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
    assert SimpleEnglish::Config.ignore?(config, "doc.md")
    refute SimpleEnglish::Config.ignore?(config, "sub/dir/doc.md")
  end
end
