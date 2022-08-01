# frozen_string_literal: true

module Konfipay
  module Operations
    class CreditTransfer < Base
      # Returns info about this credit transfer's status.
      # Return format is the same as for 
      # Konfipay::Operations::InitializeCreditTransfer#submit
      #
      # The r_id was returned after the first successful #submit call.
      def fetch(r_id)
        logger&.info "credit transfer fetch operation started for r_id #{r_id.inspect}"

        client = Konfipay::Client.new
        data = nil
        begin
          data = client.pain_file_info(r_id)
        rescue Konfipay::Client::Unauthorized, Konfipay::Client::BadRequest => x
          logger&.info "credit transfer fetch operation finished with error"
          return {
            "final" => true,
            "success" => false,
            "data" => {
              "error_class" => x.class.name,
              "message" => x.message
            }
          }
        end
        result = parse_pain_status(data)
        logger&.info "credit transfer fetch operation finished"
        result
      end
    end
  end
end
