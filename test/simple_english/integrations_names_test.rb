# frozen_string_literal: true

require_relative "test_helper"

# The name audit from the spec's Names section. It covers the three
# distinctive exposed names, listed in NAMES. The shared plugin name
# "simple-english" is not distinctive, and the marketplace now shares
# it, so the audit leaves both out.
# Each audited name may appear only in its recorded places. A rename
# updates those places and this list together. New places need a spec
# change first.
class IntegrationsNamesTest < Minitest::Test
  SELF = "test/simple_english/integrations_names_test.rb"

  # pi writes its package state into .pi/, and those files name
  # the audited packages by definition. Like node_modules, it is
  # generated state, not source.
  EXCLUDED_DIRS = [".git", ".pi", ".superpowers", "node_modules", "tmp", ".changes", "docs/superpowers"].freeze
  # Generated history. `changie batch` folds fragment bodies (which name
  # tools) into it, and released history cannot be rewritten on a rename.
  EXCLUDED_FILES = ["CHANGELOG.md"].freeze

  NAMES = {
    # The npm package name for pi.
    "pi-simple-english" => [
      "README.md",
      "docs/DEVELOPMENT.md",
      "docs/RELEASING.md",
      "integrations/pi/package.json",
      "integrations/pi/README.md",
      "integrations/verification.md",
      "test/simple_english/integrations_pi_test.rb",
      ".github/workflows/release.yml"
    ],
    # The pi tool name.
    "se_lint" => [
      "docs/DEVELOPMENT.md",
      "integrations/pi/extensions/se-lint.ts",
      "integrations/pi/README.md",
      "integrations/shared/skills/lint-simple-english/SKILL.md",
      "integrations/claude-code/skills/lint-simple-english/SKILL.md",
      "integrations/codex/skills/lint-simple-english/SKILL.md",
      "integrations/pi/skills/lint-simple-english/SKILL.md",
      "integrations/cursor/skills/lint-simple-english/SKILL.md",
      "integrations/opencode/skills/lint-simple-english/SKILL.md",
      "integrations/vscode-copilot/skills/lint-simple-english/SKILL.md",
      "test/simple_english/integrations_pi_test.rb"
    ],
    # The MCP subcommand wiring.
    "se mcp" => [
      "README.md",
      "docs/DEVELOPMENT.md",
      "integrations/claude-code/README.md",
      "integrations/codex/README.md",
      "integrations/cursor/README.md",
      "integrations/opencode/README.md",
      "integrations/vscode-copilot/README.md",
      "integrations/verification.md"
    ],
    # The lint skill, named verb-first like the writing skill.
    "lint-simple-english" => [
      "bin/e2e-agents",
      "docs/DEVELOPMENT.md",
      "integrations/shared/skills/lint-simple-english/SKILL.md",
      "integrations/shared/skills/write-simple-english/SKILL.md",
      "integrations/claude-code/skills/lint-simple-english/SKILL.md",
      "integrations/claude-code/skills/write-simple-english/SKILL.md",
      "integrations/codex/skills/lint-simple-english/SKILL.md",
      "integrations/codex/skills/write-simple-english/SKILL.md",
      "integrations/cursor/skills/lint-simple-english/SKILL.md",
      "integrations/cursor/skills/write-simple-english/SKILL.md",
      "integrations/opencode/skills/lint-simple-english/SKILL.md",
      "integrations/opencode/skills/write-simple-english/SKILL.md",
      "integrations/vscode-copilot/skills/lint-simple-english/SKILL.md",
      "integrations/vscode-copilot/skills/write-simple-english/SKILL.md",
      "integrations/pi/skills/lint-simple-english/SKILL.md",
      "integrations/pi/skills/write-simple-english/SKILL.md",
      "integrations/claude-code/README.md",
      "integrations/codex/README.md",
      "integrations/cursor/README.md",
      "integrations/opencode/README.md",
      "integrations/vscode-copilot/README.md",
      "bin/vscode-copilot-check",
      "integrations/pi/README.md",
      "integrations/verification.md",
      "test/simple_english/integrations_claude_manifest_test.rb",
      "test/simple_english/integrations_codex_test.rb",
      "test/simple_english/integrations_cursor_test.rb",
      "test/simple_english/integrations_pi_test.rb"
    ],
    # The writing-guidance skill shipped next to the lint skill.
    "write-simple-english" => [
      ".simple-english.yml",
      "integrations/shared/skills/write-simple-english/SKILL.md",
      "integrations/claude-code/skills/write-simple-english/SKILL.md",
      "integrations/codex/skills/write-simple-english/SKILL.md",
      "integrations/cursor/skills/write-simple-english/SKILL.md",
      "integrations/opencode/skills/write-simple-english/SKILL.md",
      "integrations/pi/skills/write-simple-english/SKILL.md",
      "integrations/vscode-copilot/skills/write-simple-english/SKILL.md",
      "bin/vscode-copilot-check",
      "integrations/claude-code/README.md",
      "integrations/codex/README.md",
      "integrations/cursor/README.md",
      "integrations/opencode/README.md",
      "integrations/vscode-copilot/README.md",
      "integrations/pi/README.md"
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
