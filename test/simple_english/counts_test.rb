# frozen_string_literal: true

require_relative "test_helper"

class CountingChecksTest < Minitest::Test
  def test_flags_list_item_over_twenty_words
    long_item = "Install the tracer and then start the service again after " \
                "the check finishes and then write the whole thing down somewhere safe.\n"
    findings = SimpleEnglish::Counts.check("- #{long_item}")
    assert_includes findings.map { |f| f[:rule] }, "SE_SENTENCE_TOO_LONG"
  end

  def test_counts_identifiers_as_single_words
    text = "Install `dd-trace-rb` from `https://example.com/gem` today. It works.\n"
    findings = SimpleEnglish::Counts.check(text)
    refute_includes findings.map { |f| f[:rule] }, "SE_SENTENCE_TOO_LONG"
  end

  def test_flags_paragraph_over_six_sentences
    para = "The service starts. It loads the file. It reads the config. " \
           "It opens the port. It starts the worker. It writes the log. It exits.\n"
    findings = SimpleEnglish::Counts.check(para)
    assert_includes findings.map { |f| f[:rule] }, "SE_PARAGRAPH_TOO_LONG"
  end

  def test_treats_each_list_item_as_its_own_paragraph
    items = 8.times.map { |i| "* Entry number #{i + 1}. It fixes one thing.\n" }.join
    findings = SimpleEnglish::Counts.check(items)
    refute_includes findings.map { |f| f[:rule] }, "SE_PARAGRAPH_TOO_LONG"
  end
end
