# frozen_string_literal: true

module Konfipay
  module Operations
    class InitializeCreditTransfer < Base
      # Starts a credit transfer (Überweisung) from one of our accounts to one or many recipients.
      # TODO: format
      def submit(payment_data)
        pp(payment_data)
        # TODO: validate payment data again?

        # client = Konfipay::Client.new

        # TODO: check data
        ## pp data
        # maybe split up in sub-tasks if there are very many transfers
        # make PAIN xml in memory
        # upload to konfipay
        # parse/check result

        {
          'r_id' => 'aaaaaaaaaaaa'
        }
      end
    end
  end
end
