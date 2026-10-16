# frozen_string_literal: true

require_relative "test_helper"
require "yaml"

# The house style for changie fragment bodies, so the changelog
# folds in consistent. Released entries from 0.5.0 on open with an
# imperative verb and say one thing. Install steps live in the
# READMEs, not here. A genuinely new verb needs a deliberate edit
# to VERBS, like the names audit's recorded places.
class ChangelogFragmentsTest < Minitest::Test
  VERBS = %w[
    Add Allow Bundle Change Deprecate Drop Fix Handle Lint Migrate Move
    Record Reject Remove Rename Say Skip Support Turn Warn
  ].freeze

  def unreleased
    Dir[".changes/unreleased/*.yaml"].sort
  end

  def test_each_fragment_body_opens_with_an_imperative_verb
    unreleased.each do |path|
      body = YAML.safe_load_file(path, permitted_classes: [Time])["body"]
      assert_instance_of String, body, "#{path} needs a body"
      first = body.split.first.to_s
      assert VERBS.include?(first),
        "#{path} opens with \"#{first}\". Start with an imperative verb " \
        "(#{VERBS.join(", ")}); reword the body or extend VERBS."
    end
  end

  def test_each_fragment_body_is_one_sentence
    unreleased.each do |path|
      body = YAML.safe_load_file(path, permitted_classes: [Time])["body"]
      next unless body.is_a?(String)
      sentences = SimpleEnglish::Markdown.sentences_of(body)
      assert_equal 1, sentences.size,
        "#{path} carries #{sentences.size} sentences. The body is one sentence."
    end
  end
end
