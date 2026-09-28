# frozen_string_literal: true

require_relative "test_helper"

require "fileutils"
require "tmpdir"

class ServerStagingTest < Minitest::Test
  def test_stage_rules_copies_to_classpath_layout
    Dir.mktmpdir do |dir|
      staged = SimpleEnglish::Server.stage_rules(dir)
      assert_equal File.join(dir, "org/languagetool/rules/en/grammar_custom.xml"), staged
      assert File.read(staged).start_with?("<?xml")
    end
  end
end
