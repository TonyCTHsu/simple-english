# frozen_string_literal: true

require_relative "test_helper"

require "json"

class ClientEnsureUpTest < Minitest::Test
  def test_up_is_true_when_daemon_answers
    server = StubHTTPServer.new("/v2/check" => lambda { |_body| [200, {matches: []}.to_json] })
    assert_equal true, SimpleEnglish::Client.up?(base_url: server.url)
    server.shutdown
  end

  def test_lint_text_returns_nil_when_custom_url_is_dead
    with_env("SE_SERVER_URL" => "http://localhost:1") do
      _out, err = capture_io do
        assert_nil SimpleEnglish.lint_text("Fine text.\n")
      end
      assert_match(/SE_SERVER_URL is set but/, err)
    end
  end

  def test_ensure_up_fails_fast_with_setup_message_when_jar_is_missing
    in_tmpdir do |dir|
      install = SimpleEnglish::Install.new(cache_dir: dir)
      # The jar matters only when the daemon is down and we need to
      # spawn it.
      SimpleEnglish::Client.stub :up?, false do
        _out, err = capture_io do
          refute SimpleEnglish::Client.ensure_up(install: install)
        end
        assert_match(/Run `se setup`\./, err)
      end
    end
  end
end
