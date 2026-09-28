# frozen_string_literal: true

require_relative "test_helper"
load File.expand_path("../../bin/render-rules", __dir__)

class RenderRulesTest < Minitest::Test
  def test_docs_rules_md_is_current
    assert_equal RenderRules.render,
      File.read(File.expand_path("../../docs/RULES.md", __dir__)),
      "docs/RULES.md is stale. Run bin/render-rules."
  end
end
