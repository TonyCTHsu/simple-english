# frozen_string_literal: true

require_relative "test_helper"

require "tmpdir"

class FingerprintTest < Minitest::Test
  USER_A = <<~XML
    <?xml version="1.0" encoding="UTF-8"?>
    <rules lang="en">
      <rule id="TEAM_A" name="No alpha">
        <pattern><token>alpha</token></pattern>
        <message>Do not write alpha.</message>
      </rule>
    </rules>
  XML

  USER_B = <<~XML
    <?xml version="1.0" encoding="UTF-8"?>
    <rules lang="en">
      <rule id="TEAM_B" name="No beta">
        <pattern><token>beta</token></pattern>
        <message>Do not write beta.</message>
      </rule>
    </rules>
  XML

  def test_gem_digest_is_stable
    first = SimpleEnglish::Fingerprint.gem
    assert_match(/\A\h{64}\z/, first)
    assert_equal first, SimpleEnglish::Fingerprint.gem
  end

  def test_rules_digest_moves_with_user_rules
    Dir.mktmpdir do |dir|
      a = File.join(dir, "a.xml")
      b = File.join(dir, "b.xml")
      File.write(a, USER_A)
      File.write(b, USER_B)
      digest_a = SimpleEnglish::Fingerprint.sha(
        SimpleEnglish::Server.merged_rules([a])
      )
      digest_b = SimpleEnglish::Fingerprint.sha(
        SimpleEnglish::Server.merged_rules([b])
      )
      refute_equal digest_a, digest_b
    end
  end
end
