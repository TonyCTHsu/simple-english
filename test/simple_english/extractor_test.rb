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

  def test_xml_comment_node_is_capitalized
    source = "<!-- You don't need this file. --><a>1</a>"
    texts = SimpleEnglish::Extractor.comment_spans(source, "xml").map(&:text)
    assert_equal ["<!-- You don't need this file. -->"], texts
  end

  def test_php_line_and_hash_comments
    source = "<?php\n// You don't need this file.\n# You don't need the cache.\n$x = 1;\n"
    texts = SimpleEnglish::Extractor.comment_spans(source, "php").map(&:text)
    assert_equal ["// You don't need this file.", "# You don't need the cache."], texts
  end

  def test_hash_comment_languages
    {"toml" => "key = 1", "r" => "x <- 1",
     "perl" => "my $x = 1;", "elixir" => "x = 1"}.each do |lang, code|
      source = "# You don't need this file.\n#{code}"
      texts = SimpleEnglish::Extractor.comment_spans(source, lang).map(&:text)
      assert_equal ["# You don't need this file."], texts, lang
    end
  end

  def test_ini_comment_spans_the_newline
    source = "[a]\n# You don't need this file.\nb = 1"
    texts = SimpleEnglish::Extractor.comment_spans(source, "ini").map(&:text)
    assert_equal ["# You don't need this file.\n"], texts
  end

  def test_dockerfile_and_makefile_comments
    dockerfile = "# You don't need this layer.\nFROM alpine"
    makefile = "# You don't need this target.\nall:\n\techo hi"
    assert_equal ["# You don't need this layer."],
      SimpleEnglish::Extractor.comment_spans(dockerfile, "dockerfile").map(&:text)
    assert_equal ["# You don't need this target."],
      SimpleEnglish::Extractor.comment_spans(makefile, "makefile").map(&:text)
  end

  def test_language_for_registry
    assert_equal "python", SimpleEnglish::Extractor.language_for("a/b/c.py")
    assert_equal "yaml", SimpleEnglish::Extractor.language_for("config.yml")
    assert_nil SimpleEnglish::Extractor.language_for("notes.md")
    assert_equal "csharp", SimpleEnglish::Extractor.language_for("src/Cs.cs")
    assert_equal "cpp", SimpleEnglish::Extractor.language_for("src/thing.cpp")
    assert_equal "cpp", SimpleEnglish::Extractor.language_for("include/header.h")
    assert_equal "c", SimpleEnglish::Extractor.language_for("src/thing.c")
    assert_equal "objc", SimpleEnglish::Extractor.language_for("src/thing.m")
    assert_equal "php", SimpleEnglish::Extractor.language_for("web/index.php")
    assert_equal "swift", SimpleEnglish::Extractor.language_for("app/view.swift")
    assert_equal "scala", SimpleEnglish::Extractor.language_for("app/job.scala")
    assert_equal "elixir", SimpleEnglish::Extractor.language_for("app/conn.ex")
    assert_equal "lua", SimpleEnglish::Extractor.language_for("script/run.lua")
    assert_equal "dart", SimpleEnglish::Extractor.language_for("app/page.dart")
    assert_equal "perl", SimpleEnglish::Extractor.language_for("bin/tool.pl")
    assert_equal "r", SimpleEnglish::Extractor.language_for("stats/plot.r")
    assert_equal "sql", SimpleEnglish::Extractor.language_for("db/query.sql")
    assert_equal "haskell", SimpleEnglish::Extractor.language_for("src/lib.hs")
    assert_equal "zig", SimpleEnglish::Extractor.language_for("src/main.zig")
    assert_equal "toml", SimpleEnglish::Extractor.language_for("config/app.toml")
    assert_equal "ini", SimpleEnglish::Extractor.language_for("config/app.ini")
    assert_equal "makefile", SimpleEnglish::Extractor.language_for("rules.mk")
    assert_equal "html", SimpleEnglish::Extractor.language_for("web/index.html")
    assert_equal "html", SimpleEnglish::Extractor.language_for("web/index.htm")
    assert_equal "xml", SimpleEnglish::Extractor.language_for("web/index.xml")
    assert_nil SimpleEnglish::Extractor.language_for("img/icon.svg")
  end

  def test_language_for_extensionless_names
    assert_equal "dockerfile", SimpleEnglish::Extractor.language_for("deploy/Dockerfile")
    assert_equal "dockerfile", SimpleEnglish::Extractor.language_for("deploy/Dockerfile.dev")
    assert_equal "makefile", SimpleEnglish::Extractor.language_for("Makefile")
    assert_equal "makefile", SimpleEnglish::Extractor.language_for("makefile")
    assert_equal "makefile", SimpleEnglish::Extractor.language_for("GNUmakefile")
    assert_equal "makefile", SimpleEnglish::Extractor.language_for("Makefile.dev")
    assert_nil SimpleEnglish::Extractor.language_for("README")
  end
end
