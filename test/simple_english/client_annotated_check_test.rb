# frozen_string_literal: true

require_relative "test_helper"

require "json"

class ClientAnnotatedCheckTest < Minitest::Test
  def test_parse_matches_with_annotated_result_gives_line_and_column
    source = "# Load the config from the path\nconfig = load(path)\n# The worker didn't write the file.\n"
    spans = [
      SimpleEnglish::Extractor::Span.new(
        text: "# Load the config from the path", start_byte: 0, end_byte: 31
      ),
      SimpleEnglish::Extractor::Span.new(
        text: "# The worker didn't write the file.", start_byte: 52, end_byte: 87
      )
    ]
    result = SimpleEnglish::AnnotatedText.build(source, spans)
    matches = [{"offset" => result.stream.index("didn't"), "length" => 6,
                "rule" => {"id" => "SE_NO_CONTRACTIONS"},
                "message" => "Write the words in full. No contractions.",
                "context" => {"text" => "...", "offset" => 0, "length" => 3}}]
    finding = SimpleEnglish::Client.parse_matches(matches, result).first
    assert_equal [3, 14], [finding.line, finding.column]
    assert_equal [3, 20], [finding.end_line, finding.end_column]
    assert_equal "SE_NO_CONTRACTIONS", finding.rule
  end

  def test_check_posts_data_param_for_annotated_result
    result = SimpleEnglish::AnnotatedText.build("# a comment\n", [
      SimpleEnglish::Extractor::Span.new(text: "# a comment", start_byte: 0, end_byte: 11)
    ])
    captured = nil
    server = StubHTTPServer.new("/v2/check" => lambda do |body|
      captured = body
      [200, {"matches" => []}.to_json]
    end)
    SimpleEnglish::Client.check(result, base_url: server.url,
      enabled_rules: SimpleEnglish::LanguageTool.rule_ids)
    server.shutdown
    assert_includes captured, "data=" # {"annotation" is URL-encoded in the body
    refute_includes captured, "text="
  end
end
