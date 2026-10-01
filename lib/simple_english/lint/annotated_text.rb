# frozen_string_literal: true

# LanguageTool AnnotatedText for code comments. Builds the annotation
# JSON and maps LT match offsets back to file line and UTF-16 column.
# Offsets are UTF-16 code units that count into the concatenation of
# all text and markup strings. interpretAs does not count. Semantics
# verified against a live LT 6.6 server on 2026-09-25.

require_relative "extractor"
require_relative "segment"
require_relative "result"

module SimpleEnglish
  module AnnotatedText
    # ASCII comment markers only (MARKER holds the set).
    MARKER = /\A[\/#*;%-]+/
    CLOSER = /\A.*?(\s*\*\/)\z/m

    module_function

    def build(source, spans)
      segments = []
      cursor = 0 # byte offset into source
      emit = lambda do |text:, content:, file_char:, interpret_as: nil|
        next if content.empty?
        segments << Segment.new(text: text, content: content, file_char: file_char,
          stream_start: segments.sum { |s| s.content.length }, interpret_as: interpret_as)
      end
      spans = spans.sort_by(&:start_byte)
      spans.each do |span|
        if cursor < span.start_byte
          # Interior gaps break sentences between comments. Gaps with no
          # checkable text before them (leading) change nothing.
          emit.call(text: false, content: source.byteslice(cursor...span.start_byte),
            file_char: char_index(source, cursor),
            interpret_as: (segments.any? { |s| s.text }) ? "\n\n" : nil)
        end
        marker, body, closer = split(span.text)
        file_char = char_index(source, span.start_byte)
        emit.call(text: false, content: marker, file_char: file_char, interpret_as: " ")
        emit.call(text: true, content: body, file_char: file_char + marker.length)
        unless closer.empty?
          emit.call(text: false, content: closer,
            file_char: file_char + marker.length + body.length)
        end
        cursor = span.end_byte
      end
      emit.call(text: false, content: source.byteslice(cursor..),
        file_char: char_index(source, cursor), interpret_as: nil)
      Result.new(source: source, segments: segments,
        stream: segments.map(&:content).join)
    end

    def data_json(result)
      require "json"
      JSON.generate("annotation" => result.segments.map do |segment|
        if segment.text
          {"text" => segment.content}
        else
          entry = {"markup" => segment.content}
          entry["interpretAs"] = segment.interpret_as if segment.interpret_as
          entry
        end
      end)
    end

    # -> [line, column], both 1-based. Column in UTF-16 code units.
    def locate(result, utf16_offset)
      char = utf16_to_char(result.stream, utf16_offset)
      segment = result.segments.find do |s|
        char >= s.stream_start && char < s.stream_start + s.content.length
      end || result.segments.last
      file_char = segment.file_char + (char - segment.stream_start)
      starts = line_starts(result.source)
      line = starts.rindex { |start| start <= file_char } + 1
      [line, utf16_column(result.source, starts[line - 1], file_char)]
    end

    def split(comment)
      marker = comment[MARKER] || ""
      body = comment[marker.length..] || comment
      closer = body[CLOSER] || ""
      body = body[0, body.length - closer.length] unless closer.empty?
      [marker, body, closer]
    end

    def char_index(source, byte)
      # ponytail: O(filesize) per call. If large repos make this
      # measurable, index byte->char once.
      source.byteslice(0...byte).length
    end

    def line_starts(source)
      starts = [0]
      source.chars.each_with_index { |c, i| starts << i + 1 if c == "\n" }
      starts
    end

    def utf16_to_char(stream, offset)
      units = 0
      stream.each_char.with_index do |char, index|
        return index if units >= offset
        units += (char.ord > 0xFFFF) ? 2 : 1
      end
      stream.length
    end

    def utf16_column(source, from, to)
      units = 1
      source[from...to].each_char { |c| units += (c.ord > 0xFFFF) ? 2 : 1 }
      units
    end

    private_class_method :split, :char_index, :line_starts,
      :utf16_to_char, :utf16_column
  end
end
