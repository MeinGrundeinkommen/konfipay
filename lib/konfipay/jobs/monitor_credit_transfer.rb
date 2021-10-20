# frozen_string_literal: true

module Konfipay
  module Jobs
    class MonitorCreditTransfer
      include Sidekiq::Worker # TODO: This should be configurable

      def perform(r_id, callback_class, callback_method)
        client = Konfipay::Client.new

        # TODO:
        # get status from konfipay
        puts 'hey there, just checking for the dang transfer again yo'
        puts r_id
        # parse/check result

        callback_class.constantize.send(callback_method, { data: :data })

        # TODO: if not one of the final states, schedule yourself again

        Konfipay::Jobs::MonitorCreditTransfer.perform_in(10.seconds, r_id, callback_class, callback_method)
      end
    end
  end
end
