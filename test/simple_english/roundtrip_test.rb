# frozen_string_literal: true

require_relative "test_helper"

require "socket"

# Live native LanguageTool round trip: comment -> AnnotatedText -> /v2/check ->
# source range. Set SE_LANGUAGETOOL_EXECUTABLE for a source-tree build.
class RoundtripTest < Minitest::Test
  FIXTURE = "# Load the config from the path\n" \
            "config = load(path)\n" \
            "# The worker didn't write the file.\n"

  def start_lt(port, install)
    pid = Process.spawn(install.executable!, "--port", port.to_s,
      out: File::NULL, err: File::NULL)
    deadline = Time.now + 30
    until Time.now > deadline
      begin
        Net::HTTP.post_form(URI("http://localhost:#{port}/v2/check"),
          {"language" => "en", "text" => "a"})
        return pid
      rescue SystemCallError
        sleep 0.5
      end
    end
    Process.kill("TERM", pid)
    flunk "inner LT server never became ready"
  end

  def test_se_no_contractions_reports_the_exact_range
    install = SimpleEnglish::Install.from_env
    skip "needs native LanguageTool executable" unless install.executable?
    pid = nil
    probe = TCPServer.new("127.0.0.1", 0)
    port = probe.addr[1]
    probe.close
    pid = start_lt(port, install)
    spans = SimpleEnglish::Extractor.comment_spans(FIXTURE, "python")
    result = SimpleEnglish::AnnotatedText.build(FIXTURE, spans)
    findings = SimpleEnglish::LanguageTool::Client.check(result,
      base_url: "http://localhost:#{port}",
      enabled_rules: SimpleEnglish::LanguageTool.rule_ids)
    finding = findings.find { |item| item.rule == "SE_NO_CONTRACTIONS" }
    refute_nil finding, findings.map(&:rule).inspect
    # LT splits "didn't" into the tokens "did" and "n't". se: ignore
    # The match region is "n't". se: ignore
    # Its n is column 17 on line 3.
    assert_equal [3, 17], [finding.line, finding.column]
    assert_equal [3, 20], [finding.end_line, finding.end_column]
  ensure
    Process.kill("TERM", pid) if pid
    Process.wait(pid) if pid
  end
end
