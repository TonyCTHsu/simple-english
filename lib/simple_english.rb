# frozen_string_literal: true

# Lint Markdown prose and code comments with the SimpleEnglish
# Plain-mode rules. Pattern rules run on LanguageTool. Counting rules
# run here.
# This file is the composition root. The pieces live in lib/simple_english/.

require_relative "simple_english/version"
require_relative "simple_english/lint/finding"
require_relative "simple_english/lint/paragraph"
require_relative "simple_english/lint/utf16"
require_relative "simple_english/lint/markdown"
require_relative "simple_english/lint/counts"
require_relative "simple_english/setup/languagetool"
require_relative "simple_english/setup/install"
require_relative "simple_english/lint/extractor"
require_relative "simple_english/lint/lint_plan"
require_relative "simple_english/lint/annotated_text"
require_relative "simple_english/lint/suppressions"
require_relative "simple_english/lint/linter"
require_relative "simple_english/setup/config"
require_relative "simple_english/setup/fingerprint"
require_relative "simple_english/client/language_tool"
require_relative "simple_english/client/daemon"
require_relative "simple_english/daemon/engine"
require_relative "simple_english/daemon/http"
require_relative "simple_english/model_context_protocol"
require_relative "simple_english/daemon/server"

module SimpleEnglish
  module_function

  # The engine: text in, findings out. LintPlan decides what kind of
  # lint this is. Both tiers share it, so they cannot drift. A nil
  # language means Markdown prose. Code lints its comments.
  # nil means unreachable: the caller decides how fatal that is.
  def lint(text, language: nil)
    plan = LintPlan.call(text, language)
    return [] if plan.nil?
    return nil unless Client.ensure_up(install: Install.from_env)
    findings = Client.lint(text, language: language)
    if findings.nil?
      warn "error: se daemon did not answer. Run `#{Client.runner} serve` and read its output."
      return nil
    end
    Suppressions.filter(text, findings)
  end
end
