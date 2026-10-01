# frozen_string_literal: true

require_relative "test_helper"

require "zip"

class LanguageToolHelpersTest < Minitest::Test
  def test_rule_ids_reads_the_custom_rules_file
    ids = SimpleEnglish::LanguageTool.rule_ids
    assert_includes ids, "SE_NO_CONTRACTIONS"
    assert_includes ids, "SE_NO_SEMICOLON"
  end

  def test_rule_ids_finds_id_regardless_of_attribute_order
    in_tmpdir do |dir|
      user = File.join(dir, "team.xml")
      File.write(user, <<~XML)
        <?xml version="1.0" encoding="UTF-8"?>
        <rules lang="en">
          <rule name="No foobar" id="MY_TEAM_RULE">
            <pattern><token>foobar</token></pattern>
          </rule>
          <rule id="MY_OTHER_RULE" name="No buzz"/>
          <rulegroup id="MY_GROUP" name="group">
            <rule name="sub"><pattern><token>sub</token></pattern></rule>
          </rulegroup>
        </rules>
      XML
      ids = SimpleEnglish::LanguageTool.rule_ids(user)
      assert_includes ids, "MY_TEAM_RULE"
      assert_includes ids, "MY_OTHER_RULE"
      assert_includes ids, "MY_GROUP"
      refute_includes ids, "sub" # id-less sub-rule stays out
    end
  end

  def test_lt_version_is_pinned_to_6_6
    assert_equal "6.6", SimpleEnglish::LanguageTool::LT_VERSION
  end

  def test_download_writes_the_response_body_to_the_file
    server = StubHTTPServer.new("/download" => lambda { |_body| [200, "zip bytes"] })
    in_tmpdir do |dir|
      target = File.join(dir, "lt.zip")
      assert SimpleEnglish::LanguageTool.download(
        "#{server.url}/download", target
      )
      assert_equal "zip bytes", File.read(target)
    end
  ensure
    server&.shutdown
  end

  def test_download_warns_and_fails_on_an_http_error
    server = StubHTTPServer.new("/download" => lambda { |_body| [500, "boom"] })
    in_tmpdir do |dir|
      _out, err = capture_io do
        refute SimpleEnglish::LanguageTool.download(
          "#{server.url}/download", File.join(dir, "lt.zip")
        )
      end
      assert_match(/HTTP 500/, err)
    end
  ensure
    server&.shutdown
  end

  def test_extract_unpacks_entries_under_the_dir
    in_tmpdir do |dir|
      zip = File.join(dir, "lt.zip")
      src = File.join(dir, "src.jar")
      File.write(src, "jar body")
      Zip::File.open(zip, create: true) do |archive|
        archive.add("LanguageTool-6.6/languagetool-commandline.jar", src)
      end
      assert SimpleEnglish::LanguageTool.extract(zip, dir)
      extracted = File.join(dir, "LanguageTool-6.6/languagetool-commandline.jar")
      assert_equal "jar body", File.read(extracted)
    end
  end

  def test_extract_refuses_entries_that_escape_the_dir
    in_tmpdir do |dir|
      zip = File.join(dir, "evil.zip")
      src = File.join(dir, "src.txt")
      File.write(src, "payload")
      Zip::File.open(zip, create: true) do |archive|
        archive.add("../evil.txt", src)
      end
      _out, err = capture_io do
        refute SimpleEnglish::LanguageTool.extract(zip, dir)
      end
      assert_match(/escapes the install dir/, err)
      refute File.exist?(File.expand_path(File.join(dir, "..", "evil.txt")))
    end
  end

  def test_extract_unpacks_a_stored_entry
    in_tmpdir do |dir|
      zip = File.join(dir, "lt.zip")
      src = File.join(dir, "src.txt")
      File.write(src, "stored body")
      Zip::File.open(zip, create: true) do |archive|
        archive.add_stored("LanguageTool-6.6/stored.txt", src)
      end
      assert SimpleEnglish::LanguageTool.extract(zip, dir)
      extracted = File.join(dir, "LanguageTool-6.6/stored.txt")
      assert_equal "stored body", File.read(extracted)
    end
  end

  def test_extract_warns_on_a_non_zip_file
    in_tmpdir do |dir|
      zip = File.join(dir, "lt.zip")
      File.binwrite(zip, "not a zip archive")
      _out, err = capture_io do
        refute SimpleEnglish::LanguageTool.extract(zip, dir)
      end
      assert_match(/unpack failed/, err)
    end
  end

  def test_extract_refuses_a_zip64_archive
    in_tmpdir do |dir|
      zip = File.join(dir, "lt.zip")
      src = File.join(dir, "src.txt")
      File.write(src, "payload")
      Zip::File.open(zip, create: true) { |a| a.add("x.txt", src) }
      bytes = File.binread(zip)
      at = bytes.rindex("PK\x05\x06")
      bytes[at + 16, 4] = [0xFFFFFFFF].pack("V")
      File.binwrite(zip, bytes)
      _out, err = capture_io do
        refute SimpleEnglish::LanguageTool.extract(zip, dir)
      end
      assert_match(/unpack failed/, err)
    end
  end

  def test_extract_rejects_an_entry_with_a_bad_crc
    in_tmpdir do |dir|
      zip = File.join(dir, "lt.zip")
      src = File.join(dir, "src.txt")
      File.write(src, "payload")
      Zip::File.open(zip, create: true) { |a| a.add("x.txt", src) }
      bytes = File.binread(zip)
      at = bytes.index("PK\x01\x02")
      bytes[at + 16, 4] = [0].pack("V")
      File.binwrite(zip, bytes)
      _out, err = capture_io do
        refute SimpleEnglish::LanguageTool.extract(zip, dir)
      end
      assert_match(/CRC mismatch/, err)
      refute File.exist?(File.join(dir, "x.txt"))
    end
  end

  def test_safe_entry_target_rejects_paths_outside_the_dir
    dir = "/cache"
    assert_equal "/cache/LanguageTool-6.6/x.jar",
      SimpleEnglish::LanguageTool.safe_entry_target(
        dir, "LanguageTool-6.6/x.jar"
      )
    assert_nil SimpleEnglish::LanguageTool.safe_entry_target(dir, "../evil.txt")
    assert_nil SimpleEnglish::LanguageTool.safe_entry_target(dir, "a/../../evil.txt")
    # An absolute entry name joins under the dir, so it stays contained.
    assert_equal "/cache/etc/passwd",
      SimpleEnglish::LanguageTool.safe_entry_target(dir, "/etc/passwd")
  end

  def test_smoke_returns_false_when_java_cannot_run
    install = SimpleEnglish::Install.new(
      cache_dir: "/cache", java: "/nonexistent/java"
    )
    _out, err = capture_io do
      refute SimpleEnglish::LanguageTool.smoke(install)
    end
    assert_empty err # smoke is a verdict, not a warning: setup prints the message
  end

  def test_smoke_passes_with_a_working_install
    install = SimpleEnglish::Install.from_env
    skip "needs java and the LanguageTool cache" unless File.exist?(install.commandline_jar) &&
      install.java?
    assert SimpleEnglish::LanguageTool.smoke(install)
  end

  def test_remove_stale_versions_keeps_the_current_dir_and_zips
    in_tmpdir do |dir|
      keep = File.join(dir, "LanguageTool-#{SimpleEnglish::LanguageTool::LT_VERSION}")
      stale_dir = File.join(dir, "LanguageTool-6.5")
      zip = File.join(dir, "LanguageTool-6.5.zip")
      FileUtils.mkdir_p([keep, stale_dir])
      File.write(zip, "bytes")
      SimpleEnglish::LanguageTool.remove_stale_versions(dir, keep)
      assert File.directory?(keep)
      assert File.exist?(zip)
      refute File.directory?(stale_dir)
    end
  end
end
