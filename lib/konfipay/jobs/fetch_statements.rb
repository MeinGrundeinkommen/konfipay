# frozen_string_literal: true

module Konfipay
  module Jobs
    class FetchStatements < Konfipay::Jobs::Base
      # rubocop:disable Metrics/ParameterLists
      def perform(callback_class, callback_method, mode, filters = {}, options = {}, config_options = {})
        @config = config_from_options(config_options)
        Konfipay::Operations::FetchStatements.new(@config).fetch(mode, filters, options) do |data|
          run_callback(callback_class, callback_method, data)
        end
      end
      # rubocop:enable Metrics/ParameterLists
    end
  end
end
