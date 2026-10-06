# frozen_string_literal: true

require_relative "test_helper"
require "open3"

class IntegrationsHookTest < Minitest::Test
  SCRIPT = File.expand_path("../../integrations/claude-code/hooks/lint.sh", __dir__)
  FIXTURE = File.expand_path("../fixtures/claude_code/post_tool_use.json", __dir__)

  def hook(payload, env = {})
    out, _err, status = Open3.capture3(env, SCRIPT, stdin_data: JSON.generate(payload))
    [out, status.exitstatus]
  end

  def payload_for(path)
    payload = JSON.parse(File.read(FIXTURE))
    payload["tool_input"]["file_path"] = path
    payload
  end

  # The canned output goes to a file and the stub cats it, so bodies with
  # quotes or apostrophes never touch shell quoting.
  def stub_se(exit_code, body, &block)
    dir = Dir.mktmpdir("stub_se")
    stub = File.join(dir, "se")
    canned = File.join(dir, "output.txt")
    File.write(canned, body)
    File.write(stub, "#!/bin/sh\ncat '#{canned}'\nexit #{exit_code}\n")
    FileUtils.chmod(0o755, stub)
    block.call(stub)
  ensure
    FileUtils.remove_entry(dir) if dir
  end

  def md_file(name = "doc.md")
    dir = Dir.mktmpdir("hook_files")
    path = File.join(dir, name)
    FileUtils.touch(path)
    path
  end

  def test_findings_feed_back_as_additional_context
    stub_se(1, "doc.md:1:12-26: [SE_ACTIVE_VOICE] Use the active voice.") do |stub|
      out, code = hook(payload_for(md_file), {"SE_BIN" => stub})
      assert_equal 0, code
      feedback = JSON.parse(out)
      context = feedback.dig("hookSpecificOutput", "additionalContext")
      assert_equal "PostToolUse", feedback.dig("hookSpecificOutput", "hookEventName")
      assert_includes context, "doc.md:1:12-26: [SE_ACTIVE_VOICE] Use the active voice."
      assert_includes context, "1 lint finding"
    end
  end

  def test_findings_with_apostrophes_survive_the_stub
    stub_se(1, "doc.md:2 [SE_SHORT] Don't use filler.") do |stub|
      out, code = hook(payload_for(md_file), {"SE_BIN" => stub})
      assert_equal 0, code
      assert_includes JSON.parse(out).dig("hookSpecificOutput", "additionalContext"), "Don't use filler."
    end
  end

  def test_clean_output_prints_nothing
    stub_se(0, "") do |stub|
      out, code = hook(payload_for(md_file), {"SE_BIN" => stub})
      assert_equal 0, code
      assert_equal "", out
    end
  end

  def test_se_failure_tells_the_agent
    stub_se(2, "") do |stub|
      out, code = hook(payload_for(md_file), {"SE_BIN" => stub})
      assert_equal 0, code
      context = JSON.parse(out).dig("hookSpecificOutput", "additionalContext")
      assert_includes context, "was not linted"
      assert_includes context, "exited 2"
    end
  end

  def test_findings_exit_code_with_empty_output_stays_quiet
    stub_se(1, "") do |stub|
      out, code = hook(payload_for(md_file), {"SE_BIN" => stub})
      assert_equal 0, code
      assert_equal "", out
    end
  end

  def test_non_markdown_file_is_ignored
    stub_se(1, '[{"path":"x.py","line":1,"column":1,"rule":"R","message":"m"}]') do |stub|
      out, code = hook(payload_for(md_file("note.py")), {"SE_BIN" => stub})
      assert_equal 0, code
      assert_equal "", out
    end
  end

  def test_path_with_spaces_lints
    stub_se(1, "my file.md:1 [R] m") do |stub|
      out, code = hook(payload_for(md_file("my file.md")), {"SE_BIN" => stub})
      assert_equal 0, code
      assert_includes JSON.parse(out).dig("hookSpecificOutput", "additionalContext"), "my file.md:1"
    end
  end

  def test_payload_without_file_path_is_ignored
    payload = JSON.parse(File.read(FIXTURE))
    payload["tool_input"] = {}
    out, code = hook(payload)
    assert_equal 0, code
    assert_equal "", out
  end

  def test_missing_se_binary_names_the_remedy
    out, code = hook(payload_for(md_file), {"SE_BIN" => "/no/such/se"})
    assert_equal 0, code
    context = JSON.parse(out).dig("hookSpecificOutput", "additionalContext")
    assert_includes context, "not linted"
    assert_includes context, "gem install simple_english"
  end
end
