# frozen_string_literal: true

module Konfipay
  module Jobs
    class Base
      include Sidekiq::Worker # TODO: This should be configurable

      def config_from_options(config_options)
        Konfipay.configuration(api_key_name: config_options['api_key_name'])
      end

      def logger
        @config&.logger
      end

      def run_callback(callback_class, callback_method, data, transaction_id = nil)
        callback_class.constantize.send(callback_method, data, transaction_id)
      end

      def schedule_monitor(callback_class, callback_method, r_id, transaction_id, config_options = {})
        logger&.info "Scheduling job to monitor #{r_id} / #{transaction_id}"
        Konfipay::Jobs::MonitorTransfer.perform_in(
          @config.transfer_monitoring_interval,
          callback_class,
          callback_method,
          r_id,
          transaction_id,
          config_options
        )
      end

      def retrieve_payment_data_from_redis(key)
        json = Sidekiq.redis_pool.with do |conn|
          conn.call("GETDEL", key)
        end
        raise "Could not get payment data from redis at #{key.inspect}!" if json.nil?
        JSON.parse(json)
      end
    end
  end
end
