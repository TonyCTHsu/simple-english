# frozen_string_literal: true

# One lint result. Positions are 1-based. The end position is exclusive.
# Counting findings have no columns or end positions. Findings from an older
# daemon can have a start column without an end position.

module SimpleEnglish
  Finding = Struct.new(:line, :column, :end_line, :end_column, :rule, :message) do
    # One finding as a text line: `path:line:col-end: [rule] message`.
    # The CLI text output, the MCP tool, and the hook feedback all share
    # this format. Keep them in step by rendering through this method.
    def to_line(path)
      location = "#{path}:#{line}"
      if column
        location += ":#{column}"
        if end_line && end_column
          finish = (end_line == line) ? end_column : "#{end_line}:#{end_column}"
          location += "-#{finish}"
        end
      end
      "#{location}: [#{rule}] #{message}"
    end
  end
end
