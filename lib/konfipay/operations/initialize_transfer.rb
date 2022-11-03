# frozen_string_literal: true

module Konfipay
  module Operations
    class InitializeTransfer < Base
      # Starts a credit transfer (Überweisung) from one of our accounts to one or many recipients,
      # or a direct debit to "pull" money from debitors that have granted a debit mandate.
      # The "mode" argument has to be "credit_transfer" or "direct_debit"
      #
      # For the payment_data format, see
      # Konfipay::initialize_credit_transfer
      # and
      # Konfipay::initialize_direct_debit
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
      def submit(mode, payment_data, transaction_id)
        raise ArgumentError, "Unknown mode #{mode.inspect}" unless %w[credit_transfer direct_debit].include?(mode)

        logger&.info "starting #{mode.inspect} transfer for #{transaction_id.inspect}"
        # TODO: validate payment data again?
        xml = nil
        begin
          builder = Konfipay::PainBuilder.new(payment_data, transaction_id)
          xml = case mode
                when 'credit_transfer'
                  builder.credit_transfer_xml
                when 'direct_debit'
                  builder.direct_debit_xml
                else
                  raise ArgumentError, "Unknown mode #{mode.inspect}"
                end
        rescue ArgumentError => e
          logger&.info "#{mode.inspect} failed to start, invalid payment_data"
          return {
            'final' => true,
            'success' => false,
            'data' => {
              'SEPA builder error' => e.inspect
            }
          }
        end
        data = nil
        begin
          data = @client.submit_pain_file(xml) # here comes the pain
        rescue Konfipay::Client::Unauthorized, Konfipay::Client::BadRequest => e
          logger&.info "#{mode.inspect} failed to start"
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
        logger&.info "#{mode.inspect} for #{transaction_id.inspect} started"
        result
      end
    end
  end
end
