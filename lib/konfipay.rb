# frozen_string_literal: true

require 'http'
require 'sepa_king'
require 'camt_parser'

require_relative 'konfipay/version'
require_relative 'konfipay/configuration'
require_relative 'konfipay/client'
require_relative 'konfipay/operations'
require_relative 'konfipay/operations/base'
require_relative 'konfipay/operations/fetch_statements'
require_relative 'konfipay/jobs'
require_relative 'konfipay/jobs/base'
# TODO: Do this less clumsily and according to configured jobs adapter
require_relative 'konfipay/jobs/fetch_statements'
require_relative 'konfipay/jobs/initialize_credit_transfer'
require_relative 'konfipay/jobs/monitor_credit_transfer'

module Konfipay
  # https://portal.konfipay.de/doc/PaymentWorkflow.png
  class << self
    # Fetches and returns financial statements for all configured accounts.
    # This returns all "new" statements since the last time this was called.
    # Filter accounts by iban argument.
    def new_statements(callback_class, callback_method, iban = nil)
      # TODO: validate input, check that class and method are implemented, check if iban is valid
      Konfipay::Jobs::FetchStatements.perform_async(callback_class, callback_method, 'new', { 'iban' => iban })
    end

    def statements(callback_class, callback_method, iban = nil, from = nil, to = nil)
      # TODO: validate input, check that class and method are implemented, check if iban is valid,
      # check from and to are Date objects, check dates are logical
      Konfipay::Jobs::FetchStatements.perform_async(callback_class, callback_method, 'history',
                                                    { 'iban' => iban, 'from' => from, 'to' => to })
    end

    def initialize_credit_transfer(callback_class, callback_method, payment_data = {})
      # TODO: validate input, check that class and method are implemented
      Konfipay::Jobs::InitializeCreditTransfer.perform_async(callback_class, callback_method, payment_data)
    end

    def initialize_direct_debit(opts); end
  end
end
