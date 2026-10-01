# frozen_string_literal: true

module SimpleEnglish
  module AnnotatedText
    # One piece of the annotation stream: checkable comment text or
    # uncheckable markup (markers, closers, gaps between comments).
    # stream_start is the segment's offset into Result#stream.
    Segment = Struct.new(:text, :content, :file_char, :stream_start,
      :interpret_as)
  end
end
