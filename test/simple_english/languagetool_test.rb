# frozen_string_literal: true

require_relative "test_helper"

class LanguageToolHelpersTest < Minitest::Test
  def test_rule_ids_reads_the_custom_rules_file
    ids = SimpleEnglish::LanguageTool.rule_ids
    assert_includes ids, "SE_NO_CONTRACTIONS"
    assert_includes ids, "SE_NO_SEMICOLON"
  end

  def test_rule_ids_reads_rules_under_a_us_ascii_locale
    lib = File.expand_path("../../lib/simple_english", __dir__).inspect
    child = "require #{lib} and exit(SimpleEnglish::" \
      "LanguageTool.rule_ids.empty? ? 1 : 0)"
    IO.popen([{"LC_ALL" => "C", "LANG" => "C"}, RbConfig.ruby, "-e", child],
      &:read)
    assert $?.success?, "rule_ids crashed under a US-ASCII locale"
  end

  def test_rule_ids_finds_id_regardless_of_attribute_order
    in_tmpdir do |dir|
      rules = File.join(dir, "team.xml")
      File.write(rules, <<~XML)
        <?xml version="1.0" encoding="UTF-8"?>
        <rules lang="en">
          <rule name="No foobar" id="MY_TEAM_RULE"/>
          <rule id="MY_OTHER_RULE" name="No buzz"/>
          <rulegroup id="MY_GROUP" name="group">
            <rule name="sub"/>
          </rulegroup>
        </rules>
      XML
      ids = SimpleEnglish::LanguageTool.rule_ids(rules)
      assert_includes ids, "MY_TEAM_RULE"
      assert_includes ids, "MY_OTHER_RULE"
      assert_includes ids, "MY_GROUP"
      refute_includes ids, "sub"
    end
  end

  def test_lt_version_is_pinned_to_6_6
    assert_equal "6.6", SimpleEnglish::LanguageTool::LT_VERSION
  end

  def test_bundled_executable_is_under_libexec
    assert_equal File.expand_path("../../libexec/simple_english/languagetool-server",
      __dir__), SimpleEnglish::LanguageTool::BUNDLED_EXECUTABLE
  end
end
