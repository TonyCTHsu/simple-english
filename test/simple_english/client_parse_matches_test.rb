# frozen_string_literal: true

require_relative "test_helper"

require "json"

class ClientParseMatchesTest < Minitest::Test
  MATCHES = [
    {
      "message" => "Write the words in full. No contractions.",
      "offset" => 12,
      "length" => 6,
      "rule" => {"id" => "SE_NO_CONTRACTIONS"}
    },
    {
      "message" => "Split it.",
      "offset" => 20,
      "length" => 2,
      "rule" => {"id" => "SE_SENTENCE_TOO_LONG"}
    }
  ].freeze

  def test_parse_matches_converts_offsets_to_lines
    text = "first line\nsecond line"
    findings = SimpleEnglish::LanguageTool::Client.parse_matches(MATCHES, text)
    assert_equal [
      [2, 2, 2, 8, "SE_NO_CONTRACTIONS"],
      [2, 10, 2, 12, "SE_SENTENCE_TOO_LONG"]
    ], findings.map { |f| [f.line, f.column, f.end_line, f.end_column, f.rule] }
  end

  def test_parse_matches_empty
    assert_empty SimpleEnglish::LanguageTool::Client.parse_matches([], "anything")
  end

  def test_parse_matches_prefixes_the_offending_text
    matches = [{
      "message" => "Write \"use\".",
      "offset" => 11,
      "length" => 8,
      "rule" => {"id" => "SE_SLOP_LEVERAGE"},
      "context" => {"text" => "You should leverage this",
                    "offset" => 11, "length" => 8}
    }]
    findings = SimpleEnglish::LanguageTool::Client.parse_matches(matches, "You should leverage this")
    assert_equal "\"leverage\" - Write \"use\".", findings.first.message
  end

  def test_parse_matches_extracts_context_after_an_astral_character
    matches = [{
      "message" => "Write \"use\".",
      "offset" => 3,
      "length" => 8,
      "rule" => {"id" => "SE_SLOP_LEVERAGE"},
      "context" => {"text" => "\u{1F4A1} leverage this",
                    "offset" => 3, "length" => 8}
    }]
    findings = SimpleEnglish::LanguageTool::Client.parse_matches(matches, "\u{1F4A1} leverage this")
    assert_equal "\"leverage\" - Write \"use\".", findings.first.message
  end

  def test_parse_matches_keeps_the_message_without_context
    matches = [{
      "message" => "Write \"use\".", "offset" => 4, "length" => 8,
      "rule" => {"id" => "SE_SLOP_LEVERAGE"}
    }]
    findings = SimpleEnglish::LanguageTool::Client.parse_matches(matches, "You should leverage this")
    assert_equal "Write \"use\".", findings.first.message
  end
end
