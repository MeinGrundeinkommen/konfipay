# frozen_string_literal: true

module Konfipay
  module Jobs
    class InitializeCreditTransfer
      include Sidekiq::Worker # TODO: This should be configurable

      def perform(_data, callback_class, callback_method)
        client = Konfipay::Client.new

        # TODO: check data
        ## pp data
        # maybe split up in sub-tasks if there are very many transfers
        # make PAIN xml in memory
        # upload to konfipay
        # parse/check result

        r_id = 'jdajhckschdkjschsdkjhskjbj'

        callback_class.constantize.send(callback_method, { data: :data })

        # TODO: Kick off monitoring job(s)
        Konfipay::Jobs::MonitorCreditTransfer.perform_in(10.seconds, r_id, callback_class, callback_method)
      end
    end
  end
end
