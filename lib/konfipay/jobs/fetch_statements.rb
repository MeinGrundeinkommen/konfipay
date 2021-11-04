# frozen_string_literal: true

module Konfipay
  module Jobs
    class FetchStatements < Konfipay::Jobs::Base
      def perform(callback_class, callback_method, which_ones, filters = {}, options = {})
        Konfipay::Operations::FetchStatements.new.fetch(which_ones, filters, options) do |data|
          run_callback(callback_class, callback_method, data)
        end
      end
    end
  end
end
