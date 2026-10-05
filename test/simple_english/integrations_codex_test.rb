# frozen_string_literal: true

require_relative "test_helper"

class IntegrationsCodexTest < Minitest::Test
  PLUGIN = File.expand_path("../../integrations/codex", __dir__)

  def test_manifest_declares_the_plugin
    manifest = JSON.parse(File.read(File.join(PLUGIN, ".codex-plugin", "plugin.json")))
    assert_equal "simple-english", manifest.fetch("name")
    assert_equal SimpleEnglish::VERSION, manifest.fetch("version")
    assert manifest.key?("description")
    assert_equal "./skills/", manifest.fetch("skills")
    assert_equal "./.mcp.json", manifest.fetch("mcpServers")
  end

  def test_mcp_json_names_the_se_mcp_command
    wiring = JSON.parse(File.read(File.join(PLUGIN, ".mcp.json")))
    server = wiring.fetch("mcpServers").fetch("simple-english")
    assert_equal "stdio", server.fetch("type")
    assert_equal "se", server.fetch("command")
    assert_equal ["mcp"], server.fetch("args")
  end

  def test_skills_are_vendored_not_a_symlink
    skills = File.join(PLUGIN, "skills")
    refute File.symlink?(skills)
    assert File.exist?(File.join(skills, "lint", "SKILL.md"))
  end

  def test_vendored_skill_names_the_mcp_tool
    skill = File.read(File.join(PLUGIN, "skills", "lint", "SKILL.md"))
    assert_includes skill, "`lint`"
  end
end
