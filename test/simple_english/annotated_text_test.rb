# frozen_string_literal: true

require "minitest/autorun"
require "json"
require_relative "../../lib/simple_english/annotated_text"

# Pure golden tests: spans are hand-built so no gem is needed.
class AnnotatedTextTest < Minitest::Test
  SOURCE = "# Load the config from the path\n" \
           "config = load(path)\n" \
           "# The worker didn't write the file.\n"
  SPANS = [
    SimpleEnglish::Extractor::Span.new(
      text: "# Load the config from the path", start_byte: 0, end_byte: 31
    ),
    SimpleEnglish::Extractor::Span.new(
      text: "# The worker didn't write the file.", start_byte: 52, end_byte: 87
    )
  ].freeze

  def build(spans = SPANS, source = SOURCE)
    SimpleEnglish::AnnotatedText.build(source, spans)
  end

  def test_annotation_json_shape
    expected = {"annotation" => [
      {"markup" => "#", "interpretAs" => " "},
      {"text" => " Load the config from the path"},
      {"markup" => "\nconfig = load(path)\n", "interpretAs" => "\n\n"},
      {"markup" => "#", "interpretAs" => " "},
      {"text" => " The worker didn't write the file."},
      {"markup" => "\n"}
    ]}
    assert_equal expected, JSON.parse(SimpleEnglish::AnnotatedText.data_json(build))
  end

  def test_locate_finds_line_and_column
    result = build
    locate = ->(word) { SimpleEnglish::AnnotatedText.locate(result, result.stream.index(word)) }
    assert_equal [1, 3], locate.call("Load")
    assert_equal [3, 14], locate.call("didn't")
  end

  def test_locate_columns_with_astral_characters
    source = "# Set the \u{1F4A1} icon\nx = 1\n# The worker didn't write the file.\n"
    spans = [
      SimpleEnglish::Extractor::Span.new(
        text: "# Set the \u{1F4A1} icon", start_byte: 0, end_byte: 19
      ),
      SimpleEnglish::Extractor::Span.new(
        text: "# The worker didn't write the file.", start_byte: 26, end_byte: 61
      )
    ]
    result = SimpleEnglish::AnnotatedText.build(source, spans)
    prefix = result.stream[0, result.stream.index("didn't")]
    utf16_offset = prefix.each_char.sum { |c| (c.ord > 0xFFFF) ? 2 : 1 }
    assert_equal [3, 14], SimpleEnglish::AnnotatedText.locate(result, utf16_offset)
  end

  def test_locate_with_crlf_line_endings
    source = "# a didn't\r\nx = 1\r\n"
    result = SimpleEnglish::AnnotatedText.build(source, [
      SimpleEnglish::Extractor::Span.new(text: "# a didn't", start_byte: 0, end_byte: 10)
    ])
    assert_equal [1, 5], SimpleEnglish::AnnotatedText.locate(result, result.stream.index("didn't"))
  end

  def test_marker_only_comment_emits_no_text_segment
    result = SimpleEnglish::AnnotatedText.build("x = 1 #\n", [
      SimpleEnglish::Extractor::Span.new(text: "#", start_byte: 6, end_byte: 7)
    ])
    segments = JSON.parse(SimpleEnglish::AnnotatedText.data_json(result))["annotation"]
    assert_equal [{"markup" => "x = 1 "}, {"markup" => "#", "interpretAs" => " "},
      {"markup" => "\n"}], segments
  end

  def test_empty_spans_still_build
    result = SimpleEnglish::AnnotatedText.build("x = 1\n", [])
    assert_equal "x = 1\n", result.stream
  end
end
