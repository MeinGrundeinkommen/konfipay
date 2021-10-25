# frozen_string_literal: true

module Konfipay
  module Jobs
    class InitializeCreditTransfer < Konfipay::Jobs::Base

      # Don't retry (could start multiple payments), but keep job in "dead" queue for debugging
      sidekiq_options retry: 0

      def perform(callback_class, callback_method, data)
        result = Konfipay::Operations::InitializeCreditTransfer.new.submit(data)
        run_callback(callback_class, callback_method, result)
        schedule_credit_monitor(callback_class, callback_method, result["r_id"])
      end
    end
  end
end
