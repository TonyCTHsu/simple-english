# frozen_string_literal: true

# Fingerprints for the daemon handshake. `gem` identifies the code and
# built-in rules a daemon runs: any release that changes lint behavior
# changes it, and nothing else does. `sha` covers the merged rule
# content (built-in plus BYOR files) wherever the caller resolved it.

require_relative "languagetool"

module SimpleEnglish
  module Fingerprint
    module_function

    # Hash everything the daemon can execute, not a curated list: a
    # curated list goes stale the first time a new file is forgotten,
    # and a missed file means silent staleness, the exact bug the
    # handshake exists to catch. The accepted cost: a release that
    # only changes caller-side code triggers one needless restart.
    # ponytail: whole-lib glob. If restarts ever hurt, curate per-file.
    def gem
      files = Dir.glob(File.expand_path("../../**/*.rb", __dir__)).sort
      files << LanguageTool::RULES_FILE
      # Each file is length-prefixed: bare concatenation cannot tell
      # ["ab", "c"] from ["a", "bc"], so bytes moved across a file
      # boundary leave the digest unchanged.
      framed = files.map do |path|
        content = File.read(path)
        "#{content.bytesize}\n#{content}"
      end
      sha(framed.join)
    end

    def sha(content)
      require "digest"
      ::Digest::SHA256.hexdigest(content)
    end
  end
end
