require "konfipay/version"

module Konfipay
  class Error < StandardError; end

  class << self
    attr_accessor :api_key

    BASE_URL = 'https://www.konfipay.de'.freeze

    def config
      yield self
    end
  end

  def authenticate

  end
end
