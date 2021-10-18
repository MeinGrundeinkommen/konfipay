# frozen_string_literal: true

require_relative 'konfipay/version'
require 'http'
require 'pry' # TODO: Only require in development mode?

require_relative 'konfipay/configuration'
require_relative 'konfipay/client'
require_relative 'konfipay/jobs'
# TODO: Do this less clumsily and according to configured jobs adapter
require_relative 'konfipay/jobs/fetch_statements'
require_relative 'konfipay/jobs/initialize_credit_transfer'
require_relative 'konfipay/jobs/monitor_credit_transfer'

module Konfipay

  # https://portal.konfipay.de/doc/PaymentWorkflow.png
  class << self

    def new_statements(iban: nil, callback_class:, callback_method:)
      # TODO: validate input, check that class and method are implemented, check if iban is valid
      Konfipay::Jobs::FetchStatements.perform_async(:new, iban, callback_class, callback_method)
    end

    def initialize_credit_transfer(payment_data:, callback_class:, callback_method:)
      # TODO: validate input, check that class and method are implemented
      Konfipay::Jobs::InitializeCreditTransfer.perform_async(payment_data, callback_class, callback_method)
    end

    def initialize_direct_debit(opts)
    end
  end
end
