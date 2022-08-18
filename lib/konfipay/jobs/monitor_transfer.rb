# frozen_string_literal: true

module Konfipay
  module Jobs
    class MonitorTransfer < Konfipay::Jobs::Base
      def perform(callback_class, callback_method, r_id, transaction_id)
        data = Konfipay::Operations::TransferInfo.new.fetch(r_id)
        run_callback(callback_class, callback_method, data, transaction_id)
        schedule_monitor(callback_class, callback_method, r_id, transaction_id) unless data['final']
      end
    end
  end
end
