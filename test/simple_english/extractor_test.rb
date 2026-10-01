# frozen_string_literal: true

require "minitest/autorun"
require_relative "../../lib/simple_english/lint/extractor"

# Golden spans for the extractor. The fixtures carry the two failure
# modes of naive regex extraction: a comment marker inside a string,
# and a comment after broken syntax.
class ExtractorTest < Minitest::Test
  def self.available?
    require "tree_sitter_language_pack"
    true
  rescue LoadError
    false
  end

  def setup
    skip "tree_sitter_language_pack not installed" unless self.class.available?
  end

  def test_python_comment_marker_in_string_is_not_a_comment
    source = <<~SRC
      # Loads the config from the path
      config = load(path)
      url = "http://x#anchor"
    SRC
    texts = SimpleEnglish::Extractor.comment_spans(source, "python").map(&:text)
    assert_equal ["# Loads the config from the path"], texts
  end

  def test_python_comment_survives_broken_syntax
    source = "def broken(:\n  # still extracted\nend\n"
    texts = SimpleEnglish::Extractor.comment_spans(source, "python").map(&:text)
    assert_equal ["# still extracted"], texts
  end

  def test_javascript_line_and_block_comments
    source = <<~SRC
      // Loads the config from the path
      const cfg = parse(path);
      /* Free the handle after the response is send. */
      free(buf);
    SRC
    texts = SimpleEnglish::Extractor.comment_spans(source, "javascript").map(&:text)
    assert_equal ["// Loads the config from the path",
      "/* Free the handle after the response is send. */"], texts
  end

  def test_yaml_anchor_in_value_is_not_a_comment
    source = <<~SRC
      # Loads the config from the path
      url: http://x#anchor
      key: value  # Free the handle when we are finish
    SRC
    texts = SimpleEnglish::Extractor.comment_spans(source, "yaml").map(&:text)
    assert_equal ["# Loads the config from the path",
      "# Free the handle when we are finish"], texts
  end

  def test_span_offsets_slice_the_source
    source = "code = 1  # Free the handle\n"
    span = SimpleEnglish::Extractor.comment_spans(source, "python").first
    assert_equal "# Free the handle", source.byteslice(span.start_byte...span.end_byte)
    assert_equal "# Free the handle", span.text
  end

  def test_csharp_line_comments
    source = "int x = 1;  // Ensure that the value stays correct.\n"
    texts = SimpleEnglish::Extractor.comment_spans(source, "csharp").map(&:text)
    assert_equal ["// Ensure that the value stays correct."], texts
  end

  def test_cpp_line_and_block_comments
    source = <<~SRC
      // Ensure that the value stays correct.
      int x = 1;
      /* Free the handle after the response is send. */
      /** Docs live here. */
    SRC
    texts = SimpleEnglish::Extractor.comment_spans(source, "cpp").map(&:text)
    assert_equal ["// Ensure that the value stays correct.",
      "/* Free the handle after the response is send. */",
      "/** Docs live here. */"], texts
  end

  def test_language_for_registry
    assert_equal "python", SimpleEnglish::Extractor.language_for("a/b/c.py")
    assert_equal "yaml", SimpleEnglish::Extractor.language_for("config.yml")
    assert_nil SimpleEnglish::Extractor.language_for("notes.md")
    assert_equal "csharp", SimpleEnglish::Extractor.language_for("src/Cs.cs")
    assert_equal "cpp", SimpleEnglish::Extractor.language_for("src/thing.cpp")
    assert_equal "cpp", SimpleEnglish::Extractor.language_for("include/header.h")
  end
end
