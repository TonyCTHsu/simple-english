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

  def test_keeps_line_count_identical
    assert_equal @source.lines.count, @stripped.lines.count
  end

  def test_neutralizes_inline_code
    refute_includes @stripped, "don't"
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
