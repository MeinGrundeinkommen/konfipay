# frozen_string_literal: true

require 'bundler/setup'
require 'pry'
require 'simplecov'
SimpleCov.start
require 'konfipay'
require 'webmock/rspec'
require 'active_support/testing/time_helpers'

require 'support/example_callback_class'

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.include ActiveSupport::Testing::TimeHelpers

  config.after do
    Konfipay.reset_configuration!
  end
end
