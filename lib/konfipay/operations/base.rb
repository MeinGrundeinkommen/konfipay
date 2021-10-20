# frozen_string_literal: true

module Konfipay
  module Operations
    class Base
      def initialize
        @config = Konfipay.configuration
        @client = Konfipay::Client.new
      end

      def logger
        @config.logger
      end
    end
  end
end
