# frozen_string_literal: true

module Konfipay
  module Operations
    class TransferInfo < Base
      # Returns info about this transfer (credit or debit) status.
      # Return format is the same as for
      # Konfipay::Operations::InitializeTransfer#submit
      #
      # The r_id was returned after the first successful #submit call.
      def fetch(r_id)
        logger&.info "Fetching info for r_id #{r_id.inspect}"

        data = nil
        begin
          data = @client.pain_file_info(r_id)
        rescue Konfipay::Client::Unauthorized, Konfipay::Client::BadRequest => e
          logger&.error "Transfer info fetch for r_id #{r_id.inspect} finished with error"
          return {
            'final' => true,
            'success' => false,
            'data' => {
              'error_class' => e.class.name,
              'message' => e.message
            }
          }
        end
        result = parse_pain_status(data)
        logger&.info "Transfer info fetch for r_id #{r_id.inspect} finished"
        result
      end
    end
  end
end
