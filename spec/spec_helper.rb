# frozen_string_literal: true

require 'bundler/setup'
require 'pry'
require 'simplecov'
SimpleCov.start
require 'konfipay'
require 'webmock/rspec'
require 'active_support/testing/time_helpers'

require 'sidekiq/testing'
Sidekiq::Testing.fake!

require 'support/example_callback_class'

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.before do
    @sidekiq_redis_pool_dummy = Class.new.new
    @sidekiq_redis_connection_dummy = Class.new.new
    allow(Sidekiq).to receive(:redis_pool).and_return(@sidekiq_redis_pool_dummy)
    allow(@sidekiq_redis_pool_dummy).to receive(:with).and_yield(@sidekiq_redis_connection_dummy)
  end

  # rubocop:disable Style/TrivialAccessors
  def sidekiq_redis_connection_dummy
    @sidekiq_redis_connection_dummy
  end
  # rubocop:enable Style/TrivialAccessors

  config.include ActiveSupport::Testing::TimeHelpers
end
