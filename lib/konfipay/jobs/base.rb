# frozen_string_literal: true

module Konfipay
  module Jobs
    class Base
      include Sidekiq::Worker # TODO: This should be configurable

      def initialize
        @config = Konfipay.configuration
      end

      def logger
        @config.logger
      end

      def run_callback(callback_class, callback_method, data)
        callback_class.constantize.send(callback_method, data)
      end

      def schedule_credit_monitor(callback_class, callback_method, r_id)
        logger&.info "Scheduling job to check for credit transfer #{r_id}"
        Konfipay::Jobs::MonitorCreditTransfer.perform_in(
          @config.credit_monitoring_interval,
          r_id,
          callback_class,
          callback_method
        )
      end
    end
  end
end
