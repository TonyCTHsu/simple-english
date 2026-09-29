# frozen_string_literal: true

require_relative "test_helper"

class CLIFormatTest < Minitest::Test
  DAEMON_FINDINGS = [
    {"line" => 3, "column" => 17, "end_line" => 3, "end_column" => 23,
     "rule" => "SE_NO_CONTRACTIONS",
     "message" => "Write the words in full. No contractions."}
  ].to_json

  def with_stub_daemon
    server = StubHTTPServer.new("/lint" => DAEMON_FINDINGS)
    old_url = ENV["SE_SERVER_URL"]
    ENV["SE_SERVER_URL"] = server.url
    yield
  ensure
    ENV["SE_SERVER_URL"] = old_url
    server&.shutdown
  end

  def test_format_json_prints_one_object_per_finding
    out, = with_stub_daemon do
      capture_io { SimpleEnglish::CLI.run(["--format", "json", "-"]) }.first
    end
    assert_equal [{"path" => "-", "line" => 3, "column" => 17,
                   "end_line" => 3, "end_column" => 23,
                   "rule" => "SE_NO_CONTRACTIONS",
                   "message" => "Write the words in full. No contractions."}],
      JSON.parse(out)
  end

  def test_format_sarif_prints_a_sarif_log
    out, = with_stub_daemon do
      capture_io { SimpleEnglish::CLI.run(["--format", "sarif", "-"]) }.first
    end
    log = JSON.parse(out)
    assert_equal "2.1.0", log.fetch("version")
    run = log.fetch("runs").first
    assert_equal "utf16CodeUnits", run.fetch("columnKind")
    result = run.fetch("results").first
    assert_equal "SE_NO_CONTRACTIONS", result.fetch("ruleId")
    region = result.fetch("locations").first.fetch("physicalLocation").fetch("region")
    assert_equal 3, region.fetch("startLine")
    assert_equal 17, region.fetch("startColumn")
    assert_equal 3, region.fetch("endLine")
    assert_equal 23, region.fetch("endColumn")
  end

  def test_format_text_stays_the_default
    out, = with_stub_daemon do
      capture_io { SimpleEnglish::CLI.run(["-"]) }.first
    end
    assert_equal "-:3:17-23: [SE_NO_CONTRACTIONS] Write the words in full. No contractions.\n", out
  end

  def test_format_text_omits_the_range_when_column_is_absent
    server = StubHTTPServer.new("/lint" => [
      {"line" => 5, "column" => nil, "rule" => "SE_SENTENCE_TOO_LONG",
       "message" => "Split it."}
    ].to_json)
    old_url = ENV["SE_SERVER_URL"]
    ENV["SE_SERVER_URL"] = server.url
    out, = capture_io { SimpleEnglish::CLI.run(["-"]) }
    assert_equal "-:5: [SE_SENTENCE_TOO_LONG] Split it.\n", out
  ensure
    ENV["SE_SERVER_URL"] = old_url
    server&.shutdown
  end

  def test_format_text_prints_both_positions_for_a_multiline_range
    finding = SimpleEnglish::Finding.new(line: 3, column: 17,
      end_line: 4, end_column: 6, rule: "RULE", message: "Message.")
    out, = capture_io { SimpleEnglish::CLI.report([["file.md", finding]], "text") }
    assert_equal "file.md:3:17-4:6: [RULE] Message.\n", out
  end

  def test_format_text_keeps_a_start_only_location_from_an_older_daemon
    finding = SimpleEnglish::Finding.new(line: 3, column: 17,
      rule: "RULE", message: "Message.")
    out, = capture_io { SimpleEnglish::CLI.report([["file.md", finding]], "text") }
    assert_equal "file.md:3:17: [RULE] Message.\n", out
  end
end
