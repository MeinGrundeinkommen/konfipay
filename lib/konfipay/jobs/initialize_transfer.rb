# frozen_string_literal: true

module Konfipay
  module Jobs
    class InitializeTransfer < Konfipay::Jobs::Base
      # Don't retry (could start multiple payments), but keep job in "dead" queue for debugging
      sidekiq_options retry: 0

      def perform(callback_class, callback_method, mode, payment_data, transaction_id, use_other_api_key) # rubocop:disable Metrics/ParameterLists
        data = Konfipay::Operations::InitializeTransfer.new.submit(mode, payment_data, transaction_id,
                                                                   use_other_api_key)
        run_callback(callback_class, callback_method, data, transaction_id)
        return if data['final']

        schedule_monitor(callback_class, callback_method, data['data']['rId'], transaction_id, use_other_api_key)
      end
    end
  end
end
