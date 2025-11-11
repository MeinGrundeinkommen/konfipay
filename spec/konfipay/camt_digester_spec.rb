# frozen_string_literal: true

require 'spec_helper'
RSpec.describe Konfipay::CamtDigester do
  let(:parsed_statements) { described_class.new(parsed_camt_file).statements }

  let(:expected_parsed_statements) do
    [
      { 'additional_information' => 'Überweisungsauftrag',
        'amount_in_cents' => 2000,
        'currency' => 'EUR',
        'end_to_end_reference' => 'Transfer-0001/09',
        'executed_on' => '2022-01-28',
        'fees' => nil,
        'iban' => 'DE02701500000000594937',
        'name' => 'Donald Duck',
        'original_amount_in_cents' => nil,
        'remittance_information' => 'Auszahlung - Februar 2022 - 9. Monat',
        'reason_code' => nil,
        'return_information' => nil,
        'type' => 'debit' },
      { 'additional_information' => 'Überweisungsauftrag',
        'amount_in_cents' => 2000,
        'currency' => 'EUR',
        'end_to_end_reference' => 'Transfer-0002/09',
        'executed_on' => '2022-01-28',
        'fees' => nil,
        'iban' => 'DE88100900001234567892',
        'name' => 'Sir Isaac Newton',
        'original_amount_in_cents' => nil,
        'remittance_information' => 'Auszahlung - Februar 2022 - 9. Monat',
        'reason_code' => nil,
        'return_information' => nil,
        'type' => 'debit' }
    ]
  end

  shared_examples_for 'a camt file with format' do |format|
    let(:parsed_camt_file) do
      # This file is based on a real example, but anonymized.
      # It contains an entry with a credit collection with two transactions - i.e.
      # "our" side sent out money to two recipients in one go, and this shows up in our
      # account as a debit with two transactions.
      CamtParser::String.parse(File.read("spec/examples/camt053/outgoing_collection_#{format}.xml"))
    end

    it 'parses statements correctly' do
      expect(parsed_statements).to eq(expected_parsed_statements)
    end
  end

  it_behaves_like 'a camt file with format', '02'
  it_behaves_like 'a camt file with format', '08'
end
