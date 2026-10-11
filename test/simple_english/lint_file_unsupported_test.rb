# frozen_string_literal: true

require_relative "test_helper"

class LintFileUnsupportedTest < Minitest::Test
  # A dead custom URL makes any daemon boot fatal. Reaching [] with no
  # stderr proves the skip happens before any daemon code runs.
  def test_unknown_file_type_is_skipped_without_a_daemon
    with_env("SE_SERVER_URL" => "http://localhost:1") do
      _out, err = capture_io do
        assert_empty SimpleEnglish.lint_file("notes.txt", "This is utilized in order to do it.")
        assert_empty SimpleEnglish.lint_file("script.pl", "print 'utilized in order to';")
        assert_empty SimpleEnglish.lint_file("data.json", "{\"k\": \"utilized in order to\"}")
      end
      assert_equal "", err
    end
  end

  def test_unsupported_file_is_never_read_from_disk
    # The gate runs before the read: this path does not exist, so a
    # read-first order raises here.
    assert_empty SimpleEnglish.lint_file("missing.bin")
  end

  def test_markdown_and_stdin_still_lint
    with_env("SE_SERVER_URL" => "http://localhost:1") do
      _out, err = capture_io do
        assert_nil SimpleEnglish.lint_file("doc.md", "This is utilized in order to do it.")
        assert_nil SimpleEnglish.lint_file("-", "This is utilized in order to do it.")
      end
      assert_match(/SE_SERVER_URL is set but/, err)
    end
  end
end
