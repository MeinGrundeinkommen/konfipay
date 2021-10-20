# frozen_string_literal: true

module Konfipay
  module Jobs
    class Base
      include Sidekiq::Worker # TODO: This should be configurable

      def run_callback(callback_class, callback_method, data)
        callback_class.constantize.send(callback_method, data)
      end
    end
  end
end
