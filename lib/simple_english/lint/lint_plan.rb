# frozen_string_literal: true

# One decision, two callers: the CLI (SimpleEnglish.lint_file) and
# the daemon (Engine.lint) must agree on what kind of lint an input
# is. The CLI decides to skip comment-free files without a boot.
# The daemon decides again on its side of the wire. Both call this
# module, so the two tiers cannot drift.

module SimpleEnglish
  module LintPlan
    module_function

    # Returns :prose when there is no language (the Markdown
    # pipeline), nil for a comment-free code file (nothing to lint:
    # no boot, no POST), or the comment spans for a code file.
    def call(text, language)
      return :prose unless language
      spans = SimpleEnglish::Extractor.comment_spans(text, language)
      spans.empty? ? nil : spans
    end
  end
end
