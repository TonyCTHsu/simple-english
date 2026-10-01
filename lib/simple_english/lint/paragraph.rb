# frozen_string_literal: true

module SimpleEnglish
  module Markdown
    # A paragraph of prose: its lines, the first line's number in the
    # source, and whether it starts with a list item (procedural text
    # gets a tighter sentence limit).
    Paragraph = Struct.new(:lines, :start_line, :procedural)
  end
end
