# frozen_string_literal: true

# The complete lint engine, daemon-side. Never call SimpleEnglish.lint_text
# here: that call probes the daemon and recurses into the server.
# The engine reads nothing from disk: the caller captures the enabled
# rule IDs once at daemon boot (Server.start) and passes them in.
# LintPlan owns what kind of lint an input is. This module executes
# the plan.

require "json"

module SimpleEnglish
  module Engine
    module_function

    def lint(text, base_url:, language: nil,
      enabled_rules: SimpleEnglish::LanguageTool.rule_ids)
      plan = SimpleEnglish::LintPlan.call(text, language)
      return [] if plan.nil?
      if plan == :prose
        stripped = SimpleEnglish::Markdown.strip(text)
        (SimpleEnglish::Counts.check(stripped) +
          SimpleEnglish::Client.check(stripped, base_url: base_url,
            enabled_rules: enabled_rules))
          .sort_by { |finding| [finding.line, finding.rule] }
      else
        SimpleEnglish::Client.check(
          SimpleEnglish::AnnotatedText.build(text, plan), base_url: base_url,
          enabled_rules: enabled_rules
        )
      end
    end

    def lint_json(text, base_url:, language: nil,
      enabled_rules: SimpleEnglish::LanguageTool.rule_ids)
      JSON.generate(lint(text, base_url: base_url, language: language,
        enabled_rules: enabled_rules).map(&:to_h))
    end
  end
end
