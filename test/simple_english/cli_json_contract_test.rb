# frozen_string_literal: true

require_relative "test_helper"

# Contract freeze: the `se --json` shape is the interface the Claude Code
# hook parses and third parties script against. Fields may be added,
# never renamed or removed. A failure here is a Breaking changie entry.
class CLIJsonContractTest < Minitest::Test
  def lint_via_daemon(findings_json)
    server = StubHTTPServer.new("/lint" => findings_json)
    with_env("SE_SERVER_URL" => server.url) do
      with_stdin("") { capture_io { SimpleEnglish::CLI.run(["--format", "json", "-"]) }.first }
    ensure
      server&.shutdown
    end
  end

  def test_finding_object_shape_is_frozen
    out = lint_via_daemon(
      [
        {"line" => 3, "column" => 17, "end_line" => 3, "end_column" => 23,
         "rule" => "SE_NO_CONTRACTIONS",
         "message" => "Write the words in full. No contractions."},
        {"line" => 5, "column" => nil, "end_line" => nil, "end_column" => nil,
         "rule" => "SE_COUNT_WORDS", "message" => "Too many words."}
      ].to_json
    )
    objects = JSON.parse(out)
    assert_equal 2, objects.length
    assert_equal ["path", "line", "column", "end_line", "end_column", "rule", "message"],
      objects.first.keys
    assert_equal ["path", "line", "column", "end_line", "end_column", "rule", "message"],
      objects.last.keys
    assert_equal({"path" => "-", "line" => 3, "column" => 17, "end_line" => 3,
                  "end_column" => 23, "rule" => "SE_NO_CONTRACTIONS",
                  "message" => "Write the words in full. No contractions."},
      objects.first)
    assert_equal({"path" => "-", "line" => 5, "column" => nil, "end_line" => nil,
                  "end_column" => nil, "rule" => "SE_COUNT_WORDS",
                  "message" => "Too many words."},
      objects.last)
  end

  def test_clean_output_is_an_empty_array
    out = lint_via_daemon([].to_json)
    assert_equal [], JSON.parse(out)
  end
end
