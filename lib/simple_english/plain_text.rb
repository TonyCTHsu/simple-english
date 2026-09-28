# frozen_string_literal: true

module SimpleEnglish
  module Client
    # The plain-text payload for /v2/check, duck-compatible with
    # AnnotatedText::Result: #lt_params and #locate.
    PlainText = Struct.new(:text) do
      def lt_params
        {"text" => text}
      end

      def locate(utf16_offset)
        [Client.offset_to_line(text, utf16_offset), nil]
      end
    end
  end
end
