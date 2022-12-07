# frozen_string_literal: true

module Konfipay
  module Jobs
    class FetchStatements < Konfipay::Jobs::Base
      def perform(options_hash)
        options = Konfipay::Options.from_hash(options_hash, @config)
        Konfipay::Operations::FetchStatements.new.fetch(
          options.operation.mode,
          options.operation.filters.to_hash,
          options.operation.options.to_hash
        ) do |data|
          run_callback(
            options.callback.class_name,
            options.callback.method_name,
            data
          )
        end
      end
    end
  end
end
