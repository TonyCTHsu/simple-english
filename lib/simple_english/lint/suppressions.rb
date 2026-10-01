# frozen_string_literal: true

# Inline suppressions. A line containing `se: ignore` (or
# `se: ignore=RULE1,RULE2`) suppresses findings reported on that
# same line. Pattern findings cite the line of the match, not the
# paragraph or comment start, so put the directive on the line the
# finding reports.

module SimpleEnglish
  module Suppressions
    DIRECTIVE = /se:\s*ignore\s*(?:=\s*(?<rules>[\w,]+))?/

    module_function

    def filter(source, findings)
      return findings if findings.empty?
      blocked = directives(source)
      return findings if blocked.empty?
      findings.reject do |finding|
        blocked.any? do |directive|
          directive[:line] == finding.line &&
            (directive[:rules].empty? || directive[:rules].include?(finding.rule))
        end
      end
    end

    def directives(source)
      source.lines.each_with_index.filter_map do |line, index|
        next unless (match = line.match(DIRECTIVE))
        rules = match[:rules] ? match[:rules].split(",").map(&:strip) : []
        {line: index + 1, rules: rules}
      end
    end

    private_class_method :directives
  end
end
