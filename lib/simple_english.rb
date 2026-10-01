# frozen_string_literal: true

# Lint Markdown prose with the SimpleEnglish Plain-mode rules.
# Pattern rules run on LanguageTool. Counting rules run here.
# This file is the composition root. The pieces live in lib/simple_english/.

require_relative "simple_english/version"
require_relative "simple_english/finding"
require_relative "simple_english/markdown"
require_relative "simple_english/counts"
require_relative "simple_english/languagetool"
require_relative "simple_english/install"
require_relative "simple_english/extractor"
require_relative "simple_english/lint_plan"
require_relative "simple_english/annotated_text"
require_relative "simple_english/suppressions"
require_relative "simple_english/config"
require_relative "simple_english/fingerprint"
require_relative "simple_english/engine"
require_relative "simple_english/http"
require_relative "simple_english/client"
require_relative "simple_english/server"

module SimpleEnglish
  module_function

  # Returns findings, or nil when the daemon is unreachable. The
  # caller (bin/se) owns the exit status. Diagnostics go to
  # stderr here.
  def lint_text(text)
    return nil unless Client.ensure_up(install: Install.from_env)
    Client.lint(text)
  end

  # One entry point for files. LintPlan decides what kind of lint
  # this is. Both tiers share it, so they cannot drift. Code files
  # lint comments through the daemon. nil means unreachable:
  # the caller decides how fatal that is.
  def lint_file(path, text = File.read(path))
    language = Extractor.language_for(path)
    plan = LintPlan.call(text, language)
    return [] if plan.nil?
    findings =
      if plan == :prose
        lint_text(text)
      else
        return nil unless Client.ensure_up(install: Install.from_env)
        result = Client.lint(text, language: language)
        if result.nil?
          warn "error: se daemon did not answer. Run `se serve` and read its output."
        end
        result
      end
    return nil unless findings
    Suppressions.filter(text, findings)
  end
end
