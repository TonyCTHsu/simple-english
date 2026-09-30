# frozen_string_literal: true

# The complete lint engine, daemon-side. Never call SimpleEnglish.lint_text
# here: that call probes the daemon and recurses into the server.
# The engine reads nothing from disk: the caller captures the enabled
# rule IDs once at daemon boot (Server.start) and passes them in.

require "json"

module SimpleEnglish
  module Engine
    module_function

    def lint(text, base_url:, language: nil,
      enabled_rules: SimpleEnglish::LanguageTool.rule_ids)
      if language
        spans = SimpleEnglish::Extractor.comment_spans(text, language)
        spans.empty? ? [] :
          SimpleEnglish::Client.check(
            SimpleEnglish::AnnotatedText.build(text, spans), base_url: base_url,
            enabled_rules: enabled_rules
          )
      else
        stripped = SimpleEnglish::Markdown.strip(text)
        (SimpleEnglish::Counts.check(stripped) +
          SimpleEnglish::Client.check(stripped, base_url: base_url,
            enabled_rules: enabled_rules))
          .sort_by { |finding| [finding.line, finding.rule] }
      end
    end

    def lint_json(text, base_url:, language: nil,
      enabled_rules: SimpleEnglish::LanguageTool.rule_ids)
      JSON.generate(lint(text, base_url: base_url, language: language,
        enabled_rules: enabled_rules).map(&:to_h))
    end
  end
end
