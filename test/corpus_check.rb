# frozen_string_literal: true

# Run the corpus pairs in test/corpus through the daemon.
#
# Usage: run `se serve` (or let the first lint start it), then
#   ruby test/corpus_check.rb

require_relative "../lib/simple_english"

exit(SimpleEnglish.corpus_test ? 0 : 1)
