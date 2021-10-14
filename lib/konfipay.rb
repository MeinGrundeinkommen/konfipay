# frozen_string_literal: true

require_relative 'konfipay/version'
require 'net/http'
require 'pry'

# comment
module Konfipay
  BASE_URL = 'https://portal.konfipay.de'

  class Error < StandardError; end

  # comment
  class Configuration
    attr_accessor :api_key

    def initialize
      @api_key = nil
    end
  end

  class << self
    attr_writer :configuration
  end

  def self.configuration
    @configuration ||= Configuration.new
  end

  def self.reset
    @configuration = Configuration.new
  end

  def self.config
    yield(configuration)
  end

  # comment
  class Connection
    def initialize
      authenticate
    end

    def authenticate
      binding.pry
      response = Net::HTTP.post("#{BASE_URL}/api/v4/Auth/Login/Token", {}, { 'Authorization' => "Bearer #{api_key}" })
    end
  end
end
