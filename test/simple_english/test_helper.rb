# frozen_string_literal: true

require "tmpdir"
require "json"
require "fileutils"
require "minitest/autorun"
require "minitest/mock"
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

# Sets ENV keys for the block and restores them (or unsets them) after,
# even on failure. A nil value means the key stays unset.
def with_env(overrides)
  saved = overrides.keys.map { |k| [k, ENV[k]] }.to_h
  overrides.each { |k, v| v ? ENV[k] = v : ENV.delete(k) }
  yield
ensure
  saved.each { |k, v| v ? ENV[k] = v : ENV.delete(k) }
end

# Runs the block in a fresh temp dir, removed after, even on failure.
# chdir: true also makes it the working dir for the block.
def in_tmpdir(chdir: false)
  Dir.mktmpdir do |dir|
    chdir ? Dir.chdir(dir) { yield dir } : yield(dir)
  end
end

# An Install whose server jar is an empty file: passes Server.start's
# preflight with no LanguageTool cache needed.
# ponytail: fake jar. If the preflight grows checks, grow this too.
def fake_install
  in_tmpdir do |dir|
    lt = File.join(dir, "LanguageTool-#{SimpleEnglish::LanguageTool::LT_VERSION}")
    FileUtils.mkdir_p(lt)
    FileUtils.touch(File.join(lt, "languagetool-server.jar"))
    yield SimpleEnglish::Install.new(cache_dir: dir, java: RbConfig.ruby)
  end
end
