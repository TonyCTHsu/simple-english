# frozen_string_literal: true

require "json"
require "minitest/autorun"
require "socket"
require_relative "../../lib/simple_english"
require_relative "../../lib/simple_english/cli"

# Minimal stdlib HTTP stub for tests: binds 127.0.0.1 in the constructor
# (construction = ready, no polling), one thread per request, reuses
# SimpleEnglish::HTTP's request/response framing.
class StubHTTPServer
  SELECT_TIMEOUT = 0.2

  # mounts: { "/path" => handler } where handler is a callable taking the
  # request body string and returning [status, body_string], or a plain
  # String body (served as 200). Any other path answers 404.
  def initialize(mounts)
    @mounts = mounts
    @server = TCPServer.new("127.0.0.1", 0)
    @threads = []
    @mutex = Mutex.new
    @threads << Thread.new do
      loop do
        ready = IO.select([@server], nil, nil, SELECT_TIMEOUT)
        next if ready.nil?
        client = @server.accept
        track(Thread.new(client) { |c| handle(c) })
      rescue IOError, Errno::EBADF
        break
      end
    end
  end

  def url
    "http://127.0.0.1:#{@server.addr[1]}"
  end

  # Closes the listener (the accept loop notices within one select
  # timeout) and joins all threads with a bound.
  def shutdown
    begin
      @server.close
    rescue IOError
      # Already closed.
    end
    threads = @mutex.synchronize { @threads.dup }
    threads.each { |thread| thread.join(5) }
  end

  private

  def track(thread)
    @mutex.synchronize { @threads << thread }
  end

  def handle(client)
    request = SimpleEnglish::HTTP.read_request(client)
    if request.nil?
      # Malformed request or immediate hangup. Nothing to answer.
    elsif request[:method] == "HEAD"
      # Client.up? does http.head("/") and treats any response as up.
      SimpleEnglish::HTTP.write_response(client, status: 200, body: "")
    elsif (handler = @mounts[request[:path]])
      handled = handler.respond_to?(:call) ? handler.call(request[:body]) : handler
      status, body = handled.is_a?(Array) ? handled : [200, handled]
      SimpleEnglish::HTTP.write_response(client, status: status, body: body)
    else
      SimpleEnglish::HTTP.write_response(client, status: 404,
        body: JSON.generate({"error" => "not found"}))
    end
  ensure
    client.close
  end
end
