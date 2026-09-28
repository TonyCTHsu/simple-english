# frozen_string_literal: true

# One lint result. The line and column are 1-based. The column is
# nil when the rule has no position within the line.

module SimpleEnglish
  Finding = Struct.new(:line, :column, :rule, :message)
end
