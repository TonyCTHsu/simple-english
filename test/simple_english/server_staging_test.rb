# frozen_string_literal: true

require_relative "test_helper"

require "fileutils"

class ServerStagingTest < Minitest::Test
  def test_stage_rules_copies_to_classpath_layout
    in_tmpdir do |dir|
      staged = SimpleEnglish::Server.stage_rules(dir)
      assert_equal File.join(dir, "org/languagetool/rules/en/grammar_custom.xml"), staged
      assert_equal File.read(SimpleEnglish::LanguageTool::RULES_FILE),
        File.read(staged)
      assert_includes SimpleEnglish::LanguageTool.rule_ids(staged), "SE_NO_CONTRACTIONS"
    end
  end
end
