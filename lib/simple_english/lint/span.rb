# frozen_string_literal: true

module SimpleEnglish
  module Extractor
    # One comment: its text and byte range in the source file.
    Span = Struct.new(:text, :start_byte, :end_byte)
  end
end
