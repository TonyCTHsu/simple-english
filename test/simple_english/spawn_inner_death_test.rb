# frozen_string_literal: true

require_relative "test_helper"

require "socket"
require "timeout"
require "tmpdir"

class SpawnInnerDeathTest < Minitest::Test
  def test_spawn_inner_raises_quickly_when_inner_dies_instantly
    Dir.mktmpdir do |dir|
      script = File.join(dir, "die-now")
      File.write(script, "#!/bin/sh\necho boom >&2\nexit 1\n")
      File.chmod(0o755, script)
      install = SimpleEnglish::Install.new(executable: script)
      log_path = File.join(dir, "inner.log")
      probe = TCPServer.new("localhost", 0)
      port = probe.addr[1]
      probe.close
      error = Timeout.timeout(15) do
        assert_raises(SimpleEnglish::Server::InnerDied) do
          SimpleEnglish::Server.spawn_inner(install: install, port: port,
            log_path: log_path)
        end
      end
      assert_includes error.message, "boom",
        "failure message must name the inner log's first line"
    ensure
      probe&.close
    end
  end

  def test_spawn_inner_raises_setup_error_when_executable_is_missing
    install = SimpleEnglish::Install.new(executable: "/nonexistent/server")
    error = assert_raises(SimpleEnglish::Install::SetupError) do
      SimpleEnglish::Server.spawn_inner(install: install, port: 0,
        log_path: "/dev/null")
    end
    assert_includes error.message, "supported platform build"
  end
end
