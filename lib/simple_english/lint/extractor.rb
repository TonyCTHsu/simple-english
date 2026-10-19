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
      ".h" => "cpp",
      ".c" => "c",
      ".m" => "objc",
      ".php" => "php",
      ".swift" => "swift",
      ".scala" => "scala",
      ".ex" => "elixir",
      ".exs" => "elixir",
      ".lua" => "lua",
      ".dart" => "dart",
      ".pl" => "perl",
      ".pm" => "perl",
      ".r" => "r",
      ".sql" => "sql",
      ".hs" => "haskell",
      ".zig" => "zig",
      ".toml" => "toml",
      ".ini" => "ini",
      ".mk" => "makefile",
      ".html" => "html",
      ".htm" => "html",
      ".xml" => "xml"
    }.freeze

    # Dockerfile and Makefile carry no extension, and the variants
    # keep the language: Dockerfile.dev, Makefile.dev.
    NAME_LANGUAGES = {
      "Dockerfile" => "dockerfile",
      "Makefile" => "makefile",
      "makefile" => "makefile",
      "GNUmakefile" => "makefile"
    }.freeze

    PROSE_EXTENSIONS = [".md"].freeze

    module_function

    # nil for files we do not lint.
    def language_for(path)
      name = File.basename(path)
      return NAME_LANGUAGES[name] if NAME_LANGUAGES[name]
      return "dockerfile" if name.start_with?("Dockerfile.")
      return "makefile" if name.start_with?("Makefile.")
      EXTENSION_LANGUAGES[File.extname(path)]
    end

    # true when the path is a file this linter owns: Markdown, stdin,
    # or a supported code language. Everything else is skipped, so a
    # single explicit path behaves like directory expansion (cli.rb).
    def lintable?(path)
      path == "-" || PROSE_EXTENSIONS.include?(File.extname(path)) ||
        !language_for(path).nil?
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

    # The xml grammar names the node "Comment", so the kind check
    # reads case-insensitive.
    def comment?(node)
      kind = node.kind.downcase
      kind.end_with?("comment") && !kind.start_with?("non")
    end

    private_class_method :comment?
  end
end
