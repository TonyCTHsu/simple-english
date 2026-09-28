# frozen_string_literal: true

# The complete lint engine, daemon-side. Never call SimpleEnglish.lint_text
# here: that call probes the daemon and recurses into the server.

require "json"

module SimpleEnglish
  module Engine
    module_function

    def lint(text, base_url:, language: nil)
      if language
        spans = SimpleEnglish::Extractor.comment_spans(text, language)
        spans.empty? ? [] :
          SimpleEnglish::Client.check(
            SimpleEnglish::AnnotatedText.build(text, spans), base_url: base_url
          )
      else
        stripped = SimpleEnglish::Markdown.strip(text)
        (SimpleEnglish::Counts.check(stripped) +
          SimpleEnglish::Client.check(stripped, base_url: base_url))
          .sort_by { |finding| [finding.line, finding.rule] }
      end
    end

    def lint_json(text, base_url:, language: nil)
      JSON.generate(lint(text, base_url: base_url, language: language).map(&:to_h))
    end
  end
end
