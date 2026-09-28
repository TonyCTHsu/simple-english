# frozen_string_literal: true

# HTTP client for the LanguageTool server and the se daemon.

require "json"
require "net/http"
require "rbconfig"
require "uri"

require_relative "plain_text"
require_relative "languagetool"

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
    def check(payload, base_url: url)
      payload = to_payload(payload)
      params = {"language" => "en",
                "enabledRules" => SimpleEnglish::LanguageTool.rule_ids.join(","),
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

    # True when the daemon answers. Starts it when we own the default
    # URL. A custom SE_SERVER_URL belongs to someone else, so
    # never spawn against it. It returns false when unusable. The
    # caller owns the exit status. Diagnostics go to stderr here, where the cause
    # is known.
    def ensure_up(install: SimpleEnglish::Install.from_env)
      return true if up?
      if ENV["SE_SERVER_URL"]
        warn "error: SE_SERVER_URL is set but #{url} does not answer."
        return false
      end
      unless File.exist?(install.server_jar)
        warn install.setup_error
        return false
      end
      warn "se: daemon not running; starting it (first lint takes ~15s)..."
      bin = File.expand_path("../../bin/se", __dir__)
      Process.spawn(RbConfig.ruby, bin, "serve", out: File::NULL, err: File::NULL)
      deadline = Time.now + 90
      until Time.now > deadline
        return true if up?
        sleep 0.5
      end
      warn "error: se daemon did not come up. Run `se serve` and read its output."
      false
    end
  end
end
