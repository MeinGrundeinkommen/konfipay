# frozen_string_literal: true

module Konfipay
  BASE_URL = 'https://portal.konfipay.de'

  class Configuration
    attr_accessor :api_key, :logger, :timeout, :base_url, :api_client_name, :api_client_version, :credit_monitoring_interval

    def initialize
      @timeout = 10
      @base_url = BASE_URL
      @api_client_name = 'Konfipay Ruby Client'
      @api_client_version = Konfipay::VERSION
      @credit_monitoring_interval = 10.minutes

      # TODO: If logger is given, maybe wrap, copy, or extend the instance somehow so
      # log messages get prefixed with something like "Konfipay #{VERSION}: " ?
    end
  end

  class << self
    attr_writer :configuration
  end

  def self.configuration
    @configuration ||= Configuration.new
  end

  # TODO: Run sanity check after this was called to catch misconfiguration early
  def self.configure
    yield(configuration)
  end
end
