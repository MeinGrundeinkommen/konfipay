# frozen_string_literal: true

module Konfipay
  module Operations
    class Base
      def initialize(config = nil, client = nil)
        @config = (config || Konfipay.configuration)
        @client = (client || Konfipay::Client.new(@config))
      end

      def logger
        @config&.logger
      end
    end
  end
end
