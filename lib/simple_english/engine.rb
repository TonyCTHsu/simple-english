# frozen_string_literal: true

# The complete lint engine, daemon-side. Never call SimpleEnglish.lint_text
# here: that call probes the daemon and recurses into the server.

require "json"

module SimpleEnglish
  module Engine
    module_function

    def lint(text, base_url:, language: nil)
      enabled = SimpleEnglish::LanguageTool.rule_ids(
        [SimpleEnglish::LanguageTool::RULES_FILE, *rules_paths]
      )
      if language
        spans = SimpleEnglish::Extractor.comment_spans(text, language)
        spans.empty? ? [] :
          SimpleEnglish::Client.check(
            SimpleEnglish::AnnotatedText.build(text, spans), base_url: base_url,
            enabled_rules: enabled
          )
      else
        stripped = SimpleEnglish::Markdown.strip(text)
        (SimpleEnglish::Counts.check(stripped) +
          SimpleEnglish::Client.check(stripped, base_url: base_url,
            enabled_rules: enabled))
          .sort_by { |finding| [finding.line, finding.rule] }
      end
    end

    def lint_json(text, base_url:, language: nil)
      JSON.generate(lint(text, base_url: base_url, language: language).map(&:to_h))
    end

    # BYOR rule files from .simple-english.yml, resolved against the
    # daemon's CWD: the same files stage_rules merged at boot. A config
    # that breaks after boot must not fail every lint: fall back to the
    # built-in rules only.
    def rules_paths
      SimpleEnglish::Config.load[:rules]
    rescue SimpleEnglish::Config::ConfigError => e
      warn "se: ignoring custom rules: #{e.message}"
      []
    end

    private_class_method :rules_paths
  end
end
