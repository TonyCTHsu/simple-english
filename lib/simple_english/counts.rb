# frozen_string_literal: true

# Counting rules: sentence and paragraph length. Pure text analysis.

module SimpleEnglish
  module Counts
    PROCEDURAL_WORD_LIMIT = 20
    DESCRIPTIVE_WORD_LIMIT = 25
    PARAGRAPH_SENTENCE_LIMIT = 6

    module_function

    # Takes Markdown-stripped text, returns findings for long
    # sentences and long paragraphs.
    def check(text)
      Markdown.paragraphs(text).flat_map { |paragraph| findings_for(paragraph) }
    end

    def findings_for(paragraph)
      sentences = Markdown.sentences_of(paragraph.lines.join(" "))
      limit = paragraph.procedural ? PROCEDURAL_WORD_LIMIT : DESCRIPTIVE_WORD_LIMIT

      findings = sentences
        .select { |sentence| sentence.split.size > limit }
        .map do |_sentence|
        Finding.new(line: paragraph.start_line, column: nil, rule: "SE_SENTENCE_TOO_LONG",
          message: "Sentence has more than #{limit} words. Split it.")
      end

      if !paragraph.procedural && sentences.size > PARAGRAPH_SENTENCE_LIMIT
        findings << Finding.new(line: paragraph.start_line, column: nil, rule: "SE_PARAGRAPH_TOO_LONG",
          message: "Paragraph has more than #{PARAGRAPH_SENTENCE_LIMIT} " \
                   "sentences. Give one topic six sentences at most.")
      end
      findings
    end

    private_class_method :findings_for
  end
end
