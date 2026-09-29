# frozen_string_literal: true

require_relative "test_helper"

class StripMarkdownTest < Minitest::Test
  def setup
    @source = <<~MARKDOWN
      # Title
      Use `don't` here.
      ```ruby
      puts 'utilize'
      ```
      Done.
    MARKDOWN
    @stripped = SimpleEnglish::Markdown.strip(@source)
  end

  def test_keeps_line_count_and_utf16_line_widths_identical
    assert_equal @source.lines.count, @stripped.lines.count
    widths = lambda do |text|
      text.lines.map { |line| line.each_char.sum { |char| (char.ord > 0xFFFF) ? 2 : 1 } }
    end
    assert_equal widths.call(@source), widths.call(@stripped)
  end

  def test_neutralizes_inline_code
    refute_includes @stripped, "don't"
  end

  def test_preserves_line_endings
    source = "Use `code`.\r\nKeep this.\nLast line."
    assert_equal ["\r\n", "\n"], SimpleEnglish::Markdown.strip(source).scan(/\r?\n/)
  end

  def test_preserves_width_after_astral_inline_code
    source = "Use `\u{1F4A1}` but don't stop.\n"
    stripped = SimpleEnglish::Markdown.strip(source)
    source_offset = source.each_char.take_while { |char| char != "d" }.sum do |char|
      (char.ord > 0xFFFF) ? 2 : 1
    end
    assert_equal [1, source_offset + 1],
      SimpleEnglish::Client.offset_to_position(stripped, stripped.index("don't"))
  end

  def test_inline_code_remains_one_word_when_followed_by_punctuation
    stripped = SimpleEnglish::Markdown.strip("Use `first`, `second`, and `third`.\n")
    assert_equal 5, stripped.split.size
  end

  def test_blanks_fenced_code_blocks
    refute_includes @stripped, "utilize"
  end

  def test_keeps_prose
    assert_includes @stripped, "Title"
    assert_includes @stripped, "Done."
  end

  def test_drops_heading_markers
    refute_includes @stripped.lines.first, "#"
  end

  def test_stripping_preserves_columns
    source = "Use `don't` here.\n"
    stripped = SimpleEnglish::Markdown.strip(source)
    assert_equal 12, stripped.index("here")
    assert_equal source.index("here"), stripped.index("here")
  end

  def test_blanks_tilde_fences
    source = "~~~\nUse utilize here.\n~~~\nDone.\n"
    stripped = SimpleEnglish::Markdown.strip(source)
    assert_equal source.lines.count, stripped.lines.count
    refute_includes stripped, "utilize"
    assert_includes stripped, "Done."
  end

  def test_blanks_indented_code_blocks
    source = "Intro.\n\n    indented_code = 'utilize'\n\nOutro.\n"
    stripped = SimpleEnglish::Markdown.strip(source)
    assert_equal source.lines.count, stripped.lines.count
    refute_includes stripped, "indented_code"
    assert_includes stripped, "Intro."
  end
end

class SentencesOfMarkdownTest < Minitest::Test
  def test_periods_inside_urls_do_not_split_sentences
    badges = "[![CI](https://example.com/a.svg)](https://example.com) " \
             "[![Gem](https://example.com/b.svg)](https://example.com)\n"
    assert_equal 1, SimpleEnglish::Markdown.sentences_of(badges).size
  end

  def test_periods_after_whitespace_still_split_sentences
    assert_equal 3, SimpleEnglish::Markdown.sentences_of("One. Two words. Three.\n").size
  end
end
