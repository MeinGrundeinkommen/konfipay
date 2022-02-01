# frozen_string_literal: true

module Konfipay
  # Adds functionality on top of camt_parser gem
  class CamtDigester

    # Expects an instance of CamtParser::Format053::Base :
    # https://github.com/viafintech/camt_parser/blob/master/lib/camt_parser/053/base.rb
    def initialize(camt)
      @camt = camt
    end

    def statements
      result = []
      @camt.statements.each do |statement|
        statement.entries.each do |entry|
          entry.transactions.each do |transaction|

  #            binding.pry
            base = base_hash(entry, transaction)

            result << base
          end
        end
      end
      result
    end

    def base_hash(entry, transaction)

      {
        'name' => transaction.name.presence,
        'iban' => transaction.iban.presence,
        'type' => transaction.debit? ? 'debit' : 'credit',
        'amount_in_cents' => transaction.amount_in_cents,
        'currency' => transaction.currency.presence,
        "original_amount_in_cents" => nil,
        'fees' => nil,
        'executed_on' => entry.booking_date.iso8601,
        'end_to_end_reference' => transaction.end_to_end_reference.presence,
        'remittance_information' => transaction.remittance_information.presence,
        "return_information" => nil,
        "additional_information" => entry.additional_information.presence,
      }

      # {
      #   'name' => transaction.name.presence,
      #   'iban' => transaction.iban.presence,
      #   'type' => transaction.debit? ? 'debit' : 'credit',
      #   'amount_in_cents' => transaction.amount_in_cents,
      #   'currency' => transaction.currency.presence,
      #   "original_amount_in_cents" => nil,
      #   'fees' => nil,
      #   'executed_on' => entry.booking_date.iso8601,
      #   'end_to_end_reference' => transaction.end_to_end_reference.presence,
      #   'remittance_information' => transaction.remittance_information.presence,
      #   "return_information" => nil,
      #   "additional_information" => entry.additional_information.presence,
      # }
    end

  end
end
