# frozen_string_literal: true

require_relative "test_helper"

class LintFileReadEncodingTest < Minitest::Test
  FINDINGS = [
    {"line" => 1, "column" => 46, "end_line" => 1, "end_column" => 47,
     "rule" => "SE_NO_EMDASH",
     "message" => "Write two sentences, or use a comma."}
  ].to_json

  # A GUI app such as Claude Desktop spawns the MCP server with no LANG,
  # so Ruby reads files as US-ASCII. Prose with non-ASCII characters must
  # still lint, not crash in the suppression scan (issue 95).
  def test_non_ascii_file_lints_under_a_us_ascii_process
    Dir.mktmpdir do |dir|
      path = File.join(dir, "doc.md")
      File.binwrite(path, "# Dogfooding — one-pager\n\nThe team ships a tracer.\n")
      server = StubHTTPServer.new("/lint" => FINDINGS)
      original = Encoding.default_external
      Encoding.default_external = Encoding::US_ASCII
      with_env("SE_SERVER_URL" => server.url) do
        findings = SimpleEnglish.lint_file(path)
        assert_equal 1, findings.size
      end
    ensure
      Encoding.default_external = original
      server&.shutdown
    end
  end
end
