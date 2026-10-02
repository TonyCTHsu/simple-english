# frozen_string_literal: true

require_relative "test_helper"

require "stringio"
require "socket"
require "tempfile"
require "timeout"

class DaemonEndToEndTest < Minitest::Test
  def test_serve_detached_boots_a_daemon_that_outlives_the_parent
    install = SimpleEnglish::Install.from_env
    skip "needs native LanguageTool executable" unless install.executable?

    in_tmpdir do |dir|
      port = 8282
      root = File.expand_path("../..", __dir__)
      pid = Process.spawn(RbConfig.ruby, File.join(root, "bin/se"), "serve",
        "--detached", "--port", port.to_s,
        "--dev-log", File.join(dir, "daemon.log"),
        out: File::NULL, err: File.join(dir, "parent-stderr.log"),
        chdir: root)
      _, status = Process.wait2(pid)
      assert_equal 0, status.exitstatus,
        "detached serve exited nonzero. Log: #{daemon_log(dir)}"
      # The parent exited, but the daemon it spawned must answer.
      url = "http://localhost:#{port}"
      daemon = nil
      ((SimpleEnglish::LanguageTool::TIMEOUT_SECONDS + 10) * 2).times do
        daemon = SimpleEnglish::Client.info(base_url: url)
        break if daemon.is_a?(Hash)
        sleep 0.5
      end
      assert_kind_of Hash, daemon, "daemon never became ready. Log: #{daemon_log(dir)}"
      assert_includes SimpleEnglish::Client.lint("Don't do it here.\n", base_url: url)
        .map(&:rule), "SE_NO_CONTRACTIONS"
    ensure
      if daemon.is_a?(Hash)
        begin
          Process.kill("TERM", daemon["pid"])
          # The inner server takes longer than the outer
          # listener: wait the takeover window or the next run on this
          # port races the shutdown.
          deadline = Time.now + 10
          sleep 0.2 until Time.now > deadline ||
              !SimpleEnglish::Client.info(base_url: url).is_a?(Hash)
        rescue Errno::ESRCH
        end
      end
    end
  end

  def test_serve_daemon_lints_bad_markdown
    install = SimpleEnglish::Install.from_env
    skip "needs native LanguageTool executable" unless install.executable?

    in_tmpdir do |dir|
      port = 8281
      root = File.expand_path("../..", __dir__)
      pid = Process.spawn(RbConfig.ruby, File.join(root, "bin/se"), "serve",
        "--port", port.to_s, "--dev-log", File.join(dir, "daemon.log"),
        out: File::NULL, err: File.join(dir, "daemon-stderr.log"),
        chdir: root)
      url = "http://localhost:#{port}"
      # The daemon gives its inner server TIMEOUT_SECONDS to boot. Poll for
      # that budget plus a margin, so the test never races the daemon
      # into a false failure on a slow runner.
      ((SimpleEnglish::LanguageTool::TIMEOUT_SECONDS + 10) * 2).times do
        break if SimpleEnglish::Client.info(base_url: url)
        if Process.wait(pid, Process::WNOHANG)
          raise "daemon exited early. Log: #{daemon_log(dir)}"
        end
        sleep 0.5
      end
      refute_nil SimpleEnglish::Client.lint("Don't do it here.\n", base_url: url),
        "daemon never became ready. Log: #{daemon_log(dir)}"
      findings = SimpleEnglish::Client.lint("Don't do it here.\n", base_url: url)
      assert_includes findings.map(&:rule), "SE_NO_CONTRACTIONS"
    ensure
      if pid
        begin
          Process.kill("TERM", pid)
          Process.wait(pid)
        rescue Errno::ESRCH, Errno::ECHILD
          # The poll loop already reaped a daemon that exited early.
        end
      end
    end
  end

  private

  # The logs name the reason when the daemon dies. The tmpdir is
  # gone by the time minitest prints the failure, so quote them here.
  def daemon_log(dir)
    ["daemon.log", "daemon-stderr.log", "parent-stderr.log"].map do |name|
      path = File.join(dir, name)
      next "#{name}: none" unless File.file?(path)
      "#{name}: #{File.read(path)}"
    end.join("\n")
  rescue SystemCallError
    "unreadable"
  end
end
