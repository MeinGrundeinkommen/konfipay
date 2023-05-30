# frozen_string_literal: true

module Konfipay
  module Jobs
    class Base
      include Sidekiq::Worker # TODO: This should be configurable

      def logger
        @config&.logger
      end

      def run_callback(callback_class, callback_method, data, transaction_id = nil)
        callback_class.constantize.send(callback_method, data, transaction_id)
      end

      def schedule_monitor(callback_class, callback_method, r_id, transaction_id)
        logger&.info "Scheduling job to monitor #{r_id} / #{transaction_id}"
        Konfipay::Jobs::MonitorTransfer.perform_in(
          @config.transfer_monitoring_interval,
          callback_class,
          callback_method,
          r_id,
          transaction_id
        )
      end
    end
  end
end
