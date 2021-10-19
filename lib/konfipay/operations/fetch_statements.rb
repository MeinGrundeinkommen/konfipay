module Konfipay
  module Operations
    class FetchStatements < Base
      def fetch(which_ones, filters = {})
        case which_ones
        when "new"
          ["bli", "bla"]
        else
          raise "not implemented yet"
        end
      end
    end
  end
end
