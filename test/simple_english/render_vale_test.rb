# frozen_string_literal: true

require_relative "test_helper"
load File.expand_path("../../bin/render-vale", __dir__)

class RenderValeTest < Minitest::Test
  def test_vale_styles_are_current
    expected = RenderVale.render
    actual = Dir.children(RenderVale::STYLES_DIR).sort.to_h do |name|
      [name, File.read(File.join(RenderVale::STYLES_DIR, name))]
    end
    assert_equal expected, actual,
      "vale/styles is stale. Run bin/render-vale."
  end

  def test_every_override_is_used
    used = RenderVale.checks.keys
    Dir.children(RenderVale::OVERRIDES_DIR).each do |name|
      assert_includes used, name,
        "vale/overrides/#{name} matches no rule in the XML. Remove it."
    end
  end
end
