# frozen_string_literal: true

module Konfipay
  module Jobs
    class InitializeCreditTransfer < Konfipay::Jobs::Base
      # Don't retry (could start multiple payments), but keep job in "dead" queue for debugging
      sidekiq_options retry: 0

      def perform(callback_class, callback_method, payment_data, transaction_id)
        data = Konfipay::Operations::InitializeCreditTransfer.new.submit(payment_data, transaction_id)
        run_callback(callback_class, callback_method, data, transaction_id)
        unless data["final"]
          schedule_credit_monitor(callback_class, callback_method, data["data"]['rId'], transaction_id)
        end
      end
    end
  end
end
