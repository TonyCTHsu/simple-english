# frozen_string_literal: true

# UTF-16 code-unit arithmetic. LanguageTool is a Java service, and
# Java strings count UTF-16 code units: an astral-plane character
# counts as two. Every offset crossing the LT wire goes through
# here.

module SimpleEnglish
  module UTF16
    module_function

    # The character index in text where the offsetth code unit
    # falls.
    def index(text, offset)
      units = 0
      text.each_char.with_index do |char, index|
        return index if units >= offset
        units += (char.ord > 0xFFFF) ? 2 : 1
      end
      text.length
    end

    # The code-unit length of text.
    def length(text)
      text.each_char.sum { |char| (char.ord > 0xFFFF) ? 2 : 1 }
    end

    # The 1-based code-unit column of the character at index to.
    def column(source, from, to)
      length(source[from...to]) + 1
    end
  end
end
