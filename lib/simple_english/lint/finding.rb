# frozen_string_literal: true

# One lint result. Positions are 1-based. The end position is exclusive.
# Counting findings have no columns or end positions. Findings from an older
# daemon can have a start column without an end position.

module SimpleEnglish
  Finding = Struct.new(:line, :column, :end_line, :end_column, :rule, :message)
end
