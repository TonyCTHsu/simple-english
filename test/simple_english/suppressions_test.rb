# frozen_string_literal: true

require "minitest/autorun"
require_relative "../../lib/simple_english"
require_relative "../../lib/simple_english/suppressions"

class SuppressionsTest < Minitest::Test
  def test_directive_without_rules_suppresses_the_whole_line
    source = "# se: ignore\nx = 1\n"
    finding = SimpleEnglish::Finding.new(line: 1, column: 3, rule: "SE_NO_CONTRACTIONS", message: "x")
    assert_empty SimpleEnglish::Suppressions.filter(source, [finding])
  end

  def test_directive_with_rules_suppresses_only_those_rules
    source = "# se: ignore=SE_NO_CONTRACTIONS\n"
    keep = SimpleEnglish::Finding.new(line: 1, column: 3, rule: "SE_NO_EMDASH", message: "x")
    drop = SimpleEnglish::Finding.new(line: 1, column: 3, rule: "SE_NO_CONTRACTIONS", message: "x")
    assert_equal [keep], SimpleEnglish::Suppressions.filter(source, [keep, drop])
  end

  def test_suppression_applies_to_the_cited_line
    source = "Fine text here. # se: ignore\nAnd more text that is fine.\n"
    # A Markdown paragraph starting on line 1 cites line 1.
    finding = SimpleEnglish::Finding.new(line: 1, column: nil, rule: "SE_PARAGRAPH_TOO_LONG", message: "x")
    assert_empty SimpleEnglish::Suppressions.filter(source, [finding])
  end

  def test_directive_on_another_line_does_not_suppress
    source = "# se: ignore\n# The worker didn't write the file.\n"
    finding = SimpleEnglish::Finding.new(line: 2, column: 14, rule: "SE_NO_CONTRACTIONS", message: "x")
    assert_equal [finding], SimpleEnglish::Suppressions.filter(source, [finding])
  end

  def test_no_directives_changes_nothing
    finding = SimpleEnglish::Finding.new(line: 1, column: 3, rule: "SE_NO_CONTRACTIONS", message: "x")
    assert_equal [finding], SimpleEnglish::Suppressions.filter("# a comment\n", [finding])
  end

  def test_block_comment_finding_is_suppressed_on_its_reported_line
    source = "/* First line\n" \
             "   The worker didn't write the file. se: ignore\n" \
             " */\n"
    finding = SimpleEnglish::Finding.new(line: 2, column: 17, rule: "SE_NO_CONTRACTIONS", message: "x")
    assert_empty SimpleEnglish::Suppressions.filter(source, [finding])
  end
end
