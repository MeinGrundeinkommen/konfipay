module Konfipay
  module Operations
    class FetchStatements < Base
      def fetch(which_ones, filters = {})
        iban = filters["iban"].presence
        opts = {}
        opts["iban"] = iban if iban
        list = case which_ones
        when "new"
          @client.new_statements(opts)
        else
          raise "not implemented yet"
        end

        binding.pry

      # TODO: Only get each statement doc if iban given and matching
      # TODO: Get each new document, collect and parse each CAMT and get out the actual statement info

      end
    end
  end
end
