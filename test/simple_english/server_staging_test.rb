# frozen_string_literal: true

require_relative "test_helper"

require "fileutils"
require "tmpdir"

class ServerStagingTest < Minitest::Test
  USER_RULES = <<~XML
    <?xml version="1.0" encoding="UTF-8"?>
    <rules lang="en">
      <rule id="MY_TEAM_RULE" name="No foobar">
        <pattern><token>foobar</token></pattern>
        <message>Do not write foobar.</message>
      </rule>
    </rules>
  XML

  def test_stage_rules_copies_to_classpath_layout
    Dir.mktmpdir do |dir|
      staged = SimpleEnglish::Server.stage_rules(dir)
      assert_equal File.join(dir, "org/languagetool/rules/en/grammar_custom.xml"), staged
      assert File.read(staged).start_with?("<?xml")
      assert_includes SimpleEnglish::LanguageTool.rule_ids([staged]), "SE_NO_CONTRACTIONS"
    end
  end

  def test_stage_rules_merges_user_rules_into_the_staged_file
    Dir.mktmpdir do |dir|
      user = File.join(dir, "team.xml")
      File.write(user, USER_RULES)
      staged = SimpleEnglish::Server.stage_rules(dir, user_rules: [user])
      ids = SimpleEnglish::LanguageTool.rule_ids([staged])
      assert_includes ids, "SE_NO_CONTRACTIONS"
      assert_includes ids, "MY_TEAM_RULE"
    end
  end

  def test_stage_rules_names_the_file_on_malformed_xml
    Dir.mktmpdir do |dir|
      user = File.join(dir, "broken.xml")
      File.write(user, "<rules lang=\"en\"><rule id=\"X\">")
      error = assert_raises(SimpleEnglish::Server::ServerError) do
        SimpleEnglish::Server.stage_rules(dir, user_rules: [user])
      end
      assert_match(/broken\.xml/, error.message)
    end
  end
end
