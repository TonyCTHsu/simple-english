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
end
