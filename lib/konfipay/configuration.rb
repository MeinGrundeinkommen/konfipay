# frozen_string_literal: true

module Konfipay
  BASE_URL = 'https://portal.konfipay.de'

  class Configuration
    attr_accessor :api_key, # API key used to access Konfipay API. Can be configured in Konfipay Portal.
                  :normal_api_key,
                  :other_api_key,
                  :logger, # Optional logger object - has to respond to debug, info, etc.
                  :timeout, # for http requests to API, 30s by default
                  :base_url,
                  :api_client_name, # sent to konfipay with each http request as a papertrail
                  :api_client_version, # ditto
                  # in seconds, 10 minutes by default - how often to check for updates on a payment process
                  :transfer_monitoring_interval

    def initialize
      @timeout = (10 * 60) # uploading large PAIN files can simply take a long time
      # TODO: Make a short timeout for GETs and a large one for the other http verbs?
      @base_url = BASE_URL
      @normal_api_key = @api_key
      @api_client_name = 'Konfipay Ruby Client'
      @api_client_version = Konfipay::VERSION
      @transfer_monitoring_interval = 10 * 60
    end

    def check!
      %i[api_key base_url api_client_name api_client_version].each do |string|
        value = send(string)
        raise ArgumentError, "#{value.inspect} is not a valid #{string}!" if value.nil? || value.empty?
      end
      raise ArgumentError, "#{logger.inspect} is not a working logger!" if !logger.nil? && !logger.respond_to?(:info)

      %i[timeout transfer_monitoring_interval].each do |number_in_seconds|
        value = send(number_in_seconds)
        raise ArgumentError, "#{value.inspect} has to be a positive integer" if value.to_i <= 0
      end
    end
  end

  class << self
    attr_writer :configuration
  end

  def self.configuration(*args)
    @configuration ||= Configuration.new(*args)
  end

  def self.reset_configuration!
    @configuration = nil
  end

  def self.configure
    yield(configuration)
    configuration.check!
    configuration
  end
end
