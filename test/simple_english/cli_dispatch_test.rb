# frozen_string_literal: true

require_relative "test_helper"

class CLIDispatchTest < Minitest::Test
  def test_bare_file_routed_to_lint
    _, err = capture_io do
      assert_equal 2, SimpleEnglish::CLI.run(["does-not-exist.md"])
    end
    assert_match(/file not readable: does-not-exist\.md/, err)
  end

  def test_stdin_dash_routed_to_lint
    server = StubHTTPServer.new("/lint" => "[]")
    old_url = ENV["SE_SERVER_URL"]
    ENV["SE_SERVER_URL"] = server.url
    status = nil
    capture_io { status = SimpleEnglish::CLI.run(["-"]) }
    assert_equal 0, status
  ensure
    ENV["SE_SERVER_URL"] = old_url
    server&.shutdown
  end

  def test_empty_invocation_prints_usage_and_returns_2
    out, = capture_io { assert_equal 2, SimpleEnglish::CLI.run([]) }
    assert_match(/lint/, out)
  end
end
