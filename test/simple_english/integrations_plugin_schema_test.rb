# frozen_string_literal: true

require_relative "test_helper"

# The schemas are vendored from the Agent Plugins 1.0.0 standard,
# https://agent-plugins.org/specification. Refresh them from
# https://agent-plugins.org/schemas/1.0.0/ when the standard bumps.
# The spec's semantic rules that no schema encodes (path containment,
# mcp.json version matching the manifest) get their own assertions.
# One test covers both adapters built on the portable format.
class IntegrationsPluginSchemaTest < Minitest::Test
  FIXTURES = File.expand_path("../fixtures/agent_plugins", __dir__)
  PLUGINS = %w[codex cursor].freeze

  def test_each_plugin_json_matches_the_vendored_schema
    PLUGINS.each do |plugin|
      assert_empty load_schema("plugin.schema.json")
        .validate(load_plugin_doc(plugin, "plugin.json")).to_a,
        "#{plugin}: plugin.json drifted from the schema"
    end
  end

  def test_each_mcp_json_matches_the_vendored_schema
    PLUGINS.each do |plugin|
      assert_empty load_schema("mcp.schema.json")
        .validate(load_plugin_doc(plugin, "mcp.json")).to_a,
        "#{plugin}: mcp.json drifted from the schema"
    end
  end

  # The mcp.json schema version must match the manifest's declared
  # standard version, per the spec's version-locking rule.
  def test_each_mcp_schema_version_matches_the_manifest
    PLUGINS.each do |plugin|
      manifest = load_plugin_doc(plugin, "plugin.json")
      mcp = load_plugin_doc(plugin, "mcp.json")
      expected = manifest.fetch("$schema").sub("plugin.schema.json", "mcp.schema.json")
      assert_equal expected, mcp.fetch("$schema"), "#{plugin}: schema versions diverge"
    end
  end

  # The manifest carries no skills or mcpServers pointers: the
  # standard discovers skills/ and mcp.json by convention.
  def test_each_manifest_leaves_component_discovery_to_the_standard
    PLUGINS.each do |plugin|
      manifest = load_plugin_doc(plugin, "plugin.json")
      refute manifest.key?("skills"), "#{plugin}: skills pointer is not portable"
      refute manifest.key?("mcpServers"), "#{plugin}: mcpServers pointer is not portable"
    end
  end

  private

  def load_schema(name)
    require "json_schemer"
    JSONSchemer.schema(File.read(File.join(FIXTURES, name)))
  end

  def load_plugin_doc(plugin, name)
    dir = File.expand_path("../../integrations/#{plugin}", __dir__)
    JSON.parse(File.read(File.join(dir, name)))
  end
end
