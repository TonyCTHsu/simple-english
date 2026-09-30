# frozen_string_literal: true

require_relative "test_helper"

class LintFileEnsureUpTest < Minitest::Test
  def test_lint_file_code_path_ensures_the_daemon
    with_env("SE_SERVER_URL" => "http://localhost:1") do
      _out, err = capture_io do
        assert_nil SimpleEnglish.lint_file("a.py", "# a comment\nx = 1\n")
      end
      assert_match(/SE_SERVER_URL is set but/, err)
    end
  end
end
