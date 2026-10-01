# frozen_string_literal: true

require_relative "test_helper"

require "json"

class ClientHTTPTest < Minitest::Test
  LT_BODY = {
    matches: [
      {message: "No contractions.", offset: 6, length: 6,
       rule: {id: "SE_NO_CONTRACTIONS"}}
    ]
  }.to_json

  def with_stub_server(mounts)
    server = StubHTTPServer.new(mounts)
    yield server.url
  ensure
    server&.shutdown
  end

  def test_check_posts_and_parses
    with_stub_server("/v2/check" => LT_BODY) do |url|
      findings = SimpleEnglish::Client.check("first\nsecond line", base_url: url,
        enabled_rules: SimpleEnglish::LanguageTool.rule_ids)
      positions = findings.map do |finding|
        [finding.line, finding.column, finding.end_line, finding.end_column,
          finding.rule, finding.message]
      end
      assert_equal [[2, 1, 2, 7, "SE_NO_CONTRACTIONS", "No contractions."]],
        positions
    end
  end

  def test_check_sends_the_enabled_rules_param
    seen = nil
    with_stub_server("/v2/check" => lambda do |body|
      seen = URI.decode_www_form(body).to_h
      LT_BODY
    end) do |url|
      SimpleEnglish::Client.check("text", base_url: url, enabled_rules: %w[A B])
      assert_equal "A,B", seen["enabledRules"]
      assert_equal "true", seen["enabledOnly"]
    end
  end

  def test_lint_returns_nil_when_daemon_is_down
    assert_nil SimpleEnglish::Client.lint("text",
      base_url: "http://localhost:1")
  end

  def test_lint_returns_nil_on_error_response
    # A daemon 500 serves {"error": ...}. lint must fall back, not crash
    # on Hash#map yielding [key, value] pairs.
    with_stub_server("/lint" => ->(_body) do
      [500, JSON.generate({"error" => "boom"})]
    end) do |url|
      assert_nil SimpleEnglish::Client.lint("text", base_url: url)
    end
  end

  def test_lint_returns_nil_on_non_json_response
    # A foreign service on the URL may answer with HTML or plain text.
    with_stub_server("/lint" => "not json") do |url|
      assert_nil SimpleEnglish::Client.lint("text", base_url: url)
    end
  end

  def test_info_is_foreign_for_a_non_handshake_responder
    with_stub_server("/" => "not a handshake") do |url|
      assert_equal :foreign, SimpleEnglish::Client.info(base_url: url)
    end
  end

  def test_info_reads_the_daemon_handshake
    info = {"version" => "0.2.0", "pid" => 42,
            "gem_digest" => "a" * 64, "rules_digest" => "b" * 64}
    with_stub_server("/" => JSON.generate(info)) do |url|
      assert_equal info, SimpleEnglish::Client.info(base_url: url)
    end
  end

  def test_info_is_foreign_for_a_malformed_handshake
    # Key presence alone is not a handshake: a malformed daemon is
    # not one we can reason about.
    bad = {"version" => "0.2.0", "pid" => "42",
           "gem_digest" => "a" * 64, "rules_digest" => "b" * 64}
    with_stub_server("/" => JSON.generate(bad)) do |url|
      assert_equal :foreign, SimpleEnglish::Client.info(base_url: url)
    end
  end

  def test_info_is_nil_when_daemon_is_down
    assert_nil SimpleEnglish::Client.info(base_url: "http://localhost:1")
  end

  def test_info_is_foreign_when_the_connection_dies_mid_poll
    # A daemon being TERMed resets or closes the connection:
    # something holds the port but answers nothing usable.
    server = TCPServer.new("127.0.0.1", 0)
    port = server.addr[1]
    closer = Thread.new { server.accept.close }
    assert_equal :foreign, SimpleEnglish::Client.info(base_url: "http://127.0.0.1:#{port}")
  ensure
    closer&.join(1)
    server&.close
  end
end
