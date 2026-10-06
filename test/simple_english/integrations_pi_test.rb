# frozen_string_literal: true

require_relative "test_helper"

class IntegrationsPiTest < Minitest::Test
  ROOT = File.expand_path("../../integrations/pi", __dir__)

  def test_package_json_declares_the_pi_block
    package = JSON.parse(File.read(File.join(ROOT, "package.json")))
    assert_equal "pi-simple-english", package.fetch("name")
    assert_equal SimpleEnglish::VERSION, package.fetch("version")
    pi = package.fetch("pi")
    assert_equal ["./extensions/se-lint.ts"], pi.fetch("extensions")
    assert_equal ["./skills"], pi.fetch("skills")
  end

  def test_peer_dependencies_stay_host_supplied
    package = JSON.parse(File.read(File.join(ROOT, "package.json")))
    peers = package.fetch("peerDependencies")
    assert_equal "*", peers.fetch("@earendil-works/pi-coding-agent")
    assert_equal "*", peers.fetch("typebox")
  end

  def test_declared_paths_exist
    package = JSON.parse(File.read(File.join(ROOT, "package.json")))
    package.fetch("pi").fetch("extensions").each do |path|
      assert File.exist?(File.join(ROOT, path)), "missing #{path}"
    end
    package.fetch("pi").fetch("skills").each do |path|
      assert File.directory?(File.join(ROOT, path)), "missing #{path}"
    end
  end

  def test_extension_registers_the_se_lint_tool
    source = File.read(File.join(ROOT, "extensions", "se-lint.ts"))
    assert_includes source, "se_lint"
  end

  def test_vendored_skill_names_the_pi_tool
    skill = File.read(File.join(ROOT, "skills", "simple-english-lint", "SKILL.md"))
    assert_includes skill, "se_lint"
  end
end
