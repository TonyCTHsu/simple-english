# frozen_string_literal: true

require_relative "test_helper"

class LintFileEnsureUpTest < Minitest::Test
  def test_lint_file_code_path_ensures_the_daemon
    old_url = ENV["SE_SERVER_URL"]
    ENV["SE_SERVER_URL"] = "http://localhost:1"
    _out, err = capture_io do
      assert_nil SimpleEnglish.lint_file("a.py", "# a comment\nx = 1\n")
    end
    assert_match(/SE_SERVER_URL is set but/, err)
  ensure
    ENV["SE_SERVER_URL"] = old_url
  end
end
