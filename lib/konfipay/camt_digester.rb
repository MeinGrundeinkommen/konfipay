# frozen_string_literal: true

module Konfipay
  # Adds functionality on top of camt_parser gem
  # To use directly for debugging:
  #
  # rails c (in including project):
  #
  # Konfipay::CamtDigester.new(CamtParser::String.parse(File.read("camtfile.XML"))).statements
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
            base = base_hash(entry, transaction)
            if transaction.debit?
              base.merge!(debit_hash(transaction))
            else
              base.merge!(credit_hash(transaction))
            end

            result << base
          end
        end
      end
      result
    end

    def base_hash(entry, transaction)
      {
        'name' => nil,
        'iban' => nil,
        'type' => transaction.debit? ? 'debit' : 'credit',
        'amount_in_cents' => nil,
        'currency' => transaction.currency.presence,
        'original_amount_in_cents' => nil,
        'fees' => nil,
        'executed_on' => entry.booking_date.iso8601,
        'end_to_end_reference' => transaction.end_to_end_reference.presence,
        'remittance_information' => transaction.remittance_information.presence,
        'return_information' => nil,
        'additional_information' => entry.additional_information.presence
      }
    end

    def debit_hash(transaction)
      # Have to crowbar in, the gem allows no access :/
      xml = transaction.instance_variable_get(:@xml_data)

      transaction_amount = parse_cents(xml.xpath('AmtDtls/TxAmt/Amt').text)
      original_amount = parse_cents(xml.xpath('AmtDtls/InstdAmt/Amt').text)

      {
        'name' => transaction.debitor.name.presence || transaction.creditor.name.presence,
        'iban' => transaction.debitor.iban.presence,
        'amount_in_cents' => transaction_amount,
        'original_amount_in_cents' => original_amount,
        'fees' => extract_fees(xml),
        'return_information' => xml.xpath('RtrInf/AddtlInf').text.presence
      }
    end

    def credit_hash(transaction)
      {
        'amount_in_cents' => transaction.amount_in_cents,
        'name' => transaction.name.presence,
        'iban' => transaction.iban.presence
      }
    end

    def extract_fees(xml)
      charges = xml.xpath('Chrgs')
      return unless charges.any?

      charges.map do |charge|
        {
          'amount_in_cents' => parse_cents(charge.xpath('Amt').text),
          'from_bic' => charge.xpath('Pty/FinInstnId/BIC').text
        }
      end
    end

    def parse_cents(text)
      CamtParser::Misc.to_amount_in_cents(text)
    end
  end
end
