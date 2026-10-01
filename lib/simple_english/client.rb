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

    # The daemon handshake: GET / answers {version, pid, gem_digest,
    # rules_digest}. Returns the handshake Hash for an se daemon,
    # :foreign for a reachable responder that is not one (an older
    # release, a foreign service) - those still lint, the caller
    # cannot check them - or nil when nothing answers. Unreachable
    # means boot. Foreign means lint but say so.
    def info(base_url: url)
      uri = URI(base_url)
      response = Net::HTTP.start(uri.host, uri.port, open_timeout: 1,
        read_timeout: 2) { |http| http.get("/") }
      return :foreign unless response.is_a?(Net::HTTPSuccess)
      data = JSON.parse(response.body)
      # The whole contract or nothing: a responder with a string pid
      # or a missing field is not a daemon we can reason about.
      return :foreign unless data.is_a?(Hash) &&
        data["version"].is_a?(String) && data["pid"].is_a?(Integer) &&
        data["pid"].positive? && data["gem_digest"].is_a?(String) &&
        data["rules_digest"].is_a?(String)
      data
    rescue Errno::ECONNRESET, Errno::EPIPE, EOFError, Net::ReadTimeout,
      JSON::ParserError, TypeError
      # Something holds the port but answers nothing usable. A read
      # timeout is that too: the request went out, nothing came back.
      :foreign
    rescue Errno::ECONNREFUSED, SocketError, Timeout::Error
      nil
    end

    # True when the daemon answers. Starts it when the port is
    # cold and we own the default URL. A running daemon is never
    # replaced by a lint: `se serve` owns that. A custom
    # SE_SERVER_URL belongs to someone else, so never spawn against
    # it. It returns false when unusable. The caller owns the exit
    # status. Diagnostics go to stderr here, where the cause is
    # known.
    def ensure_up(install: SimpleEnglish::Install.from_env)
      daemon = info
      return boot(install) if daemon.nil?
      check_daemon(daemon)
    end

    # An answered probe, classified and said out loud: a foreign
    # responder, another project's staged rules, or a different
    # build. Returns true: there is a daemon to lint against, so
    # the lint proceeds. Every path that holds a handshake result
    # goes through here, so no caller can lint silently.
    def check_daemon(daemon)
      # Reachable but not handshake-capable (an older release, a
      # foreign service): lint against it, there is nothing to check
      # or replace automatically. Say so: a silent stale lint is the
      # bug the handshake exists to catch.
      if daemon == :foreign
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
      warn_mismatched_code(daemon)
      true
    end

    # The daemon is unreachable. Start it when we own the default
    # URL, fail fast otherwise.
    def boot(install)
      if ENV["SE_SERVER_URL"]
        warn "error: SE_SERVER_URL is set but #{url} does not answer."
        return false
      end
      # Preflight everything the spawn needs: a missing prerequisite
      # must fail fast with the real blocker named, not spawn a
      # doomed child and wait out 90 s.
      unless File.exist?(install.server_jar) && install.java?
        warn(install.java? ? install.setup_error : install.java_message)
        return false
      end
      # One boot at a time: a concurrent lint that also found the
      # port cold waits here, re-checks, and skips its own spawn.
      # Whatever answers on wake is classified like the first probe:
      # the loser must get the same warnings, never a silent lint
      # against the winner's rules or build.
      with_spawn_lock(install) do
        daemon = info
        unless daemon
          warn "se: daemon not running; starting it (first lint takes ~15s)..."
          spawn_daemon
          daemon = wait_for { info }
        end
        if daemon
          check_daemon(daemon)
        else
          warn "error: se daemon did not come up. Run `se serve` and read its output."
          false
        end
      end
    end

    # The daemon runs different code: older, or another build of
    # this version (a dev checkout beside the installed gem). A
    # lint never stops a daemon: `se serve` owns replacement. Say
    # what runs and how to fix it, then lint against it: a stale
    # lint with a warning beats a refused lint.
    def warn_mismatched_code(daemon)
      if newer_daemon?(daemon)
        # `se serve` from this install boots an older daemon in its
        # place. The fix is updating this gem, not the daemon.
        warn "se: daemon at #{url} runs se #{daemon["version"]}, newer than this install " \
          "(#{VERSION}). Update this gem. Linting against it meanwhile."
        return
      end
      fix = ENV["SE_SERVER_URL"] ? "It is not restarted automatically." :
        "Run `se serve` to restart it."
      warn "se: daemon at #{url} runs se #{daemon["version"]}, different code than this install " \
        "(#{VERSION}). #{fix} Linting against it meanwhile."
    end

    # A lock file in the install's cache dir: per user by default,
    # and it follows SE_CACHE_DIR to whatever machine the cache sits
    # on. flock releases when the block ends, even on failure.
    def with_spawn_lock(install)
      FileUtils.mkdir_p(install.cache_dir)
      File.open(File.join(install.cache_dir, "spawn.lock"), "w") do |lock|
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
    # as not newer, so the warning path decides what to do with it.
    def newer_daemon?(daemon)
      Gem::Version.new(daemon["version"]) > Gem::Version.new(VERSION)
    rescue ArgumentError
      false
    end

    private_class_method :boot, :check_daemon, :warn_mismatched_code,
      :warn_stale_rules, :expected_rules_digest, :spawn_daemon, :wait_for,
      :newer_daemon?, :with_spawn_lock
  end
end
