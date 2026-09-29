# frozen_string_literal: true

# Tree-sitter comment extraction. One walk, no per-language code:
# every grammar marks comments with a kind ending in "comment".

require_relative "span"

module SimpleEnglish
  module Extractor
    EXTENSION_LANGUAGES = {
      ".py" => "python",
      ".rb" => "ruby",
      ".js" => "javascript",
      ".mjs" => "javascript",
      ".ts" => "typescript",
      ".yaml" => "yaml",
      ".yml" => "yaml",
      ".go" => "go",
      ".rs" => "rust",
      ".java" => "java",
      ".sh" => "bash",
      ".kt" => "kotlin",
      ".cs" => "csharp",
      ".cpp" => "cpp",
      ".cc" => "cpp",
      ".cxx" => "cpp",
      ".hpp" => "cpp",
      ".h" => "cpp"
    }.freeze

    module_function

    # nil for files we do not lint.
    def language_for(path)
      EXTENSION_LANGUAGES[File.extname(path)]
    end

    def comment_spans(source, language)
      require "tree_sitter_language_pack"
      root = TreeSitterLanguagePack.get_parser(language).parse(source).root_node
      spans = []
      stack = [root]
      until stack.empty?
        node = stack.pop
        if comment?(node)
          spans << Span.new(text: source.byteslice(node.start_byte...node.end_byte),
            start_byte: node.start_byte, end_byte: node.end_byte)
        end
        (node.child_count - 1).downto(0) { |i| stack.push(node.child(i)) }
      end
      spans.sort_by!(&:start_byte)
    end

    def comment?(node)
      node.kind.end_with?("comment") && !node.kind.start_with?("non")
    end

    private_class_method :comment?
  end
end
