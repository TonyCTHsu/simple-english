# frozen_string_literal: true

require_relative "test_helper"

class IntegrationsCursorTest < Minitest::Test
  PLUGIN = File.expand_path("../../integrations/cursor", __dir__)

  def test_mcp_json_names_the_se_mcp_command
    wiring = JSON.parse(File.read(File.join(PLUGIN, ".cursor", "mcp.json")))
    server = wiring.fetch("mcpServers").fetch("simple-english")
    assert_equal "se", server.fetch("command")
    assert_equal ["mcp"], server.fetch("args")
  end

  def test_skill_is_vendored_not_a_symlink
    skills = File.join(PLUGIN, ".cursor", "skills")
    refute File.symlink?(skills)
    assert File.exist?(File.join(skills, "simple-english-lint", "SKILL.md"))
  end

  def test_vendored_skill_names_the_mcp_tool
    skill = File.read(File.join(PLUGIN, ".cursor", "skills", "simple-english-lint", "SKILL.md"))
    assert_includes skill, "`lint`"
  end
end
