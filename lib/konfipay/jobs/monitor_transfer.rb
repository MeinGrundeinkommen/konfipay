# frozen_string_literal: true

module Konfipay
  module Jobs
    class MonitorTransfer < Konfipay::Jobs::Base
      def perform(callback_class, callback_method, r_id, transaction_id, config_options = {})
        @config = config_from_options(config_options)
        data = Konfipay::Operations::TransferInfo.new(@config).fetch(r_id)
        run_callback(callback_class, callback_method, data, transaction_id)
        schedule_monitor(callback_class, callback_method, r_id, transaction_id, config_options) unless data['final']
      end
    end
  end
end
