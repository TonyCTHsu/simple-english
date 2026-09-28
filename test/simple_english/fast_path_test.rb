# frozen_string_literal: true

require_relative "test_helper"

class FastPathTest < Minitest::Test
  DAEMON_FINDINGS = [
    {"line" => 1, "rule" => "SE_NO_CONTRACTIONS", "message" => "No contractions."}
  ].to_json

  def with_stub_daemon
    server = StubHTTPServer.new("/lint" => DAEMON_FINDINGS)
    old_url = ENV["SE_SERVER_URL"]
    ENV["SE_SERVER_URL"] = server.url
    yield
  ensure
    ENV["SE_SERVER_URL"] = old_url
    server&.shutdown
  end

  def test_lint_text_uses_daemon_when_up
    with_stub_daemon do
      findings = SimpleEnglish.lint_text("Don't.\n")
      assert_equal [[1, "SE_NO_CONTRACTIONS", "No contractions."]],
        findings.map { |f| [f.line, f.rule, f.message] }
    end
  end

  def test_lint_text_returns_nil_when_daemon_is_down
    # A dead custom URL belongs to someone else: never spawn, return nil
    # and let the caller decide the exit status.
    old_url = ENV["SE_SERVER_URL"]
    ENV["SE_SERVER_URL"] = "http://localhost:1"
    _out, err = capture_io do
      assert_nil SimpleEnglish.lint_text("Fine text.\n")
    end
    assert_match(/SE_SERVER_URL is set but/, err)
  ensure
    ENV["SE_SERVER_URL"] = old_url
  end
end
