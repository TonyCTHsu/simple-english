# frozen_string_literal: true

require_relative "test_helper"

require "json"

class ClientOffsetToPositionTest < Minitest::Test
  def test_offset_zero_is_first_column_of_line_one
    assert_equal [1, 1], SimpleEnglish::Client.offset_to_position("any text", 0)
  end

  def test_offset_after_one_newline_is_first_column_of_line_two
    assert_equal [2, 1], SimpleEnglish::Client.offset_to_position("first\nsecond", 6)
  end

  def test_offset_on_newline_is_end_of_line_one
    assert_equal [1, 6], SimpleEnglish::Client.offset_to_position("first\nsecond", 5)
  end

  def test_offset_at_end_of_text
    assert_equal [2, 4], SimpleEnglish::Client.offset_to_position("one\ntwo", 7)
  end

  def test_columns_count_emoji_as_two_units
    text = "header \u{1F600} ok\nsecond line here"
    # UTF-16: "header " = 7 units, emoji = 2 units, " ok" = 3 units, newline at unit 12
    assert_equal [1, 12], SimpleEnglish::Client.offset_to_position(text, 11)
    assert_equal [2, 1], SimpleEnglish::Client.offset_to_position(text, 13)
  end
end
