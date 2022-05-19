# frozen_string_literal: true

module Konfipay
  module Jobs
    class MonitorCreditTransfer < Konfipay::Jobs::Base
      def perform(callback_class, callback_method, r_id, transaction_id)
        data = Konfipay::Operations::CreditTransfer.new.fetch(r_id, transaction_id)
        run_callback(callback_class, callback_method, data, transaction_id)
        unless data["final"]
          schedule_credit_monitor(callback_class, callback_method, r_id, transaction_id)
        end
      end
    end
  end
end
