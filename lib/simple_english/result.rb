# frozen_string_literal: true

module SimpleEnglish
  module AnnotatedText
    # The payload for code comments. Duck interface shared with
    # Client::PlainText: #lt_params (the form data for LanguageTool)
    # and #locate (a match offset back to file line and column).
    Result = Struct.new(:source, :segments, :stream) do
      def lt_params
        {"data" => SimpleEnglish::AnnotatedText.data_json(self)}
      end

      def locate(utf16_offset)
        SimpleEnglish::AnnotatedText.locate(self, utf16_offset)
      end
    end
  end
end
