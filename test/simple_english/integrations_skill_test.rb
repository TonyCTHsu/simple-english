# frozen_string_literal: true

require "yaml"

require_relative "test_helper"

# Every skill is vendored into every adapter dir so an install that
# copies a plugin alone still carries it (a symlink dangles in that
# case). This test keeps the copies from drifting apart: edit the
# shared one, then copy it into the six adapters. A new skill under
# integrations/shared/skills/ joins this test automatically.
class IntegrationsSkillTest < Minitest::Test
  SHARED_SKILLS = File.expand_path("../../integrations/shared/skills", __dir__)
  ADAPTERS = %w[claude-code codex cursor opencode pi vscode-copilot].freeze

  def shared_skill_paths
    Dir.glob("*/SKILL.md", base: SHARED_SKILLS).sort.map { |rel| File.join(SHARED_SKILLS, rel) }
  end

  def vendored_path(adapter, shared_path)
    rel = shared_path.delete_prefix("#{SHARED_SKILLS}/")
    File.expand_path("../../integrations/#{adapter}/skills/#{rel}", __dir__)
  end

  def test_every_shared_skill_is_vendored_into_every_adapter
    refute_empty shared_skill_paths
    shared_skill_paths.each do |shared|
      ADAPTERS.each do |adapter|
        copy = vendored_path(adapter, shared)
        assert File.file?(copy),
          "#{shared} is not vendored into #{adapter}. Copy the shared skill over."
        assert_equal File.read(shared), File.read(copy),
          "#{copy} drifted from the shared skill. Copy the shared one over it."
      end
    end
  end

  def test_no_adapter_links_its_skills_to_the_outside
    shared_skill_paths.each do |shared|
      ADAPTERS.each do |adapter|
        refute File.symlink?(File.dirname(vendored_path(adapter, shared)))
      end
    end
  end

  # YAML rejects a plain scalar that contains a colon and a space, so
  # prose in a description can break the front matter in ways the
  # byte-identical check above cannot see. Parse it here, at the one
  # gate every skill file already passes through.
  def test_shared_skill_front_matter_parses
    shared_skill_paths.each do |shared|
      front_matter = File.read(shared)[/\A---\n(.*?)\n---/m, 1]
      refute_nil front_matter, "#{shared} has no front matter."
      parsed = YAML.safe_load(front_matter)
      assert_instance_of String, parsed.fetch("description"), shared
    end
  end
end
