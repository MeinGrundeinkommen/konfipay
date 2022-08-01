# frozen_string_literal: true

require 'active_support'
require 'active_support/core_ext'
require 'http'
require 'sepa_king'
require 'camt_parser'
require 'sidekiq'

require_relative 'konfipay/version'
require_relative 'konfipay/configuration'
require_relative 'konfipay/client'
require_relative 'konfipay/camt_digester'
require_relative 'konfipay/pain_builder'
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

# rubocop:disable Metrics/ParameterLists
# rubocop:disable Style/OptionalBooleanParameter
# rubocop:disable Style/OptionalArguments
module Konfipay
  class << self
    # Fetches all "new" statements for all configured accounts since the last time successfully used.
    # Use "queue" to run job in a specific sidekiq queue, default is :default
    # Use mark_as_read = false to keep retrieved data "unread", for testing.
    # Filter accounts by iban argument, if non-empty.
    # callback_class::callback_method will be called asynchronously with the resulting list of statements,
    # for the format see Konfipay::Operations::FetchStatements#fetch
    # This method itself only returns true.
    def new_statements(
      callback_class,
      callback_method,
      queue = nil,
      iban = nil,
      mark_as_read = true
    )
      queue ||= :default
      Konfipay::Jobs::FetchStatements.set(queue: queue).perform_async(
        callback_class,
        callback_method,
        'new',
        { 'iban' => iban },
        { 'mark_as_read' => mark_as_read }
      )
      true
    end

    # Fetches "history" of statements for all configured accounts between the two given dates
    # (as strings in iso-8601 format).
    # Use "queue" to run job in a specific sidekiq queue, default is :default
    # Filter accounts by iban argument, if non-empty.
    # callback_class::callback_method will be called asynchronously with the resulting list of statements,
    # for the format see Konfipay::Operations::FetchStatements#fetch
    # This method itself only returns true.
    def statement_history(
      callback_class,
      callback_method,
      queue = nil,
      iban = nil,
      from = Date.today.iso8601,
      to = from
    )
      queue ||= :default
      Konfipay::Jobs::FetchStatements.set(queue: queue).perform_async(
        callback_class,
        callback_method,
        'history',
        { 'iban' => iban, 'from' => from, 'to' => to },
        {}
      )
      true
    end

    # Start a new credit transfer, i.e. send money.
    #
    # payment_data format (all in json-compatible values, i.e. strings, numbers) is:
    # {"debtor"=>
    #   {"name"=>"Your company",
    #    "iban"=>"DE02120300000000202051",
    #    "bic"=>nil},
    #  "creditors"=>
    #   [{"name" => "Brittani Ziemann",
    #     "iban" => "DE02300209000106531065",
    #     "bic" => nil,
    #     "amount_in_cents" => 100000,
    #     "currency" => "EUR",
    #     "remittance_information" => "Here is the money, Lebowsky.",
    #     "end_to_end_reference" => "XYZ-0005-01",
    #     "execute_on" => "2022-09-01"},
    #    ...
    #   ]
    # }
    # bics and end_to_end_reference are optional.
    # The transaction_id should be unique and alphanumerical, it is used for the
    # "Message Identification" field to identify the whole transfer process.
    # The end_to_end_reference identifies the single transaction and is visible to the creditor.
    #
    # Use "queue" to run job in a specific sidekiq queue, default is :default
    #
    # callback_class::callback_method will be called asynchronously with info about the state of the transfer,
    # for the format see Konfipay::Operations::InitializeCreditTransfer#submit
    #
    # This method itself only returns true.
    #
    # Note that the callback method very likely will be called multiple times. An internal job
    # is repeatedly enqueued in Sidekiq to keep monitoring the process of the transfer,
    # until a "final" state is reached (successfully or with an error). See configuration for
    # the interval in which checks are made.
    #
    # # TODO: Implement some sort of validator class and use in all these kickoff-methods?
    def initialize_credit_transfer(
      callback_class,
      callback_method,
      queue = nil,
      payment_data,
      transaction_id
    )
      # TODO: validate input, check that class and method are implemented
      queue ||= :default # TODO: This should be in configuration and not repeated here
      Konfipay::Jobs::InitializeCreditTransfer.set(queue: queue).perform_async(
        callback_class,
        callback_method,
        payment_data,
        transaction_id
      )
      true
    end

    # def initialize_direct_debit(opts); end
  end
end
# rubocop:enable Metrics/ParameterLists
# rubocop:enable Style/OptionalBooleanParameter
# rubocop:enable Style/OptionalArguments
