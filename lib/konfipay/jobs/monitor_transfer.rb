# frozen_string_literal: true

module Konfipay
  module Jobs
    class MonitorTransfer < Konfipay::Jobs::Base
      def perform(callback_class, callback_method, r_id, transaction_id, use_other_api_key)
        data = Konfipay::Operations::TransferInfo.new.fetch(r_id, use_other_api_key)
        run_callback(callback_class, callback_method, data, transaction_id)
        schedule_monitor(callback_class, callback_method, r_id, transaction_id, use_other_api_key) unless data['final']
      end
    end
  end
end
