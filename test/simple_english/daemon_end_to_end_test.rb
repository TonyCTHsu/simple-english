# frozen_string_literal: true

require_relative "test_helper"

require "stringio"
require "socket"
require "tempfile"
require "timeout"

class DaemonEndToEndTest < Minitest::Test
  def test_serve_daemon_lints_bad_markdown
    install = SimpleEnglish::Install.from_env
    skip "needs java and the LanguageTool cache" unless install.java? &&
      File.exist?(install.commandline_jar)

    Dir.mktmpdir do |dir|
      port = 8281
      root = File.expand_path("../..", __dir__)
      pid = Process.spawn(RbConfig.ruby, File.join(root, "bin/se"), "serve",
        "--port", port.to_s, "--dev-log", File.join(dir, "daemon.log"),
        out: File::NULL, err: File.join(dir, "daemon-stderr.log"),
        chdir: root)
      url = "http://localhost:#{port}"
      # The daemon gives its JVM TIMEOUT_SECONDS to boot. Poll for
      # that budget plus a margin, so the test never races the daemon
      # into a false failure on a slow runner.
      ((SimpleEnglish::LanguageTool::TIMEOUT_SECONDS + 10) * 2).times do
        break if SimpleEnglish::Client.up?(base_url: url)
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

  # BYOR end to end: the daemon boots in a directory whose
  # .simple-english.yml names a user rule file. The rule must stage
  # into the JVM classpath, join enabledRules, and fire on a lint.
  def test_serve_daemon_lints_with_user_rules
    install = SimpleEnglish::Install.from_env
    skip "needs java and the LanguageTool cache" unless install.java? &&
      File.exist?(install.commandline_jar)

    Dir.mktmpdir do |dir|
      File.write(File.join(dir, "team.xml"), <<~XML)
        <?xml version="1.0" encoding="UTF-8"?>
        <rules lang="en">
          <rule id="MY_TEAM_RULE" name="No foobar">
            <pattern><token>foobar</token></pattern>
            <message>Do not write foobar.</message>
            <example type="incorrect"><marker>foobar</marker> here.</example>
            <example type="correct">buzz here.</example>
          </rule>
        </rules>
      XML
      File.write(File.join(dir, ".simple-english.yml"), "rules: [team.xml]\n")
      port = 8284
      pid = Process.spawn(RbConfig.ruby, File.join(File.expand_path("../..", __dir__), "bin/se"),
        "serve", "--port", port.to_s, "--dev-log", File.join(dir, "daemon.log"),
        out: File::NULL, err: File.join(dir, "daemon-stderr.log"), chdir: dir)
      url = "http://localhost:#{port}"
      ((SimpleEnglish::LanguageTool::TIMEOUT_SECONDS + 10) * 2).times do
        break if SimpleEnglish::Client.up?(base_url: url)
        if Process.wait(pid, Process::WNOHANG)
          raise "daemon exited early. Log: #{daemon_log(dir)}"
        end
        sleep 0.5
      end
      findings = SimpleEnglish::Client.lint("foobar here.\n", base_url: url)
      refute_nil findings, "daemon never became ready. Log: #{daemon_log(dir)}"
      assert_includes findings.map(&:rule), "MY_TEAM_RULE"
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
    ["daemon.log", "daemon-stderr.log"].map do |name|
      path = File.join(dir, name)
      next "#{name}: none" unless File.file?(path)
      "#{name}: #{File.read(path)}"
    end.join("\n")
  rescue SystemCallError
    "unreadable"
  end
end
