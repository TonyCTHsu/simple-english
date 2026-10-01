# frozen_string_literal: true

# The LanguageTool wire protocol: form posts to /v2/check, and
# matches mapped back to findings. Runs daemon-side (Engine calls it
# against the inner JVM) and in tests. The se daemon client - probe,
# trust, boot - lives in client/daemon.rb.

require "json"
require "net/http"
require "uri"

require_relative "../lint/plain_text"

module SimpleEnglish
  module LTApi
    module_function

    REQUEST_TIMEOUT = 30

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
    def check(payload, enabled_rules:, base_url:)
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
  end
end
