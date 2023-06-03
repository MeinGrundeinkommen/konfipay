# frozen_string_literal: true

module Konfipay
  class Configuration
    BASE_URL_DEFAULT = 'https://portal.konfipay.de'
    TIMEOUT_DEFAULT = (10 * 60) # uploading large PAIN files can simply take a long time
    API_CLIENT_NAME_DEFAULT = 'Konfipay Ruby Client'
    API_CLIENT_VERSION_DEFAULT = Konfipay::VERSION
    TRANSFER_MONITORING_INTERVAL_DEFAULT = (10 * 60)

    attr_accessor :api_key, # API key used to access Konfipay API. Can be configured in Konfipay Portal.
                  :api_keys, # Define multiple api keys to be used on demand, see README
                  :logger, # Optional logger object - has to respond to debug, info, etc.
                  :timeout, # for http requests to API, in seconds
                  :base_url,
                  :api_client_name, # sent to konfipay with each http request as a papertrail
                  :api_client_version, # ditto
                  :transfer_monitoring_interval # how often to check for updates on a payment process, in seconds

    class << self
      attr_accessor :initializer_block
    end

    def check!
      %i[api_key base_url api_client_name api_client_version].each do |string|
        value = send(string)
        raise ArgumentError, "#{value.inspect} is not a valid #{string}!" if value.nil? || value.empty?
      end
      raise ArgumentError, "#{logger.inspect} is not a working logger!" if !logger.nil? && !logger.respond_to?(:info)

      %i[timeout transfer_monitoring_interval].each do |number_in_seconds|
        value = send(number_in_seconds)
        if value.to_i <= 0
          raise ArgumentError,
                "#{number_in_seconds} has to be a positive integer, not #{value.inspect}"
        end
      end

      # TODO: Check api keys is a hash with values and one is default
      # TODO: Check either api keys or one key

      self
    end

    def apply_gem_defaults!
      @timeout = TIMEOUT_DEFAULT
      @base_url = BASE_URL_DEFAULT
      @api_client_name = API_CLIENT_NAME_DEFAULT
      @api_client_version = API_CLIENT_VERSION_DEFAULT
      @transfer_monitoring_interval = TRANSFER_MONITORING_INTERVAL_DEFAULT
      self
    end

    def apply_initializer!(initializer_block)
      initializer_block&.call(self)
      self
    end

    # rubocop:disable Metrics/ParameterLists
    def apply_runtime_options!(api_key: nil, logger: nil, timeout: nil, base_url: nil, api_client_name: nil,
                               api_client_version: nil, transfer_monitoring_interval: nil, api_key_name: nil)
      @api_key = api_key if api_key
      @logger = logger if logger
      @timeout = timeout if timeout
      @base_url = base_url if base_url
      @api_client_name = api_client_name if api_client_name
      @api_client_version = api_client_version if api_client_version
      @transfer_monitoring_interval = transfer_monitoring_interval if transfer_monitoring_interval
      if api_key_name
        # TODO: Check it's one of the defined keys or raise
        @api_key_name = api_key_name
      end
      self
    end
    # rubocop:enable Metrics/ParameterLists

    def api_key
      if @api_keys.present?
        if key = @api_keys[@api_key_name]
          @logger&.info "Using #{@api_key_name.inspect} api_key"
          key
        else
          @logger&.info "Using default api_key"
          @api_keys["default"]
        end
      else
        @api_key
      end
    end
  end

  def self.configure(&block)
    Konfipay::Configuration.initializer_block = block
    nil
  end

  # The main way to get to configuration - this will initialize a new Konfipay::Configuration instance
  # when called and applies gem defaults, initializer defaults (from Konfipay.configure) and last
  # passed-in options - see Konfipay::Configuration#apply_runtime_options! for the possible parameters
  #
  # A simple sanity check on values is also performed.
  def self.configuration(**kwargs)
    Konfipay::Configuration.new.tap do |config|
      config.apply_gem_defaults!
      config.apply_initializer!(Konfipay::Configuration.initializer_block)
      config.apply_runtime_options!(**kwargs)
      config.check!
    end
  end
end
