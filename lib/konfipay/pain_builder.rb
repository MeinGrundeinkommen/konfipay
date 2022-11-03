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
      # Override default (Time.now.iso8601) to use proper time zone
      builder.creation_date_time = Time.current.iso8601

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

    def credit_transfer_xml(format = 'pain.001.001.03')
      credit_transfer_builder.to_xml(format)
    end

    def direct_debit_builder
      # Comments here are from sepa_king docs: https://github.com/salesking/sepa_king
      builder = SEPA::DirectDebit.new(
        # Name of the initiating party and creditor, in German: "Auftraggeber"
        # String, max. 70 char
        name: payment_data['creditor']['name'],
        # OPTIONAL: Business Identifier Code (SWIFT-Code) of the creditor
        # String, 8 or 11 char
        bic: payment_data['creditor']['bic'],
        # International Bank Account Number of the creditor
        # String, max. 34 chars
        iban: payment_data['creditor']['iban'],
        # Creditor Identifier, in German: Gläubiger-Identifikationsnummer
        # String, max. 35 chars
        creditor_identifier: payment_data['creditor']['creditor_identifier']
      )

      builder.message_identification = transaction_id
      # Override default (Time.now.iso8601) to use proper time zone
      builder.creation_date_time = Time.current.iso8601

      payment_data['debitors'].each do |debitor_data|
        builder.add_transaction(
          # Name of the debtor, in German: "Zahlungspflichtiger"
          # String, max. 70 char
          name: debitor_data['name'],
          # OPTIONAL: Business Identifier Code (SWIFT-Code) of the creditor's account
          # String, 8 or 11 char
          bic: debitor_data['bic'],
          # International Bank Account Number of the debtor's account
          # String, max. 34 chars
          iban: debitor_data['iban'],
          # Amount
          # Number with two decimal digit
          amount: (Float(debitor_data['amount_in_cents']) / 100),
          # OPTIONAL: Currency, EUR by default (ISO 4217 standard)
          # String, 3 char
          currency: debitor_data['currency'],
          # OPTIONAL: End-To-End-Identification, will be submitted to the debtor
          # String, max. 35 char
          reference: debitor_data['end_to_end_reference'],
          # OPTIONAL: Unstructured remittance information, in German "Verwendungszweck"
          # String, max. 140 char
          remittance_information: debitor_data['remittance_information'],
          # OPTIONAL: Requested collection date, in German "Fälligkeitsdatum der Lastschrift"
          # Date
          requested_date: Date.parse(debitor_data['execute_on']),
          # Mandate identifikation, in German "Mandatsreferenz"
          # String, max. 35 char
          mandate_id: debitor_data['mandate_id'],
          # Mandate Date of signature, in German "Datum, zu dem das Mandat unterschrieben wurde"
          # Date
          mandate_date_of_signature: Date.parse(debitor_data['mandate_date_of_signature']),
          # Local instrument, in German "Lastschriftart"
          # One of these strings:
          #   'CORE' ("Basis-Lastschrift")
          #   'COR1' ("Basis-Lastschrift mit verkürzter Vorlagefrist")
          #   'B2B' ("Firmen-Lastschrift")
          local_instrument: debitor_data['local_instrument'],
          # Sequence type
          # One of these strings:
          #   'FRST' ("Erst-Lastschrift")
          #   'RCUR' ("Folge-Lastschrift")
          #   'OOFF' ("Einmalige Lastschrift")
          #   'FNAL' ("Letztmalige Lastschrift")
          sequence_type: debitor_data['sequence_type'],
          # OPTIONAL: Enables or disables batch booking, in German "Sammelbuchung / Einzelbuchung"
          # True or False
          # See also https://www.sepaforcorporates.com/sepa-payments/why-sepa-batch-booking-is-important/
          batch_booking: true
        )
      end
      builder
    end

    def direct_debit_xml(format = 'pain.008.001.02')
      direct_debit_builder.to_xml(format)
    end
  end
end
