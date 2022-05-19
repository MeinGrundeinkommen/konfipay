# frozen_string_literal: true

module Konfipay
  module Operations
    # TODO: Genralize? Probably same op useful for debits
    class CreditTransfer < Base
      # Returns info about this Credit Transfer's status:
      # TODO: format
      def fetch(r_id, transaction_id)
        puts "running credit transfer check"
        puts r_id
        puts transaction_id

        client = Konfipay::Client.new
        data = nil
        begin
          data = client.pain_file_info(r_id)
        rescue Konfipay::Client::Unauthorized, Konfipay::Client::BadRequest => x
          return {
            "final" => true,
            "success" => false,
            "data" => {
              "error_class" => x.class.name,
              "message" => x.message
            }
          }
        end
        parse_pain_status(data)        
      end
    end
  end
end
