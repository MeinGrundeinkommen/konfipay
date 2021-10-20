# frozen_string_literal: true

module Konfipay
  module Jobs
    class MonitorCreditTransfer < Konfipay::Jobs::Base

      def perform(r_id, callback_class, callback_method)
        data = Konfipay::Operations::CreditTransfer.new.fetch(r_id)
        run_callback(callback_class, callback_method, data)
        # TODO: stop this if a final state is reached
        schedule_credit_monitor(callback_class, callback_method, r_id)
      end
    end
  end
end
