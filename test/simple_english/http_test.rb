# frozen_string_literal: true

require_relative "test_helper"

# The wiring a private-method bug hid: Server.start calls
# HTTP.handle_client through an explicit receiver, so it must stay
# public, and a POST /lint must come back answered and closed.
class HTTPHandleClientTest < Minitest::Test
  def test_post_lint_is_answered_through_the_real_socket_loop
    inner = StubHTTPServer.new("/v2/check" => lambda do |_body|
      {matches: [{message: "No contractions.", offset: 0, length: 5,
                  rule: {id: "SE_NO_CONTRACTIONS"}}]}.to_json
    end)
    outer = TCPServer.new("127.0.0.1", 0)
    accept = Thread.new do
      loop do
        client = outer.accept
        Thread.new(client) { |c|
          SimpleEnglish::HTTP.handle_client(c,
            port: inner_port(inner), enabled_rules: %w[SE_NO_CONTRACTIONS])
        }
      end
    rescue IOError, Errno::EBADF
      # The teardown closes the socket while accept is blocked. Same
      # quiet-exit pattern as StubHTTPServer.
    end
    findings = SimpleEnglish::Client.lint("Don't do this.\n",
      base_url: "http://127.0.0.1:#{outer.addr[1]}")
    refute_nil findings, "the request hung or the daemon never answered"
    assert_includes findings.map(&:rule), "SE_NO_CONTRACTIONS"
  ensure
    outer&.close
    inner&.shutdown
    accept&.kill
  end

  private

  # handle_client computes the inner base URL as localhost:port + 1,
  # so hand it the port whose successor is the stub.
  def inner_port(stub)
    stub.url.split(":").last.to_i - 1
  end
end
