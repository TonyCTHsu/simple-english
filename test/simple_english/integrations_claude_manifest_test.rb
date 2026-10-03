# frozen_string_literal: true

require_relative "test_helper"

class IntegrationsClaudeManifestTest < Minitest::Test
  PLUGIN = File.expand_path("../../integrations/claude-code", __dir__)
  MARKETPLACE = File.expand_path("../../.claude-plugin/marketplace.json", __dir__)

  def test_plugin_manifest_declares_the_plugin
    manifest = JSON.parse(File.read(File.join(PLUGIN, ".claude-plugin", "plugin.json")))
    assert_equal "simple-english", manifest.fetch("name")
    assert_equal SimpleEnglish::VERSION, manifest.fetch("version")
    assert manifest.key?("description")
  end

  def test_hooks_json_wires_post_tool_use_to_lint_sh
    wiring = JSON.parse(File.read(File.join(PLUGIN, "hooks", "hooks.json")))
    hook = wiring.dig("hooks", "PostToolUse").first
    assert_equal "Write|Edit", hook.fetch("matcher")
    command = hook.fetch("hooks").first
    assert_equal "command", command.fetch("type")
    assert_includes command.fetch("command"), "${CLAUDE_PLUGIN_ROOT}/hooks/lint.sh"
    assert File.executable?(File.join(PLUGIN, "hooks", "lint.sh"))
  end

  def test_marketplace_lists_the_plugin_from_the_repo_root
    manifest = JSON.parse(File.read(MARKETPLACE))
    plugin = manifest.fetch("plugins").first
    assert_equal "simple-english", plugin.fetch("name")
    source = plugin.fetch("source")
    repo_root = File.expand_path("..", File.dirname(MARKETPLACE))
    assert File.exist?(File.expand_path(source, repo_root))
    assert File.exist?(File.join(PLUGIN, ".claude-plugin", "plugin.json"))
  end

  def test_plugin_skills_are_vendored_not_a_symlink
    skills = File.join(PLUGIN, "skills")
    refute File.symlink?(skills)
    assert File.exist?(File.join(skills, "lint", "SKILL.md"))
  end

  def test_skill_names_the_mcp_tool
    skill = File.read(File.join(PLUGIN, "skills", "lint", "SKILL.md"))
    assert_includes skill, "`lint`"
  end
end
