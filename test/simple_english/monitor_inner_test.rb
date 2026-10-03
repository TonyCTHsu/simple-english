# frozen_string_literal: true

require_relative "test_helper"

require "stringio"
require "socket"
require "tempfile"
require "timeout"

class MonitorInnerTest < Minitest::Test
  def test_monitor_inner_runs_on_death_when_child_exits
    pid = Process.spawn(RbConfig.ruby, "-e", "sleep 0.05")
    died = false
    monitor = SimpleEnglish::Server.monitor_inner(pid, on_death: -> { died = true })
    assert monitor.join(5), "monitor thread never finished"
    assert died
  ensure
    monitor&.kill if monitor&.alive?
  end

  # Full inner-death path: a stubbed spawn_inner starts a
  # plain sleep as the "inner server", so when it dies the daemon must
  # stop serving and raise InnerDied with the rerun message. Runs in a
  # subprocess because start() traps INT/TERM.
  def test_start_raises_inner_died_when_inner_dies
    root = File.expand_path("../..", __dir__)
    script = <<~RUBY
      require "simple_english"
      require "socket"
      # Pick a free port whose successor is free too, so the inner-port
      # guard passes and the outer server can bind a real port.
      port = nil
      50.times do
        probe = TCPServer.new("localhost", 0)
        candidate = probe.addr[1]
        probe.close
        begin
          inner = TCPServer.new("localhost", candidate + 1)
        rescue Errno::EADDRINUSE
          next
        end
        inner.close
        port = candidate
        break
      end
      module SimpleEnglish
        module Server
          def self.spawn_inner(install:, port:, log_path:)
            Process.spawn(RbConfig.ruby, "-e", "sleep 0.2")
          end
        end
      end
      begin
        SimpleEnglish::Server.start(port: port,
          install: SimpleEnglish::Install.new(executable: RbConfig.ruby),
          log: File::NULL)
      rescue SimpleEnglish::Server::InnerDied => e
        warn "error: \#{e.message}"
        exit 2
      end
      exit 42
    RUBY
    err = Tempfile.new("ste-inner-death")
    pid = Process.spawn(RbConfig.ruby, "-I", File.join(root, "lib"), "-e", script,
      out: File::NULL, err: err.path, chdir: root)
    waiter = Thread.new { Process.wait2(pid) }
    if waiter.join(10)
      _, status = waiter.value
      # Exit 2 (not the sentinel 42) proves the daemon left via the
      # inner-death path, and the message proves the reason.
      assert_equal 2, status.exitstatus
      assert_includes File.read(err.path), "lint engine died. Rerun se serve."
    else
      Process.kill("KILL", pid)
      Process.wait(pid)
      flunk "daemon kept running after the inner process died"
    end
  end
end
