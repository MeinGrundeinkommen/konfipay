# frozen_string_literal: true

require 'http'
require 'sepa_king'
require 'camt_parser'
require 'sidekiq'

require_relative 'konfipay/version'
require_relative 'konfipay/configuration'
require_relative 'konfipay/client'
require_relative 'konfipay/operations'
require_relative 'konfipay/operations/base'
require_relative 'konfipay/operations/credit_transfer'
require_relative 'konfipay/operations/fetch_statements'
require_relative 'konfipay/operations/initialize_credit_transfer'
require_relative 'konfipay/jobs'
require_relative 'konfipay/jobs/base'
require_relative 'konfipay/jobs/fetch_statements'
require_relative 'konfipay/jobs/initialize_credit_transfer'
require_relative 'konfipay/jobs/monitor_credit_transfer'

module Konfipay
  class << self
    # Fetches all "new" statements for all configured accounts since the last time successfully used.
    # Use mark_as_read = false to keep retrieved data "unread", for testing.
    # Filter accounts by iban argument, if non-empty.
    # callback_class::callback_method will be called asynchronously with the resulting list of statements,
    # for the format see Konfipay::Operations::FetchStatements#show
    # This method itself only returns true.
    def new_statements(callback_class, callback_method, iban = nil, mark_as_read = true) # rubocop:disable Style/OptionalBooleanParameter
      # TODO: validate input, check that class and method are implemented, check if iban is valid
      Konfipay::Jobs::FetchStatements.perform_async(
        callback_class,
        callback_method,
        'new',
        { 'iban' => iban },
        { 'mark_as_read' => mark_as_read }
      )
      true
    end

    # TODO: Not needed now, but might be useful
    # def statements(callback_class, callback_method, iban = nil, from = nil, to = nil)
    #   # TODO: validate input, check that class and method are implemented, check if iban is valid,
    #   # check from and to are Date objects, check dates are logical
    #   Konfipay::Jobs::FetchStatements.perform_async(callback_class, callback_method, 'history',
    #                                                 { 'iban' => iban, 'from' => from, 'to' => to })
    # end

    # TODO: Implement when needed
    # # TODO: Document payment_data format
    # # TODO: Document format of info passed to callback
    # # TODO: IMplement some sort of validator class and use in all these kickoff-methods?
    # def initialize_credit_transfer(callback_class, callback_method, payment_data = {})
    #   # TODO: validate input, check that class and method are implemented
    #   Konfipay::Jobs::InitializeCreditTransfer.perform_async(callback_class, callback_method, payment_data)
    # end

    # def initialize_direct_debit(opts); end
  end
end
