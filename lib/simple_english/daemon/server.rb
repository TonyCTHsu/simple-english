# frozen_string_literal: true

# The se daemon: process lifecycle only. The wire protocol lives in
# lib/simple_english/daemon/http.rb, the lint engine in
# lib/simple_english/daemon/engine.rb.
# Failures raise typed errors (PortInUse, SetupError, InnerDied,
# InnerTimeout). bin/se owns turning them into warnings and exit codes.

require "fileutils"
require "net/http"
require "socket"
require "tempfile"
require "tmpdir"

require_relative "../setup/install"
require_relative "../client/daemon"
require_relative "../setup/fingerprint"
require_relative "../version"

module SimpleEnglish
  module Server
    class ServerError < StandardError; end

    class PortInUse < ServerError
      def initialize(port)
        super("port #{port} is already in use.")
      end
    end

    class InnerDied < ServerError; end
    class InnerTimeout < ServerError; end

    module_function

    # LanguageTool's HTTP server has no --rulefile flag. Custom rules
    # load from the classpath at this exact path.
    def stage_rules(dir)
      target = File.join(dir, "org/languagetool/rules/en/grammar_custom.xml")
      FileUtils.mkdir_p(File.dirname(target))
      FileUtils.cp(SimpleEnglish::LanguageTool::RULES_FILE, target)
      target
    end

    # Probes both loopback families: on IPv6-first resolvers a "localhost"
    # probe falls back to IPv4 and misses an IPv6 listener.
    def assert_port_free(port)
      raise PortInUse, port unless port_free?(port)
    end

    def port_free?(port)
      ["127.0.0.1", "::1"].each do |address|
        TCPServer.new(address, port).close
      rescue Errno::EADDRNOTAVAIL, Errno::EAFNOSUPPORT
        # One family may be missing on this host (EADDRNOTAVAIL, or
        # EAFNOSUPPORT when the kernel has no IPv6 at all): skip it
        # and probe the other. A rescue at method scope returns here
        # and never probes the second family.
        next
      end
      true
    rescue Errno::EADDRINUSE
      false
    rescue Errno::EACCES
      raise ServerError, "port #{port} cannot be bound. Use a port above 1024."
    end

    # `se serve` over a live daemon (gem upgrade): when
    # one of our daemons holds the port (it answers the
    # handshake), stop it and take over the port. A service that
    # does not answer the handshake, pre-handshake daemon included,
    # keeps the PortInUse error: those need a manual look.
    def takeover(port)
      daemon = Client.info(base_url: "http://localhost:#{port}")
      return unless daemon.is_a?(Hash)
      stop(daemon["pid"])
      # The outer listener closes first. The inner JVM takes seconds
      # longer. Both ports must free, or the next boot hits the inner
      # port and dies.
      deadline = Time.now + 10
      sleep 0.2 until Time.now > deadline ||
          !Client.info(base_url: "http://localhost:#{port}").is_a?(Hash) &&
              port_free?(port + 1)
    end

    # Graceful only. SIGKILL skips the TERM trap and the inner JVM
    # teardown. The orphan still holds port + 1 and breaks the next
    # boot. The pid comes off the wire, so only a positive integer is
    # TERMed: 0 signals the caller's own process group, a negative
    # one every process the user may signal.
    def stop(pid)
      return nil unless pid.is_a?(Integer) && pid > 1
      Process.kill("TERM", pid)
    rescue Errno::ESRCH, Errno::EPERM
      nil
    end

    # Everything a boot needs on the machine, checked before the
    # takeover stops the old daemon: a reload that cannot boot must
    # leave the running daemon alive.
    def preflight_install(install)
      return if File.exist?(install.server_jar) && install.java?
      raise Install::SetupError,
        install.java? ? install.setup_error : install.java_message
    end
    private_class_method :preflight_install

    # `se serve --detached`: replace any se daemon on the port, then
    # boot a plain foreground serve as a detached child - the same
    # shape the auto-boot spawns. The parent returns once the
    # handshake answers. nil means the child never came up, and the
    # visible serve (same command, no flag) shows why. dev_log is
    # forwarded so a detached daemon can still get a log file.
    def start_detached(port: Client::DEFAULT_PORT, install: Install.from_env,
      dev_log: nil)
      preflight_install(install)
      takeover(port)
      # A foreign port holder survives the takeover untouched: fail
      # in milliseconds like the foreground boot, not after the
      # 90 s spawn timeout.
      assert_port_free(port)
      assert_port_free(port + 1)
      args = ["--port", port.to_s]
      args.concat(["--dev-log", dev_log]) if dev_log
      Client.spawn_daemon(*args)
      daemon = Client.wait_for { Client.info(base_url: "http://localhost:#{port}") }
      daemon.is_a?(Hash) ? daemon : nil
    end

    def start(port: Client::DEFAULT_PORT, install: Install.from_env, log: $stderr)
      rules_dir = Dir.mktmpdir("se-rules")
      # The enabled IDs come from the staged file, so what LT loads
      # and what each request enables can never diverge.
      staged = stage_rules(rules_dir)
      enabled_rules = SimpleEnglish::LanguageTool.rule_ids
      daemon_info = {"version" => VERSION, "pid" => Process.pid,
                     "gem_digest" => Fingerprint.gem,
                     "rules_digest" => Fingerprint.sha(File.read(staged))}
      # Preflight everything the replacement needs before the
      # takeover stops the old daemon.
      preflight_install(install)
      takeover(port)
      assert_port_free(port)
      # The inner JVM lives on port + 1. Guard it too so an occupied
      # inner port raises in milliseconds instead of timing out later.
      assert_port_free(port + 1)
      # The inner JVM's stderr goes to a file so failure messages can quote
      # its first line. Only an explicitly opened dev log (a File) is reused
      # for that. $stderr reports path "<STDERR>", so it creates a file
      # by that name in the CWD. Anything else falls back to a temp file
      # that Ruby unlinks when the process exits.
      inner_log_path =
        if log.is_a?(File)
          log.path
        else
          inner_log = Tempfile.new("se-inner")
          inner_log.close
          inner_log.path
        end
      inner = spawn_inner(install: install, port: port + 1, rules_dir: rules_dir,
        log_path: inner_log_path)
      # TCPServer.new binds synchronously: construction means ready, so
      # callers need no readiness polling. Closing the socket makes the
      # serving loop's select raise and the loop exit.
      server = TCPServer.new(port)
      inner_died = false
      # Closing the listening socket does not interrupt a syscall already
      # blocked on the old fd, so the serving loop selects with a short
      # timeout: the next IO.select on a closed socket raises IOError, so
      # every shutdown path (trap, inner-death monitor) exits the loop
      # within the timeout, on every platform.
      stop_server = proc do
        server.close
      rescue IOError
        # Already closed by another shutdown path.
      end
      # The monitor reaps the inner process, so nil it in the callback to
      # keep the cleanup idempotent against the already-reaped pid.
      monitor = monitor_inner(inner, on_death: proc do
        inner = nil
        inner_died = true
        stop_server.call
      end)
      trap("INT") { stop_server.call }
      trap("TERM") { stop_server.call }
      (log.respond_to?(:puts) ? log : $stderr).puts "se listening on http://localhost:#{port}"
      loop do
        ready = IO.select([server], nil, nil, 0.5)
        # Select timeout on an idle socket: loop back and select again.
        next if ready.nil?
        client = server.accept
        Thread.new(client) { |c|
          HTTP.handle_client(c, port: port,
            enabled_rules: enabled_rules, info: daemon_info)
        }
      rescue IOError, Errno::EBADF
        # A trap or the inner-death monitor closed the listener. This
        # happens during the select, or between select and accept.
        break
      end
      monitor.kill if monitor.alive?
      raise InnerDied, "inner LanguageTool server died. Rerun se serve." if inner_died
    ensure
      if inner
        begin
          Process.kill("TERM", inner)
          Process.wait(inner)
        rescue Errno::ESRCH, Errno::ECHILD
          # The monitor thread already reaped the inner process.
        end
      end
      monitor&.kill if monitor&.alive?
      FileUtils.remove_entry(rules_dir) if rules_dir
    end

    # Reaps the inner process and runs on_death (which stops the outer
    # server) whenever it exits, so the daemon dies instead of serving
    # without LanguageTool behind it.
    def monitor_inner(pid, on_death:)
      Thread.new do
        Process.wait(pid)
        on_death.call
      end
    end

    # Boots the inner LanguageTool server and blocks until it answers
    # /v2/check. Raises InnerDied when it dies during startup, and
    # InnerTimeout when it never becomes ready (the child is killed and
    # reaped first, so a failed boot leaks no JVM). Both messages quote
    # the inner log's first line.
    def spawn_inner(install:, port:, rules_dir:, log_path:)
      raise Install::SetupError, install.setup_error unless File.exist?(install.server_jar)
      java = install.java!
      begin
        pid = Process.spawn(java,
          "-cp", [install.server_jar, rules_dir].join(File::PATH_SEPARATOR),
          "org.languagetool.server.HTTPServer", "--port", port.to_s,
          out: File::NULL, err: log_path)
      rescue Errno::ENOENT
        # The java lookup can resolve to a path that no longer exists.
        # Quote what was resolved so the crash names its cause.
        raise ServerError, "cannot exec #{java.inspect}."
      end
      ready = false
      died = false
      deadline = Time.now + SimpleEnglish::LanguageTool::TIMEOUT_SECONDS
      until ready || died || Time.now > deadline
        # A JVM that dies instantly must not be polled for the full timeout.
        # WNOHANG reaps it here, so nothing else may wait on this pid after.
        died = !!Process.wait(pid, Process::WNOHANG)
        break if died
        begin
          Net::HTTP.post_form(URI("http://localhost:#{port}/v2/check"),
            {"language" => "en", "text" => "a"})
          ready = true
        rescue SystemCallError
          sleep 0.5
        end
      end
      if died
        raise InnerDied,
          "inner LanguageTool server exited during startup. " \
          "First log line: #{first_log_line(log_path)}"
      end
      unless ready
        kill_and_reap(pid)
        raise InnerTimeout,
          "inner LanguageTool server did not start " \
          "within #{SimpleEnglish::LanguageTool::TIMEOUT_SECONDS} seconds. " \
          "First log line: #{first_log_line(log_path)}"
      end
      pid
    end

    def kill_and_reap(pid)
      Process.kill("TERM", pid)
      Process.wait(pid)
    rescue SystemCallError
    end

    def first_log_line(path)
      File.read(path).split("\n").first || "unknown"
    rescue SystemCallError
      "unknown"
    end
  end
end
