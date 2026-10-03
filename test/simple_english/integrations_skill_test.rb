# frozen_string_literal: true

require_relative "test_helper"

# The skill is vendored into every adapter dir so an install that copies
# a plugin alone still carries it (a symlink dangles in that case). This
# test keeps the copies from drifting apart: edit the shared one, then
# copy it into the three adapters.
class IntegrationsSkillTest < Minitest::Test
  SHARED = File.expand_path("../../integrations/shared/skills/lint/SKILL.md", __dir__)
  COPIES = [
    File.expand_path("../../integrations/claude-code/skills/lint/SKILL.md", __dir__),
    File.expand_path("../../integrations/codex/skills/lint/SKILL.md", __dir__),
    File.expand_path("../../integrations/pi/skills/lint/SKILL.md", __dir__)
  ].freeze

  def test_every_vendored_copy_matches_the_shared_skill
    canonical = File.read(SHARED)
    COPIES.each do |path|
      assert_equal canonical, File.read(path),
        "#{path} drifted from the shared skill. Copy the shared one over it."
    end
  end

  def test_no_adapter_links_its_skills_to_the_outside
    COPIES.each { |path| refute File.symlink?(File.dirname(path, 2)) }
  end
end
