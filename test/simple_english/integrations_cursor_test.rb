# frozen_string_literal: true

require_relative "test_helper"

class IntegrationsCursorTest < Minitest::Test
  PLUGIN = File.expand_path("../../integrations/cursor", __dir__)

  def test_manifest_declares_the_plugin
    manifest = JSON.parse(File.read(File.join(PLUGIN, "plugin.json")))
    assert_equal "https://agent-plugins.org/schemas/1.0.0/plugin.schema.json", manifest.fetch("$schema")
    assert_equal "simple-english", manifest.fetch("name")
    assert_equal SimpleEnglish::VERSION, manifest.fetch("version")
    assert manifest.key?("description")
    refute manifest.key?("skills"), "the skills directory is found by convention"
    refute manifest.key?("mcpServers"), "the root mcp.json is found by convention"
  end

  def test_mcp_json_names_the_se_mcp_command
    wiring = JSON.parse(File.read(File.join(PLUGIN, "mcp.json")))
    assert_equal "https://agent-plugins.org/schemas/1.0.0/mcp.schema.json", wiring.fetch("$schema")
    server = wiring.fetch("mcpServers").fetch("simple-english")
    assert_equal "stdio", server.fetch("type")
    assert_equal "se", server.fetch("command")
    assert_equal ["mcp"], server.fetch("args")
  end

  def test_skill_is_vendored_not_a_symlink
    skills = File.join(PLUGIN, "skills")
    refute File.symlink?(skills)
    assert File.exist?(File.join(skills, "simple-english-lint", "SKILL.md"))
  end

  def test_vendored_skill_names_the_mcp_tool
    skill = File.read(File.join(PLUGIN, "skills", "simple-english-lint", "SKILL.md"))
    assert_includes skill, "`lint`"
  end
end
