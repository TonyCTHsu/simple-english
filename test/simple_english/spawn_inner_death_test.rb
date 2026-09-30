# frozen_string_literal: true

require_relative "test_helper"

require "fileutils"
require "socket"
require "tempfile"
require "timeout"

class SpawnInnerDeathTest < Minitest::Test
  # A JVM that dies instantly must raise InnerDied fast, not after the
  # 300-second readiness timeout, and the message must quote the inner
  # log's first line. Drives the real spawn_inner with java stubbed to a
  # dying script.
  def test_spawn_inner_raises_quickly_when_inner_dies_instantly
    in_tmpdir do |dir|
      lt_dir = File.join(dir, "LanguageTool-#{SimpleEnglish::LanguageTool::LT_VERSION}")
      FileUtils.mkdir_p(lt_dir)
      File.write(File.join(lt_dir, "languagetool-commandline.jar"), "x")
      File.write(File.join(lt_dir, "languagetool-server.jar"), "x")
      script = File.join(dir, "die-now")
      File.write(script, "#!/bin/sh\necho boom >&2\nexit 1\n")
      File.chmod(0o755, script)
      install = SimpleEnglish::Install.new(cache_dir: dir, java: script)
      log_path = File.join(dir, "inner.log")
      probe = TCPServer.new("localhost", 0)
      port = probe.addr[1]
      probe.close
      error = Timeout.timeout(15) do
        assert_raises(SimpleEnglish::Server::InnerDied) do
          SimpleEnglish::Server.spawn_inner(install: install, port: port,
            rules_dir: dir, log_path: log_path)
        end
      end
      assert_includes error.message, "boom",
        "failure message must name the inner log's first line"
    ensure
      probe&.close
    end
  end

  # serve must fail with the setup message when the jars are missing, not
  # by spawning a doomed JVM.
  def test_spawn_inner_raises_setup_error_when_the_server_jar_is_missing
    install = SimpleEnglish::Install.new(cache_dir: "/nonexistent")
    error = assert_raises(SimpleEnglish::Install::SetupError) do
      SimpleEnglish::Server.spawn_inner(install: install, port: 0,
        rules_dir: "/tmp", log_path: "/dev/null")
    end
    assert_includes error.message, "Run `se setup`."
  end
end
