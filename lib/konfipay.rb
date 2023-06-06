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
require_relative 'konfipay/operations/transfer_info'
require_relative 'konfipay/operations/fetch_statements'
require_relative 'konfipay/operations/initialize_transfer'
require_relative 'konfipay/jobs'
require_relative 'konfipay/jobs/base'
require_relative 'konfipay/jobs/fetch_statements'
require_relative 'konfipay/jobs/initialize_transfer'
require_relative 'konfipay/jobs/monitor_transfer'

# rubocop:disable Metrics/ParameterLists
module Konfipay
  DEFAULT_QUEUE_NAME = :default

  class << self
    # Fetches all "new" statements for all configured accounts since the last time successfully used.
    # Use queue: :xyz to run job in a specific sidekiq queue, default is :default
    # Use mark_as_read: false to keep retrieved data "unread", for testing.
    # Filter accounts by iban argument.
    # callback_class::callback_method will be called asynchronously with the resulting list of statements,
    # for the format see Konfipay::Operations::FetchStatements#fetch
    # api_key_name switches between multiple api_keys, if configured
    # This method itself only returns true.
    def new_statements(
      callback_class:,
      callback_method:,
      queue: DEFAULT_QUEUE_NAME,
      iban: nil,
      mark_as_read: true,
      api_key_name: nil
    )
      # TODO: We could move all validation and transformation into the Configuration class,
      # then use that here to make a dummy instance and return errors early, before the job goes into
      # Sidekiq. The same instance could serialize and deserialize to and from json-safe Sidekiq args
      Konfipay::Jobs::FetchStatements.set(queue: queue).perform_async(
        callback_class,
        callback_method,
        'new',
        { 'iban' => iban },
        { 'mark_as_read' => mark_as_read },
        extract_config_options(api_key_name: api_key_name)
      )
      true
    end

    # Fetches "history" of statements for all configured accounts between the two given dates
    # (as strings in iso-8601 format).
    # Use queue: :xyz to run job in a specific sidekiq queue, default is :default
    # Filter accounts by iban argument, if non-empty.
    # callback_class::callback_method will be called asynchronously with the resulting list of statements,
    # for the format see Konfipay::Operations::FetchStatements#fetch
    # api_key_name switches between multiple api_keys, if configured
    # This method itself only returns true.
    def statement_history(
      callback_class:,
      callback_method:,
      queue: DEFAULT_QUEUE_NAME,
      iban: nil,
      from: Date.today.iso8601,
      to: from,
      api_key_name: nil
    )
      Konfipay::Jobs::FetchStatements.set(queue: queue).perform_async(
        callback_class,
        callback_method,
        'history',
        { 'iban' => iban, 'from' => from, 'to' => to },
        {},
        extract_config_options(api_key_name: api_key_name)
      )
      true
    end

    # Start a new credit transfer, i.e. send money.
    #
    # payment_data format (all in json-compatible values, i.e. strings, numbers - no symbols) is:
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
    # Use queue: :xyz to run job in a specific sidekiq queue, default is :default
    #
    # callback_class::callback_method will be called asynchronously with info about the state of the operation,
    # for the format see Konfipay::Operations::InitializeCreditTransfer#submit
    #
    # api_key_name switches between multiple api_keys, if configured
    #
    # This method itself only returns true.
    #
    # Note that the callback method very likely will be called multiple times. An internal job
    # is repeatedly enqueued in Sidekiq to keep monitoring the process of the operation,
    # until a "final" state is reached (successfully or with an error). See configuration for
    # the interval in which checks are made.
    #
    def initialize_credit_transfer(
      callback_class:,
      callback_method:,
      payment_data:, transaction_id:, queue: DEFAULT_QUEUE_NAME,
      api_key_name: nil
    )
      Konfipay::Jobs::InitializeTransfer.set(queue: queue).perform_async(
        callback_class,
        callback_method,
        'credit_transfer',
        payment_data,
        transaction_id,
        extract_config_options(api_key_name: api_key_name)
      )
      true
    end

    # Start a new direct debit, i.e. "pull in" money from debtors with a debit mandate.
    #
    # Note that the workflow for this is the same as for ::initialize_credit_transfer,
    # this only creates and submits a different SEPA XML file to the Konfipay API,
    # which needs slightly different payment data.
    #
    # payment_data format (all in json-compatible values, i.e. strings, numbers) is:
    # {"creditor"=>
    #   {"name"=>"Your company",
    #    "iban"=>"DE02120300000000202051",
    #    "creditor_identifier" => 'DE98ZZZ09999999999',
    #    "bic"=>nil},
    #  "debitors"=>
    #   [{"name" => "Brittani Ziemann",
    #     "iban" => "DE02300209000106531065",
    #     "bic" => nil,
    #     "amount_in_cents" => 100000,
    #     "currency" => "EUR",
    #     "remittance_information" => "Here is the money, Lebowsky.",
    #     "end_to_end_reference" => "XYZ-0005-01",
    #     "execute_on" => "2022-09-01",
    #     "mandate_id" => 'K-02-2011-12345',
    #     "mandate_date_of_signature" => "2022-03-14",
    #     "local_instrument" => 'CORE',
    #     "sequence_type" => "RCUR"
    #     },
    #    ...
    #   ]
    # }
    #
    # See Konfipay::PainBuilder for details on the values.
    #
    def initialize_direct_debit(
      callback_class:,
      callback_method:,
      payment_data:,
      transaction_id:,
      queue: DEFAULT_QUEUE_NAME,
      api_key_name: nil
    )
      Konfipay::Jobs::InitializeTransfer.set(queue: queue).perform_async(
        callback_class,
        callback_method,
        'direct_debit',
        payment_data,
        transaction_id,
        extract_config_options(api_key_name: api_key_name)
      )
      true
    end

    def extract_config_options(api_key_name: nil)
      opts = {}
      # Make sure to be json-compatible and only pass on keys with values
      opts['api_key_name'] = api_key_name if api_key_name
      opts
    end
  end
end
# rubocop:enable Metrics/ParameterLists
