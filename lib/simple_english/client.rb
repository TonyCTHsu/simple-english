# frozen_string_literal: true

# HTTP client for the LanguageTool server and the se daemon.

require "json"
require "net/http"
require "rbconfig"
require "fileutils"
require "uri"

require_relative "plain_text"
require_relative "languagetool"
require_relative "fingerprint"
require_relative "version"

module SimpleEnglish
  module Client
    module_function

    # LanguageTool reports offsets and lengths in Java UTF-16 code units.
    # Return a 1-based line and UTF-16 column for its 0-based offset.
    def offset_to_position(text, offset)
      line = 1
      column = 1
      units = 0
      text.each_char do |char|
        return [line, column] if units >= offset
        units += (char.ord > 0xFFFF) ? 2 : 1
        if char == "\n"
          line += 1
          column = 1
        else
          column += (char.ord > 0xFFFF) ? 2 : 1
        end
      end
      [line, column]
    end

    DEFAULT_PORT = 8181
    REQUEST_TIMEOUT = 30

    def url
      ENV.fetch("SE_SERVER_URL") { "http://localhost:#{DEFAULT_PORT}" }
    end

    def post(uri, params, read_timeout: REQUEST_TIMEOUT)
      Net::HTTP.start(uri.host, uri.port, open_timeout: 5,
        read_timeout: read_timeout) do |http|
        request = Net::HTTP::Post.new(uri.request_uri)
        request.set_form_data(params)
        http.request(request)
      end
    end

    private_class_method :post

    # Pattern rules. `payload` is Markdown-stripped text (String) or an
    # AnnotatedText::Result (code comments): one payload interface,
    # #lt_params and #locate, either side of the daemon's LT request.
    # The caller owns the enabled rule IDs (the daemon captures them
    # at boot). There is no default, so no call silently drops BYOR
    # rules.
    def check(payload, enabled_rules:, base_url: url)
      payload = to_payload(payload)
      params = {"language" => "en",
                "enabledRules" => Array(enabled_rules).join(","),
                "enabledOnly" => "true"}.merge(payload.lt_params)
      response = post(URI("#{base_url}/v2/check"), params)
      parse_matches(JSON.parse(response.body).fetch("matches"), payload)
    end

    def parse_matches(matches, payload)
      payload = to_payload(payload)
      matches.map do |match|
        offset = match.fetch("offset")
        line, column = payload.locate(offset)
        end_line, end_column = payload.locate(offset + match.fetch("length"))
        Finding.new(line: line, column: column,
          end_line: end_line, end_column: end_column,
          rule: match.fetch("rule").fetch("id"),
          message: with_context(match.fetch("message"), match))
      end
    end

    # Prefix the offending text, so a finding says what to change,
    # not only how. Context positions use Java UTF-16 code units.
    def with_context(message, match)
      context = match["context"] or return message
      matched = utf16_slice(context.fetch("text", ""),
        context.fetch("offset", 0).to_i, context.fetch("length", 0).to_i)
      matched.empty? ? message : "\"#{matched}\" - #{message}"
    end

    def utf16_slice(text, offset, length)
      first = utf16_index(text, offset)
      last = utf16_index(text, offset + length)
      text[first...last]
    end

    def utf16_index(text, offset)
      units = 0
      text.each_char.with_index do |char, index|
        return index if units >= offset
        units += (char.ord > 0xFFFF) ? 2 : 1
      end
      text.length
    end

    def to_payload(payload)
      payload.is_a?(String) ? PlainText.new(payload) : payload
    end

    private_class_method :to_payload, :with_context, :utf16_slice, :utf16_index

    # Full lint via the se daemon. Raw Markdown in, or code
    # source with a language for the comment pipeline. nil when
    # unreachable or the response is unusable, so callers can fall
    # back without seeing a stack trace.
    def lint(text, base_url: url, language: nil)
      params = {"text" => text}
      params["language"] = language if language
      response = post(URI("#{base_url}/lint"), params)
      return nil unless response.is_a?(Net::HTTPSuccess)
      body = JSON.parse(response.body)
      return nil unless body.is_a?(Array)
      body.map do |hash|
        Finding.new(line: hash.fetch("line"), column: hash["column"],
          end_line: hash["end_line"], end_column: hash["end_column"],
          rule: hash.fetch("rule"), message: hash.fetch("message"))
      end
    rescue SystemCallError, SocketError, Timeout::Error,
      JSON::ParserError, TypeError
      nil
    end

    def up?(base_url: url)
      uri = URI(base_url)
      Net::HTTP.start(uri.host, uri.port, open_timeout: 1,
        read_timeout: 2) { |http| http.head("/") }
      true
    rescue Errno::ECONNREFUSED, SocketError, Timeout::Error
      false
    end

    # The daemon handshake: GET / answers {version, pid, gem_digest,
    # rules_digest}. nil when unreachable, or when the responder is
    # not a handshake-capable se daemon (an older release, a foreign
    # service) - those still lint, the caller cannot check them.
    def info(base_url: url)
      uri = URI(base_url)
      response = Net::HTTP.start(uri.host, uri.port, open_timeout: 1,
        read_timeout: 2) { |http| http.get("/") }
      return nil unless response.is_a?(Net::HTTPSuccess)
      data = JSON.parse(response.body)
      # The whole contract or nothing: a responder with a string pid
      # or a missing field is not a daemon we can reason about, and
      # letting it through crashes the restart probe later.
      return nil unless data.is_a?(Hash) &&
        data["version"].is_a?(String) && data["pid"].is_a?(Integer) &&
        data["pid"].positive? && data["gem_digest"].is_a?(String) &&
        data["rules_digest"].is_a?(String)
      data
    rescue Errno::ECONNREFUSED, Errno::ECONNRESET, Errno::EPIPE,
      SocketError, Timeout::Error, EOFError, JSON::ParserError, TypeError
      nil
    end

    # True when the daemon answers. Starts or restarts it when we own
    # the default URL. A custom SE_SERVER_URL belongs to someone
    # else, so never spawn or kill against it. It returns false when
    # unusable. The caller owns the exit status. Diagnostics go to
    # stderr here, where the cause is known.
    def ensure_up(install: SimpleEnglish::Install.from_env)
      return boot(install) unless up?
      daemon = info
      # Reachable but not handshake-capable (an older release, a
      # foreign service): lint against it, there is nothing to check
      # or restart automatically. Say so: a silent stale lint is the
      # bug the handshake exists to catch.
      if daemon.nil?
        if ENV["SE_SERVER_URL"]
          warn "se: daemon at #{url} is not a handshake-capable se daemon. " \
            "Update it (pull a newer image or rebuild). " \
            "It is not restarted automatically."
        else
          warn "se: daemon at #{url} is not a handshake-capable se daemon. " \
            "Run `se serve` to replace it."
        end
        return true
      end
      if daemon["gem_digest"] == Fingerprint.gem
        warn_stale_rules(daemon)
        return true
      end
      restart(daemon, install: install)
    end

    # The daemon is unreachable. Start it when we own the default
    # URL, fail fast otherwise.
    def boot(install)
      if ENV["SE_SERVER_URL"]
        warn "error: SE_SERVER_URL is set but #{url} does not answer."
        return false
      end
      # Preflight everything the replacement needs, like the restart
      # path: a missing prerequisite must fail fast with the real
      # blocker named, not spawn a doomed child and wait out 90 s.
      unless File.exist?(install.server_jar) && install.java?
        warn(install.java? ? install.setup_error : install.java_message)
        return false
      end
      warn "se: daemon not running; starting it (first lint takes ~15s)..."
      spawn_daemon
      ok = wait_for { up? }
      warn "error: se daemon did not come up. Run `se serve` and read its output." unless ok
      ok
    end

    # The daemon runs different code: older, or another build of
    # this version (a dev checkout beside the installed gem). Stop it
    # through the takeover in `se serve` (graceful TERM only) and
    # boot this gem's daemon. Newer daemons never get here, because
    # the guard below keeps them running. Every unfixable mismatch
    # ends in warn + lint: a stale lint with a warning beats a
    # refused lint.
    def restart(daemon, install:)
      if newer_daemon?(daemon)
        # Never downgrade: restarting a newer daemon boots the
        # caller's older build in its place. The fix is updating
        # this gem, not touching the daemon.
        warn "se: daemon at #{url} runs se #{daemon["version"]}, newer than this install " \
          "(#{VERSION}). Update this gem. Linting against it meanwhile."
        return true
      end
      if ENV["SE_SERVER_URL"]
        warn "se: daemon at #{url} runs se #{daemon["version"]}, different code than this install. " \
          "SE_SERVER_URL is set, so it is not restarted automatically."
        return true
      end
      unless File.exist?(install.server_jar) && install.java?
        # Preflight everything the replacement needs: the child
        # takeover stops the old daemon before its own boot errors,
        # so a missing prerequisite leaves no daemon at all.
        fix = install.java? ? install.setup_error : install.java_message
        warn "se: daemon at #{url} runs se #{daemon["version"]}, different code than this install. " \
          "#{fix} Linting against it meanwhile."
        return true
      end
      begin
        # Signal 0 probes existence: a container daemon reports a pid
        # from its own namespace, and a same-machine daemon can belong
        # to another user. Either way TERMing it fails or is wrong,
        # and the replacement stalls on the occupied port.
        Process.kill(0, daemon["pid"])
      rescue Errno::ESRCH, Errno::EPERM
        warn "se: daemon at #{url} runs se #{daemon["version"]}, different code than this install, " \
          "but its pid is not signalable from here (container or another user). " \
          "It is not restarted. Linting against it meanwhile."
        return true
      end
      warn "se: daemon runs different code than this install (se #{daemon["version"]}), " \
        "restarting (takes ~15s)..."
      # One restarter at a time: a second lint that saw the same
      # stale digest waits here and re-reads the handshake on wake,
      # so it never TERMs the fresh daemon the winner booted.
      with_restart_lock(install) do
        fresh = info
        if fresh&.dig("gem_digest") == Fingerprint.gem
          # The winner linted from another CWD, so its rules can
          # differ from this project's: run the same rules check as
          # the main lint path before returning.
          warn_stale_rules(fresh)
          return true
        end
        spawn_daemon
        # The old daemon answers until the takeover stops it. Wait for
        # the replacement to answer with this code's digest.
        expected = Fingerprint.gem
        ok = wait_for { info&.dig("gem_digest") == expected }
        warn "error: se daemon did not come up. Run `se serve` and read its output." unless ok
        return ok
      end
    end

    # A lock file in the install's cache dir: per user by default,
    # and it follows SE_CACHE_DIR to whatever machine the cache sits
    # on. flock releases when the block ends, even on failure.
    def with_restart_lock(install)
      FileUtils.mkdir_p(install.cache_dir)
      File.open(File.join(install.cache_dir, "restart.lock"), "w") do |lock|
        lock.flock(File::LOCK_EX)
        yield
      end
    end

    # BYOR froze the daemon's rule set at boot. Different merged rules
    # (an edited file, or a daemon booted in another project) lint
    # wrong for the rules the user owns: say so, restart stays
    # explicit.
    def warn_stale_rules(daemon)
      expected = expected_rules_digest
      return if expected.nil? || expected == daemon["rules_digest"]
      warn "se: daemon loaded different rules than this project's config. Run `se serve` to reload."
    end

    # The digest this CWD's config stages. nil when the config or
    # a rules file is broken: warn the cause, then lint against the
    # daemon's rules rather than say nothing at all.
    def expected_rules_digest
      Fingerprint.sha(SimpleEnglish::Server.merged_rules(Config.load[:rules]))
    rescue SimpleEnglish::Config::ConfigError, SimpleEnglish::Server::ServerError => e
      warn "se: could not compare the daemon's rules with this project's config: #{e.message}"
      nil
    end

    def spawn_daemon
      bin = File.expand_path("../../bin/se", __dir__)
      Process.spawn(RbConfig.ruby, bin, "serve", out: File::NULL, err: File::NULL)
    end

    def wait_for(seconds: 90)
      deadline = Time.now + seconds
      until Time.now > deadline
        result = yield
        return result if result
        sleep 0.5
      end
      false
    end

    # The handshake reports the daemon's version: a digest mismatch
    # alone cannot tell older from newer. A malformed version counts
    # as not newer, so the restart path decides what to do with it.
    def newer_daemon?(daemon)
      Gem::Version.new(daemon["version"]) > Gem::Version.new(VERSION)
    rescue ArgumentError
      false
    end

    private_class_method :boot, :restart, :warn_stale_rules,
      :expected_rules_digest, :spawn_daemon, :wait_for, :newer_daemon?,
      :with_restart_lock
  end
end
