# frozen_string_literal: true

require_relative "test_helper"

class LintFileNoCommentsTest < Minitest::Test
  def gem_available?
    require "tree_sitter_language_pack"
    true
  rescue LoadError
    false
  end

  def test_comment_free_code_file_never_reaches_the_daemon
    skip "needs tree_sitter_language_pack" unless gem_available?
    called = false
    server = StubHTTPServer.new("/lint" => lambda do |_body|
      called = true
      [200, "[]"]
    end)
    with_env("SE_SERVER_URL" => server.url) do
      assert_empty SimpleEnglish.lint_file("a.py", "x = 1\n")
      refute called, "a comment-free file must not reach the daemon"
      # A dead custom URL: reaching [] without SystemExit proves that no
      # daemon code ran.
      with_env("SE_SERVER_URL" => "http://localhost:1") do
        assert_empty SimpleEnglish.lint_file("b.py", "y = 2\n")
      end
    end
  ensure
    server&.shutdown
  end
end
