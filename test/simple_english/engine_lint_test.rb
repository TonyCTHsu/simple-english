# frozen_string_literal: true

require_relative "test_helper"

require "stringio"
require "socket"
require "tempfile"
require "timeout"

class EngineLintTest < Minitest::Test
  LT_BODY = {
    matches: [
      {message: "No contractions.", offset: 7, length: 6,
       rule: {id: "SE_NO_CONTRACTIONS"}}
    ]
  }.to_json

  def with_stub_lt
    # Real LanguageTool returns no matches for empty text. Mirror that.
    server = StubHTTPServer.new("/v2/check" => lambda do |body|
      text = URI.decode_www_form(body).to_h["text"]
      text.to_s.strip.empty? ? {matches: []}.to_json : LT_BODY
    end)
    yield server.url
  ensure
    server&.shutdown
  end

  def test_lint_merges_counts_and_pattern_rules
    long_item = "Install the tracer and then start the service again after " \
                "the check finishes and then write the whole thing down somewhere safe."
    with_stub_lt do |url|
      findings = SimpleEnglish::Engine.lint("- #{long_item}\n", base_url: url)
      assert_includes findings.map(&:rule), "SE_SENTENCE_TOO_LONG"
      assert_includes findings.map(&:rule), "SE_NO_CONTRACTIONS"
      assert_equal findings.map { |f| [f.line, f.rule] },
        findings.map { |f| [f.line, f.rule] }.sort
    end
  end

  def test_lint_empty_text
    with_stub_lt do |url|
      assert_empty SimpleEnglish::Engine.lint("```\n\n```\n", base_url: url)
    end
  end

  def test_lint_json_is_sorted_h
    with_stub_lt do |url|
      body = JSON.parse(SimpleEnglish::Engine.lint_json("- #{"word " * 30}.\n", base_url: url))
      assert_equal "SE_NO_CONTRACTIONS", body.first["rule"]
      assert_equal "SE_SENTENCE_TOO_LONG", body.map { |hash| hash["rule"] }.last
      assert_equal %w[line column end_line end_column rule message].sort,
        body.first.keys.sort
    end
  end

  def test_lint_sends_user_rule_ids_from_the_cwd_config
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, "team.xml"), <<~XML)
        <?xml version="1.0" encoding="UTF-8"?>
        <rules lang="en">
          <rule id="MY_TEAM_RULE" name="No foobar"/>
        </rules>
      XML
      File.write(File.join(dir, ".simple-english.yml"), "rules: [team.xml]\n")
      seen = nil
      Dir.chdir(dir) do
        server = StubHTTPServer.new("/v2/check" => lambda do |body|
          seen = URI.decode_www_form(body).to_h["enabledRules"].to_s.split(",")
          LT_BODY
        end)
        SimpleEnglish::Engine.lint("Don't.\n", base_url: server.url)
        server.shutdown
      end
      assert_includes seen, "SE_NO_CONTRACTIONS"
      assert_includes seen, "MY_TEAM_RULE"
    end
  end

  def gem_available?
    require "tree_sitter_language_pack"
    true
  rescue LoadError
    false
  end

  def test_lint_with_language_lints_code_comments_only
    skip "needs tree_sitter_language_pack" unless gem_available?
    source = "# Load the config from the path\nconfig = load(path)\n# The worker didn't write the file.\n"
    server = StubHTTPServer.new("/v2/check" => lambda do |body|
      assert_includes URI.decode_www_form(body).to_h.keys, "data"
      {"matches" => [{"offset" => 11, "length" => 6,
                      "rule" => {"id" => "SE_NO_CONTRACTIONS"},
                      "message" => "Write the words in full. No contractions.",
                      "context" => {"text" => "", "offset" => 0, "length" => 0}}]}
                                    .to_json
    end)
    findings = SimpleEnglish::Engine.lint(source, base_url: server.url, language: "python")
    server.shutdown
    assert_equal 1, findings.size
    assert_equal "SE_NO_CONTRACTIONS", findings.first.rule
    assert_equal [1, 12], [findings.first.line, findings.first.column]
    assert_equal [1, 18], [findings.first.end_line, findings.first.end_column]
  end
end
