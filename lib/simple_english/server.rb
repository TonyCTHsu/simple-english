# frozen_string_literal: true

# The se daemon: process lifecycle only. The wire protocol lives in
# lib/simple_english/http.rb, the lint engine in lib/simple_english/engine.rb.
# Failures raise typed errors (PortInUse, SetupError, InnerDied,
# InnerTimeout). bin/se owns turning them into warnings and exit codes.

require "fileutils"
require "net/http"
require "socket"
require "tempfile"
require "tmpdir"

require_relative "install"
require_relative "config"

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
    # load from the classpath at this exact path. User rule files
    # (BYOR, from .simple-english.yml `rules:`) merge into the same
    # staged file: LT loads exactly one grammar_custom.xml per language.
    def stage_rules(dir, user_rules: [])
      target = File.join(dir, "org/languagetool/rules/en/grammar_custom.xml")
      FileUtils.mkdir_p(File.dirname(target))
      File.write(target, merged_rules(user_rules))
      target
    end

    # One <rules> root holding the children of the built-in file and
    # every user file. REXML (stdlib) rejects malformed XML here, at
    # boot, with the file named: far clearer than the JVM's boot log.
    def merged_rules(user_rules)
      require "rexml/document"
      root = REXML::Element.new("rules")
      root.add_attribute("lang", "en")
      [SimpleEnglish::LanguageTool::RULES_FILE, *user_rules].each do |path|
        doc = REXML::Document.new(File.read(path))
        if doc.root.nil?
          raise ServerError, "custom rules file #{path}: no root element"
        end
        doc.root.children.each { |child| root.add(child) }
      rescue REXML::ParseException, SystemCallError => e
        raise ServerError, "custom rules file #{path}: #{e.message}"
      end
      "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n#{root}"
    end

    # Probes both loopback families: on IPv6-first resolvers a "localhost"
    # probe falls back to IPv4 and misses an IPv6 listener.
    def assert_port_free(port)
      ["127.0.0.1", "::1"].each do |address|
        TCPServer.new(address, port).close
      rescue Errno::EADDRNOTAVAIL
        next
      end
    rescue Errno::EADDRINUSE
      raise PortInUse, port
    rescue Errno::EACCES
      raise ServerError, "port #{port} cannot be bound. Use a port above 1024."
    end

    def start(port: Client::DEFAULT_PORT, install: Install.from_env, log: $stderr)
      assert_port_free(port)
      # The inner JVM lives on port + 1. Guard it too so an occupied
      # inner port raises in milliseconds instead of timing out later.
      assert_port_free(port + 1)
      rules_dir = Dir.mktmpdir("se-rules")
      # BYOR rules come from the daemon's start directory, not the
      # lint caller's: the staged rule set is frozen at boot.
      stage_rules(rules_dir, user_rules: Config.load[:rules])
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
        Thread.new(client) { |c| HTTP.handle_client(c, port: port) }
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
