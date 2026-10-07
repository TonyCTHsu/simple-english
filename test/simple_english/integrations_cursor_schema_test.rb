# frozen_string_literal: true

require_relative "test_helper"

# The schemas are vendored from the Agent Plugins 1.0.0 standard,
# https://agent-plugins.org/specification. Refresh them from
# https://agent-plugins.org/schemas/1.0.0/ when the standard bumps.
# The spec's semantic rules that no schema encodes (path containment,
# mcp.json version matching the manifest) get their own assertions.
class IntegrationsCursorSchemaTest < Minitest::Test
  FIXTURES = File.expand_path("../fixtures/agent_plugins", __dir__)
  PLUGIN = File.expand_path("../../integrations/cursor", __dir__)

  def test_plugin_json_matches_the_vendored_schema
    assert_empty load_schema("plugin.schema.json")
      .validate(load_plugin_doc("plugin.json")).to_a
  end

  def test_mcp_json_matches_the_vendored_schema
    assert_empty load_schema("mcp.schema.json")
      .validate(load_plugin_doc("mcp.json")).to_a
  end

  # The mcp.json schema version must match the manifest's declared
  # standard version, per the spec's version-locking rule.
  def test_mcp_schema_version_matches_the_manifest
    manifest = load_plugin_doc("plugin.json")
    mcp = load_plugin_doc("mcp.json")
    expected = manifest.fetch("$schema").sub("plugin.schema.json", "mcp.schema.json")
    assert_equal expected, mcp.fetch("$schema")
  end

  private

  def load_schema(name)
    require "json_schemer"
    JSONSchemer.schema(File.read(File.join(FIXTURES, name)))
  end

  def load_plugin_doc(name)
    JSON.parse(File.read(File.join(PLUGIN, name)))
  end
end
