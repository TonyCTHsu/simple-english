# frozen_string_literal: true

require_relative "test_helper"

# The name audit from the spec's Names section. It covers the three
# distinctive exposed names, listed in NAMES. The shared plugin name
# "simple-english" is not distinctive, so the audit leaves it out.
# Each audited name may appear only in its recorded places. A rename
# updates those places and this list together. New places need a spec
# change first.
class IntegrationsNamesTest < Minitest::Test
  SELF = "test/simple_english/integrations_names_test.rb"

  EXCLUDED_DIRS = [".git", ".superpowers", "node_modules", "tmp", ".changes", "docs/superpowers"].freeze
  # Generated history. `changie batch` folds fragment bodies (which name
  # tools) into it, and released history cannot be rewritten on a rename.
  EXCLUDED_FILES = ["CHANGELOG.md"].freeze

  NAMES = {
    # The pi tool name.
    "se_lint" => [
      "README.md",
      "integrations/pi/extensions/se-lint.ts",
      "integrations/shared/skills/lint/SKILL.md",
      "integrations/claude-code/skills/lint/SKILL.md",
      "integrations/codex/skills/lint/SKILL.md",
      "integrations/pi/skills/lint/SKILL.md",
      "test/simple_english/integrations_pi_test.rb"
    ],
    # The development marketplace name.
    "simple-english-dev" => [
      ".claude-plugin/marketplace.json"
    ],
    # The MCP subcommand wiring.
    "se mcp" => [
      "README.md",
      "docs/DEVELOPMENT.md"
    ]
  }.freeze

  def repo_files
    Dir.glob("**/*", File::FNM_DOTMATCH, base: repo_root).select do |rel|
      next false if rel == "." || EXCLUDED_DIRS.any? { |d| rel.start_with?("#{d}/") }
      next false if EXCLUDED_FILES.include?(rel)
      next false if rel == SELF
      path = File.join(repo_root, rel)
      File.file?(path) && !File.symlink?(path)
    end
  end

  def repo_root
    File.expand_path("../..", __dir__)
  end

  def test_each_name_stays_in_its_recorded_places
    NAMES.each do |name, recorded|
      expected = recorded.sort
      actual = repo_files.select { |rel| File.read(File.join(repo_root, rel)).include?(name) }.sort
      assert_equal expected, actual,
        "#{name} appears outside its recorded places. Update the spec Names section first."
    end
  end
end
