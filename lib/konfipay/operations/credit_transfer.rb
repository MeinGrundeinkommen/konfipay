# frozen_string_literal: true

module Konfipay
  module Operations
    class CreditTransfer < Base

      # Returns info about this Credit Transfer's status:
      # TODO: format
      def fetch(r_id)

        # TODO:
        # get status from konfipay
        puts 'hey there, just checking for the dang transfer again yo'
#        puts r_id
        # parse/check result

        # TODO: if 404, return a "final" state to stop monitoring / alert main app code



        {
          "r_id" => "aaaaaaaaaaaa"
        }
      end
    end
  end
end
