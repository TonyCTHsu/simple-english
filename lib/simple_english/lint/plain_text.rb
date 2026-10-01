# frozen_string_literal: true

module SimpleEnglish
  # The plain-text payload for /v2/check, duck-compatible with
  # AnnotatedText::Result: #lt_params and #locate.
  PlainText = Struct.new(:text) do
    def lt_params
      {"text" => text}
    end

    # LanguageTool reports offsets in Java UTF-16 code units.
    # Return a 1-based line and UTF-16 column for a 0-based offset.
    def locate(utf16_offset)
      line = 1
      column = 1
      units = 0
      text.each_char do |char|
        return [line, column] if units >= utf16_offset
        units += (char.ord > 0xFFFF) ? 2 : 1
        if char == "\n"
          line += 1
          column = 1
        else
          column += (char.ord > 0xFFFF) ? 2 : 1
        end
      end
      [line, column]
    end
  end
end
