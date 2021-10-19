module Konfipay
  module Operations
    class Base
      
      def initialize
        @client = Konfipay::Client.new
      end
    end
  end
end
