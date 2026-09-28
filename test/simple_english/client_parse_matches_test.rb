# frozen_string_literal: true

require_relative "test_helper"

require "json"

class ClientParseMatchesTest < Minitest::Test
  MATCHES = [
    {
      "message" => "Write the words in full. No contractions.",
      "offset" => 12,
      "rule" => {"id" => "SE_NO_CONTRACTIONS"}
    },
    {
      "message" => "Split it.",
      "offset" => 20,
      "rule" => {"id" => "SE_SENTENCE_TOO_LONG"}
    }
  ].freeze

  def test_parse_matches_converts_offsets_to_lines
    text = "first line\nsecond line"
    findings = SimpleEnglish::Client.parse_matches(MATCHES, text)
    assert_equal [
      [2, "SE_NO_CONTRACTIONS", "Write the words in full. No contractions."],
      [2, "SE_SENTENCE_TOO_LONG", "Split it."]
    ], findings.map { |f| [f.line, f.rule, f.message] }
  end

  def test_parse_matches_empty
    assert_empty SimpleEnglish::Client.parse_matches([], "anything")
  end

  def test_parse_matches_prefixes_the_offending_text
    matches = [{
      "message" => "Write \"use\".",
      "offset" => 4,
      "rule" => {"id" => "SE_SLOP_LEVERAGE"},
      "context" => {"text" => "You should leverage this",
                    "offset" => 11, "length" => 8}
    }]
    findings = SimpleEnglish::Client.parse_matches(matches, "You should leverage this")
    assert_equal "\"leverage\" - Write \"use\".", findings.first.message
  end

  def test_parse_matches_keeps_the_message_without_context
    matches = [{
      "message" => "Write \"use\".", "offset" => 4,
      "rule" => {"id" => "SE_SLOP_LEVERAGE"}
    }]
    findings = SimpleEnglish::Client.parse_matches(matches, "You should leverage this")
    assert_equal "Write \"use\".", findings.first.message
  end
end
