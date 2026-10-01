# frozen_string_literal: true

require "minitest/autorun"
require "socket"
require_relative "test_helper"

# Live LanguageTool round trip: comment -> AnnotatedText -> /v2/check ->
# source range. Needs java and the LanguageTool cache (CI has both).
# Run `bin/se setup` to fill the cache.
class RoundtripTest < Minitest::Test
  FIXTURE = "# Load the config from the path\n" \
            "config = load(path)\n" \
            "# The worker didn't write the file.\n"

  def skip_unless_lt
    install = SimpleEnglish::Install.from_env
    skip "needs java and the LanguageTool cache" unless File.exist?(install.commandline_jar) &&
      install.java?
  end

  def start_lt(port, rules_dir)
    install = SimpleEnglish::Install.from_env
    pid = Process.spawn(install.java!,
      "-cp", [install.server_jar, rules_dir].join(File::PATH_SEPARATOR),
      "org.languagetool.server.HTTPServer", "--port", port.to_s,
      out: File::NULL, err: File::NULL)
    deadline = Time.now + 90
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
    skip_unless_lt
    pid = nil
    in_tmpdir do |rules_dir|
      SimpleEnglish::Server.stage_rules(rules_dir)
      probe = TCPServer.new("127.0.0.1", 0)
      port = probe.addr[1]
      probe.close
      pid = start_lt(port, rules_dir)
      spans = SimpleEnglish::Extractor.comment_spans(FIXTURE, "python")
      result = SimpleEnglish::AnnotatedText.build(FIXTURE, spans)
      findings = SimpleEnglish::LTApi.check(result, base_url: "http://localhost:#{port}",
        enabled_rules: SimpleEnglish::LanguageTool.rule_ids)
      finding = findings.find { |f| f.rule == "SE_NO_CONTRACTIONS" }
      refute_nil finding, findings.map(&:rule).inspect
      # LT splits "didn't" into the tokens "did" and "n't". se: ignore
      # The match region is "n't". se: ignore
      # whose n is column 17 on line 3.
      assert_equal [3, 17], [finding.line, finding.column]
      assert_equal [3, 20], [finding.end_line, finding.end_column]
    ensure
      Process.kill("TERM", pid) if pid
      Process.wait(pid) if pid
    end
  end
end
