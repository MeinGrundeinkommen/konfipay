# frozen_string_literal: true

module Konfipay
  # Adds functionality on top of sepa_king gem: https://github.com/salesking/sepa_king
  # to create in-memory SEPA Pain (Payment Initiation) XML files
  # for credit transfers and debits.
  class PainBuilder
    attr_accessor :payment_data, :transaction_id

    def initialize(payment_data, transaction_id)
      @payment_data = payment_data
      @transaction_id = transaction_id
    end

    def credit_transfer_builder
      # Comments here are from sepa_king docs: https://github.com/salesking/sepa_king
      builder = SEPA::CreditTransfer.new(
        # Name of the initiating party and debtor, in German: "Auftraggeber"
        # String, max. 70 char
        name: payment_data['debtor']['name'],
        # OPTIONAL: Business Identifier Code (SWIFT-Code) of the debtor
        # String, 8 or 11 char
        bic: payment_data['debtor']['bic'],
        # International Bank Account Number of the debtor
        # String, max. 34 chars
        iban: payment_data['debtor']['iban']
      )

      builder.message_identification = transaction_id

      payment_data['creditors'].each do |creditor_data|
        builder.add_transaction(
          # Name of the creditor, in German: "Zahlungsempfänger"
          # String, max. 70 char
          name: creditor_data['name'],
          # OPTIONAL: Business Identifier Code (SWIFT-Code) of the creditor's account
          # String, 8 or 11 char
          bic: creditor_data['bic'],
          # International Bank Account Number of the creditor's account
          # String, max. 34 chars
          iban: creditor_data['iban'],
          # Amount
          # Number with two decimal digit
          amount: (Float(creditor_data['amount_in_cents']) / 100),
          # OPTIONAL: Currency, EUR by default (ISO 4217 standard)
          # String, 3 char
          currency: creditor_data['currency'],
          # OPTIONAL: End-To-End-Identification, will be submitted to the creditor
          # String, max. 35 char
          reference: creditor_data['end_to_end_reference'],
          # OPTIONAL: Unstructured remittance information, in German "Verwendungszweck"
          # String, max. 140 char
          remittance_information: creditor_data['remittance_information'],
          # OPTIONAL: Requested execution date, in German "Ausführungstermin"
          # Date
          requested_date: Date.parse(creditor_data['execute_on']),
          # OPTIONAL: Enables or disables batch booking, in German "Sammelbuchung / Einzelbuchung"
          # True or False
          # See also https://www.sepaforcorporates.com/sepa-payments/why-sepa-batch-booking-is-important/
          batch_booking: true,
          # OPTIONAL: Urgent Payment
          # One of these strings:
          #   'SEPA' ("SEPA-Zahlung")
          #   'URGP' ("Taggleiche Eilüberweisung")
          service_level: 'SEPA'
        )
      end
      builder
    end

    def credit_transfer_xml(format = 'pain.001.003.03')
      credit_transfer_builder.to_xml(format)
    end
  end
end
