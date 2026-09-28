# frozen_string_literal: true

require_relative "paragraph"

# Markdown stripping and paragraph splitting. Block structure comes
# from the tree-sitter Markdown grammar shipped with the pack the
# extractor already uses. Inline fixes stay regular expressions.
# Stripping keeps the line count identical to the source.

module SimpleEnglish
  module Markdown
    # A terminator ends a sentence only before whitespace or at the
    # end of the text, so periods inside URLs and file names do not
    # split sentences.
    SENTENCE_END = /(?<=[.!?])(?:\s+|$)/
    # Non-prose blocks: their lines never reach the counting rules or
    # LanguageTool.
    BLANKED_BLOCKS = %w[fenced_code_block indented_code_block thematic_break].freeze
    UNDERLINE = /\Asetext_h\d_underline\z/

    module_function

    # Blank out code and other non-prose blocks and neutralize inline
    # code and heading markers. The line count stays identical to the
    # source.
    def strip(text)
      lines = text.lines.map(&:chomp)
      blank_rows(text).each { |row| lines[row] = "" }
      lines.map { |line| strip_line(line) }.join("\n")
    end

    def strip_line(line)
      line.gsub(/`[^`]*`/, "X").sub(/\A\#{1,6} /, "")
    end

    # A vertical list is not one paragraph: each list item is its own.
    # Paragraph boundaries come from the tree-sitter Markdown grammar,
    # so lazy continuations and interrupted lists match the spec
    # instead of line-shape heuristics.
    def paragraphs(text)
      root = parse(text)
      nodes = []
      each_node(root) { |node| nodes << node if node.kind == "paragraph" }
      nodes.sort_by!(&:start_byte)
      nodes.filter_map do |node|
        body = text.byteslice(node.start_byte, node.end_byte - node.start_byte)
        lines = body.lines.map(&:strip).reject(&:empty?)
        next if lines.empty?
        Paragraph.new(lines: lines, start_line: node.start_position.row + 1,
          procedural: inside_list_item?(node))
      end
    end

    def sentences_of(paragraph_body)
      paragraph_body.split(SENTENCE_END).map(&:strip).reject(&:empty?)
    end

    # The rows (0-based) a node fully occupies. Tree-sitter end
    # positions are exclusive. A node ending at column 0 does not
    # cover that row.
    def node_rows(node)
      last = node.end_position.column.zero? ? node.end_position.row - 1 : node.end_position.row
      (node.start_position.row..last)
    end

    def blank_rows(text)
      rows = []
      each_node(parse(text)) do |node|
        next if node.kind == "paragraph" # prose, not a block to blank
        rows.concat(node_rows(node).to_a) if
          BLANKED_BLOCKS.include?(node.kind) || UNDERLINE.match?(node.kind)
      end
      rows
    end

    def each_node(root)
      stack = [root]
      until stack.empty?
        node = stack.pop
        yield node
        # No paragraphs live inside code blocks. Skip their subtrees.
        next if BLANKED_BLOCKS.include?(node.kind)
        node.child_count.times { |i| stack.push(node.child(i)) }
      end
    end

    def inside_list_item?(node)
      return false unless node.parent
      node.parent.kind == "list_item" || inside_list_item?(node.parent)
    end

    def parse(text)
      require "tree_sitter_language_pack"
      TreeSitterLanguagePack.get_parser("markdown").parse(text).root_node
    end

    private_class_method :strip_line, :node_rows, :blank_rows, :each_node,
      :inside_list_item?, :parse
  end
end
