# frozen_string_literal: true

require_relative "test_helper"

require "json"

class ClientOffsetToLineTest < Minitest::Test
  def test_offset_zero_is_line_one
    assert_equal 1, SimpleEnglish::Client.offset_to_line("any text", 0)
  end

  def test_offset_after_one_newline_is_line_two
    assert_equal 2, SimpleEnglish::Client.offset_to_line("first\nsecond", 6)
  end

  def test_offset_on_newline_is_next_line
    assert_equal 2, SimpleEnglish::Client.offset_to_line("first\nsecond", 5)
  end

  def test_offset_at_end_of_text
    assert_equal 2, SimpleEnglish::Client.offset_to_line("one\ntwo", 7)
  end

  def test_offset_to_line_counts_emoji_as_two_units
    text = "header \u{1F600} ok\nsecond line here"
    # UTF-16: "header " = 7 units, emoji = 2 units, " ok" = 3 units, newline at unit 12
    assert_equal 1, SimpleEnglish::Client.offset_to_line(text, 11)
    assert_equal 2, SimpleEnglish::Client.offset_to_line(text, 13)
  end
end
