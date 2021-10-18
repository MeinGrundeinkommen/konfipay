# frozen_string_literal: true

require_relative 'konfipay/version'
require 'http'
require 'pry' # TODO: Only require in development mode?

module Konfipay

  # TODO: Move the config stuff into its own file?
  BASE_URL = 'https://portal.konfipay.de'

#  class Error < StandardError; end

  class Configuration
    attr_accessor :api_key, :logger, :timeout, :base_url, :api_client_name, :api_client_version

    def initialize
      @timeout = 10
      @base_url = BASE_URL
      @api_client_name = "Konfipay Ruby Client"
      @api_client_version = Konfipay::VERSION
    end
  end

  class << self
    attr_writer :configuration
  end

  def self.configuration
    @configuration ||= Configuration.new
  end

  # def self.reset
  #   @configuration = Configuration.new
  # end

  def self.configure
    yield(configuration)
  end

  # TODO: Also should be in own file
  class Client

    def initialize
      @config = Konfipay.configuration
      @bearer_token = nil
    end

    def get_statements(iban)
      authenticate if @bearer_token.nil?
      # TODO: Catch and retry 401 error
      response = http.auth("Bearer #{@bearer_token}").get("#{@config.base_url}/api/v4/Document/Camt")
      json = JSON.parse(response.body.to_s)

      # probably need to get list of docs, then get each one separately
    end

    def get_camt_file(r_id)
      authenticate if @bearer_token.nil?
      response = http.auth("Bearer #{@bearer_token}").get("#{@config.base_url}/api/v4/Document/Camt/#{r_id}")
      # todo: parse with camt_parser
      #json = JSON.parse(response.body.to_s)
    end

# rough sketch on payments "interface"
#
    # def initialize_credit_transfer(name:, bic:, ..., on_success: ~> {}, on_error: ~> {})

    # end

# admin area: TransferCollection.create -> causes:

# client = Konfipay::Client.new
# client.initialize_credit_transfer({
#   iban: ...
#   ,
#   transfers: [
#     {
#       name: "martin",
#       amount: 12_000,
#     }
#     ...
#   ],
#   on_success: ~> { Mailer.send_payouts_initialized_mail },
#   on_invalid: ~> { Mailer.send_payouts_failed },
# })


    def http
      HTTP.timeout(@config.timeout)
        .headers(accept: "application/json")
        .use(logging: { logger: @config.logger })
    end

    def authenticate
      response = http.post("#{@config.base_url}/api/v4/Auth/Login/Token",
        json: {
          "apiKey": @config.api_key,
          "client": {
            "name": @config.api_client_name,
            "version": @config.api_client_version
          }
        }
      )
      raise response.inspect unless response.status.success?
      @bearer_token = JSON.parse(response.body.to_s)["accessToken"]
      raise "AAAAAA" unless @bearer_token # TODO: better message/error class?

      # on any other api call, set @bearer_token to nil if response is 401, then use authenticate again and retry (once)
    end
  end
end
