# frozen_string_literal: true

# Runs every test file in test/simple_english in one process.
Dir[File.expand_path("simple_english/*_test.rb", __dir__)].sort.each { |file| require file }
