# frozen_string_literal: true

module Konfipay
  module Jobs
    class InitializeTransfer < Konfipay::Jobs::Base
      # Don't retry (could start multiple payments), but keep job in "dead" queue for debugging
      sidekiq_options retry: 0

      def perform(callback_class, callback_method, mode, payment_data, transaction_id)
        data = Konfipay::Operations::InitializeTransfer.new(@config).submit(mode, payment_data, transaction_id)
        run_callback(callback_class, callback_method, data, transaction_id)
        return if data['final']

        schedule_monitor(callback_class, callback_method, data['data']['rId'], transaction_id)
      end
    end
  end
end
