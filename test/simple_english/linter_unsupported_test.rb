# frozen_string_literal: true

require_relative "test_helper"

class LinterUnsupportedTest < Minitest::Test
  # A dead custom URL makes any daemon boot fatal. Reaching [] with no
  # stderr proves the skip happens before any daemon code runs.
  def test_unknown_file_type_is_skipped_without_a_daemon
    with_env("SE_SERVER_URL" => "http://localhost:1") do
      _out, err = capture_io do
        assert_empty SimpleEnglish::Linter.lint_file("notes.txt", config: SimpleEnglish::Config::DEFAULT)
        assert_empty SimpleEnglish::Linter.lint_file("script.pl", config: SimpleEnglish::Config::DEFAULT)
        assert_empty SimpleEnglish::Linter.lint_file("data.json", config: SimpleEnglish::Config::DEFAULT)
      end
      assert_equal "", err
    end
  end

  def test_unsupported_file_is_never_read_from_disk
    # The gate runs before the read: this path does not exist, so a
    # read-first order raises here.
    assert_empty SimpleEnglish::Linter.lint_file("missing.bin", config: SimpleEnglish::Config::DEFAULT)
  end

  def test_prose_text_still_lints
    with_env("SE_SERVER_URL" => "http://localhost:1") do
      _out, err = capture_io do
        assert_nil SimpleEnglish::Linter.lint_text("This is utilized in order to do it.", config: SimpleEnglish::Config::DEFAULT)
      end
      assert_match(/SE_SERVER_URL is set but/, err)
    end
  end
end
