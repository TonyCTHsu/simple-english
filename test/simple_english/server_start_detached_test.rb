# frozen_string_literal: true

require_relative "test_helper"

require "fileutils"
require "socket"

class ServerStartDetachedTest < Minitest::Test
  def test_spawns_a_plain_serve_and_returns_the_handshake
    port = free_port
    spawned = nil
    SimpleEnglish::Server.stub :takeover, nil do
      SimpleEnglish::Client.stub :spawn_daemon, ->(*args) { spawned = args } do
        SimpleEnglish::Client.stub :wait_for, ->(seconds: 90, &block) { block.call } do
          SimpleEnglish::Client.stub :info, {"pid" => 4242} do
            in_tmpdir do |dir|
              daemon = SimpleEnglish::Server.start_detached(port: port,
                install: fake_install(dir))
              assert_equal 4242, daemon["pid"]
              assert_equal ["--port", port.to_s], spawned
            end
          end
        end
      end
    end
  end

  def test_forwards_the_dev_log_to_the_child_serve
    port = free_port
    spawned = nil
    SimpleEnglish::Server.stub :takeover, nil do
      SimpleEnglish::Client.stub :spawn_daemon, ->(*args) { spawned = args } do
        SimpleEnglish::Client.stub :wait_for, ->(seconds: 90, &block) { block.call } do
          SimpleEnglish::Client.stub :info, {"pid" => 4242} do
            in_tmpdir do |dir|
              SimpleEnglish::Server.start_detached(port: port,
                install: fake_install(dir), dev_log: "daemon.log")
              assert_equal ["--port", port.to_s, "--dev-log", "daemon.log"], spawned
            end
          end
        end
      end
    end
  end

  def test_fails_fast_when_a_foreign_process_holds_the_port
    # A foreign holder does not answer the handshake, so the takeover
    # leaves it alone and the port check fires in milliseconds
    # instead of waiting out the spawn timeout.
    holder = TCPServer.new("127.0.0.1", 28291)
    in_tmpdir do |dir|
      SimpleEnglish::Client.stub :info, nil do
        SimpleEnglish::Client.stub :spawn_daemon, -> { flunk "must not spawn" } do
          error = assert_raises(SimpleEnglish::Server::PortInUse) do
            SimpleEnglish::Server.start_detached(port: 28291,
              install: fake_install(dir))
          end
          assert_match(/28291/, error.message)
        end
      end
    end
  ensure
    holder&.close
  end

  def test_fails_fast_with_setup_message_when_the_executable_is_missing
    install = SimpleEnglish::Install.new(executable: "/nonexistent/server")
    SimpleEnglish::Client.stub :spawn_daemon, -> { flunk "must not spawn" } do
      error = assert_raises(SimpleEnglish::Install::SetupError) do
        SimpleEnglish::Server.start_detached(port: 28291, install: install)
      end
      assert_match(/supported platform build/, error.message)
    end
  end

  def test_terms_and_reaps_the_child_when_readiness_fails
    # A straggler child that never answers must not survive the
    # failure: it later takes over the port from whatever
    # daemon comes next.
    child = Process.spawn(RbConfig.ruby, "-e", "sleep 30")
    budget = nil
    SimpleEnglish::Server.stub :takeover, nil do
      SimpleEnglish::Client.stub :spawn_daemon, child do
        SimpleEnglish::Client.stub :wait_for, ->(seconds:, &) {
          budget = seconds
          false
        } do
          in_tmpdir do |dir|
            assert_nil SimpleEnglish::Server.start_detached(port: free_port,
              install: fake_install(dir))
          end
        end
      end
    end
    # The wait matches the child's own boot budget, not the 90 s
    # default: a slow native server boot must not read as failure.
    assert_equal SimpleEnglish::LanguageTool::TIMEOUT_SECONDS + 10, budget
    assert_reaped(child)
  end

  private

  def fake_install(_dir)
    SimpleEnglish::Install.new(executable: RbConfig.ruby)
  end

  def free_port
    server = TCPServer.new("127.0.0.1", 0)
    port = server.addr[1]
    server.close
    port
  end

  def assert_reaped(pid)
    reaped = false
    50.times do
      reaped = !Process.wait(pid, Process::WNOHANG).nil?
      break if reaped
      sleep 0.1
    rescue Errno::ECHILD
      # No such child left: already reaped, which is the assertion.
      reaped = true
      break
    end
    assert reaped, "child still running after start_detached"
  end
end
