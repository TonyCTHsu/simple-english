# frozen_string_literal: true

require "minitest/autorun"
require "socket"
require "tmpdir"
require_relative "../../lib/simple_english"

# Live LanguageTool round trip: comment -> AnnotatedText -> /v2/check ->
# line and column. Needs java and the LanguageTool cache (CI has both).
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

  def test_se_no_contractions_lands_on_line_3_column_14
    skip_unless_lt
    pid = nil
    Dir.mktmpdir do |rules_dir|
      SimpleEnglish::Server.stage_rules(rules_dir)
      probe = TCPServer.new("127.0.0.1", 0)
      port = probe.addr[1]
      probe.close
      pid = start_lt(port, rules_dir)
      spans = SimpleEnglish::Extractor.comment_spans(FIXTURE, "python")
      result = SimpleEnglish::AnnotatedText.build(FIXTURE, spans)
      findings = SimpleEnglish::Client.check(result, base_url: "http://localhost:#{port}")
      finding = findings.find { |f| f.rule == "SE_NO_CONTRACTIONS" }
      refute_nil finding, findings.map(&:rule).inspect
      assert_equal 3, finding.line
      # LT splits "didn't" into the tokens "did" and "n't". se: ignore
      # The match region is "n't". se: ignore
      # whose n is column 17 on line 3.
      assert_equal 17, finding.column
    ensure
      Process.kill("TERM", pid) if pid
      Process.wait(pid) if pid
    end
  end
end
