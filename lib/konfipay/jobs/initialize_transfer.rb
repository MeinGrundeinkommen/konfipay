# frozen_string_literal: true

module Konfipay
  module Jobs
    class InitializeTransfer < Konfipay::Jobs::Base
      # Don't retry (could start multiple payments), but keep job in "dead" queue for debugging
      sidekiq_options retry: 0

      # rubocop:disable Metrics/ParameterLists
      def perform(callback_class, callback_method, mode, payment_data, transaction_id, config_options = {})
        @config = config_from_options(config_options)
        data = Konfipay::Operations::InitializeTransfer.new(@config).submit(mode, payment_data, transaction_id)
        run_callback(callback_class, callback_method, data, transaction_id)
        return if data['final']

        schedule_monitor(callback_class, callback_method, data['data']['rId'], transaction_id, config_options)
      end
      # rubocop:enable Metrics/ParameterLists
    end
  end
end
