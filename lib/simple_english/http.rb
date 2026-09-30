# frozen_string_literal: true

# Minimal HTTP/1.1 wire framing for the daemon's outer server. Serving
# one request per connection (Connection: close) keeps this simple: no
# chunked bodies, no pipelining.

require "json"

module SimpleEnglish
  module HTTP
    module_function

    # Reads one HTTP request from io: request line, headers, then
    # Content-Length bytes of body. nil when malformed or the peer
    # hung up.
    def read_request(io)
      request_line = io.gets
      parts = request_line ? request_line.split(" ") : []
      return nil if parts.length < 2
      content_length = 0
      while (line = io.gets)
        break if line == "\r\n" || line == "\n"
        name, value = line.split(":", 2)
        next unless value
        content_length = value.strip.to_i if name.casecmp?("content-length")
      end
      return nil if content_length.negative?
      body = content_length.zero? ? +"" : io.read(content_length)
      {method: parts[0], path: parts[1], body: body}
    end

    # Writes a minimal HTTP/1.1 response and closes the logical
    # connection (Connection: close): status line, always-JSON headers,
    # Content-Length, then the body.
    def write_response(io, status:, body:, content_type: "application/json")
      reason = {200 => "OK", 404 => "Not Found",
                500 => "Internal Server Error"}.fetch(status, "Unknown")
      io.write("HTTP/1.1 #{status} #{reason}\r\n" \
        "Content-Type: #{content_type}\r\n" \
        "Content-Length: #{body.bytesize}\r\n" \
        "Connection: close\r\n\r\n")
      io.write(body)
    end

    # One thread per request: lint can take seconds, so a slow request
    # must not block readiness probes or other clients. The enabled
    # rule IDs are frozen at boot (Server.start) and passed through.
    def handle_client(client, port:, enabled_rules:)
      request = read_request(client)
      if request.nil?
        # Malformed request or immediate hangup: nothing to answer.
      elsif request[:method] == "HEAD"
        # Client.up? does http.head("/") and treats any response as up.
        write_response(client, status: 200, body: "")
      elsif request[:method] == "POST" && request[:path] == "/lint"
        begin
          # Ruling 2026-09-24: Client.lint posts form-encoded data, so the
          # handler decodes it. A raw body lints "text=Don%27t...".
          # The optional language switches to the code-comment pipeline.
          params = URI.decode_www_form(request[:body]).to_h
          write_response(client, status: 200,
            body: SimpleEnglish::Engine.lint_json(params["text"],
              base_url: "http://localhost:#{port + 1}",
              language: params["language"], enabled_rules: enabled_rules))
        rescue => e
          write_response(client, status: 500,
            body: JSON.generate({"error" => e.message}))
        end
      else
        write_response(client, status: 404,
          body: JSON.generate({"error" => "not found"}))
      end
    ensure
      client.close
    end
  end
end
