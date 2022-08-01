# frozen_string_literal: true

module Konfipay
  module Operations
    class InitializeCreditTransfer < Base

      # Starts a credit transfer (Überweisung) from one of our accounts to one or many recipients.
      # For the payment_data format, see
      # Konfipay::initialize_credit_transfer
      #
      # Format of data returned is:
      #
      # {"final"=>false,
      #  "success"=>true,
      #  "data"=>
      #   {"rId"=>"ef2abc7e-62b8-4603-8994-61a716e9fa81",
      #    "timestamp"=>"2022-06-08T16:20:52+02:00",
      #    "type"=>"pain",
      #    "paymentStatusItem"=>
      #     {"status"=>"FIN_UPLOAD_SUCCEEDED",
      #      "uploadTimestamp"=>"2022-06-08T16:20:53+02:00",
      #      "orderID"=>"N9D4"}}}
      # 
      # or it can raise a connection error exception.
      #
      # "final" means the process has finished, successfully or not.
      # "success" is when the money is on the way - note that it's not always possible to completely
      # know if the transactions are "done", this gem assumes that success is reached when the bank
      # has acknowledged the receipt of the payment info without error.
      # See Konfipay::Operations::Base#parse_pain_status for details, and also which "status" strings can
      # be returned by the Konfipay API.
      # "data" is verbatim what the Konfipay API returned for the initial process start.
      # Note that rId is needed to identify this transfer process on all subsequent (manual) API calls.
      def submit(payment_data, transaction_id)
        logger&.info "starting credit transfer for #{transaction_id.inspect}"
        # TODO: validate payment data again?
        xml = nil
        begin
          xml = Konfipay::PainBuilder.new(payment_data, transaction_id).credit_transfer_xml # here comes the pain
        rescue ArgumentError => e
          logger&.info "credit transfer failed to start, invalid payment_data"
          return {
            "final" => true,
            "success" => false,
            "data" => {
              "SEPA builder error" => e.inspect
            }
          }
        end
        client = Konfipay::Client.new
        data = nil
        begin
          data = client.submit_pain_file(xml)
        rescue Konfipay::Client::Unauthorized, Konfipay::Client::BadRequest => x
          logger&.info "credit transfer failed to start"
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
        logger&.info "credit transfer for #{transaction_id.inspect} started"
        result
      end
    end
  end
end
