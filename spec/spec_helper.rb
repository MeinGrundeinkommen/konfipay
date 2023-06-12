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
    stub_sidekiq_redis_connection_double
  end

  def stub_sidekiq_redis_connection_double
    @sidekiq_redis_pool_double = instance_double(ConnectionPool)
    allow(Sidekiq).to receive(:redis_pool).and_return(@sidekiq_redis_pool_double)
    @sidekiq_redis_connection_double = instance_double(Sidekiq::RedisClientAdapter::CompatClient)
    allow(@sidekiq_redis_pool_double).to receive(:with).and_yield(@sidekiq_redis_connection_double)
  end

  # rubocop:disable Style/TrivialAccessors
  def sidekiq_redis_connection_double
    @sidekiq_redis_connection_double
  end
  # rubocop:enable Style/TrivialAccessors

  config.include ActiveSupport::Testing::TimeHelpers
end
