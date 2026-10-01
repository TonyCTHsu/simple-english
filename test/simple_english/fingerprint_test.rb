# frozen_string_literal: true

require_relative "test_helper"

class FingerprintTest < Minitest::Test
  def test_gem_digest_is_stable
    first = SimpleEnglish::Fingerprint.gem
    assert_match(/\A\h{64}\z/, first)
    assert_equal first, SimpleEnglish::Fingerprint.gem
  end

  def test_sha_digests_its_input
    assert_equal SimpleEnglish::Fingerprint.sha("a"), SimpleEnglish::Fingerprint.sha("a")
    refute_equal SimpleEnglish::Fingerprint.sha("a"), SimpleEnglish::Fingerprint.sha("b")
  end
end
