# frozen_string_literal: true

require_relative "test_helper"

class LinterEnsureUpTest < Minitest::Test
  def test_linter_code_path_ensures_the_daemon
    with_env("SE_SERVER_URL" => "http://localhost:1") do
      _out, err = capture_io do
        assert_nil SimpleEnglish::Linter.lint_text("# a comment\nx = 1\n", language: "python", config: SimpleEnglish::Config::DEFAULT)
      end
      assert_match(/SE_SERVER_URL is set but/, err)
    end
  end
end
