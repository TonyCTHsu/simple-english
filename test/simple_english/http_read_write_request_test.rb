# frozen_string_literal: true

require_relative "test_helper"

require "stringio"
require "socket"
require "tempfile"
require "timeout"

class HTTPReadWriteRequestTest < Minitest::Test
  def test_read_request_parses_method_path_and_body
    io = StringIO.new("POST /lint HTTP/1.1\r\nContent-Length: 8\r\n\r\ntext=abc")
    assert_equal({method: "POST", path: "/lint", body: "text=abc"},
      SimpleEnglish::HTTP.read_request(io))
  end

  def test_read_request_returns_nil_for_malformed_request_line
    assert_nil SimpleEnglish::HTTP.read_request(StringIO.new("garbage\r\n\r\n"))
  end

  def test_read_request_returns_nil_at_eof
    assert_nil SimpleEnglish::HTTP.read_request(StringIO.new(+""))
  end

  def test_write_response_writes_minimal_http_response
    io = StringIO.new(+"")
    SimpleEnglish::HTTP.write_response(io, status: 404, body: "{}")
    assert_equal "HTTP/1.1 404 Not Found\r\nContent-Type: application/json\r\n" \
      "Content-Length: 2\r\nConnection: close\r\n\r\n{}", io.string
  end
end
