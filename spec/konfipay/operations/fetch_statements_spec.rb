# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Konfipay::Operations::FetchStatements do
  let(:config) { Konfipay.configuration }
  let(:client) do
    Konfipay::Client.new(config)
  end
  let(:operation) { described_class.new(config, client) }
  let(:iban) { 'DE02300606010002474689' }

  describe 'fetch new' do
    let(:fetch_it) { operation.fetch('new') }

    let(:r_id1) { 'x-y-z' }
    let(:r_id2) { 'f-g-h' }

    let(:statements_parsed_json) do
      { 'documentItems' =>
        [{
          'rId' => r_id1,
          'href' => "api/v4.0/Document/Camt/#{r_id1}",
          'timestamp' => '2021-10-28T23:21:59+02:00',
          'iban' => iban,
          'isNew' => true,
          'format' => 'camt.053',
          'fileName' => "2021-10-28_C53_#{iban}_EUR_365352.xml"
        },

         {
           'rId' => r_id2,
           'href' => "api/v4.0/Document/Camt/#{r_id2}",
           'timestamp' => '2021-10-28T23:21:59+02:00',
           'iban' => iban,
           'isNew' => true,
           'format' => 'camt.053',
           'fileName' => "2021-10-28_C53_#{iban}_EUR_365352.xml"
         }] }
    end

    let(:parsed_camt_file1) do
      CamtParser::String.parse(File.read('spec/examples/camt053/CAMT.053_458b71be-2ba3-488e-a898-11e6a5b421d6.XML'))
    end

    let(:parsed_camt_file2) do
      CamtParser::String.parse(File.read('spec/examples/camt053/failed_debit.xml'))
    end

    let(:expected_parsed_statement1) do
      JSON.parse(File.read('spec/examples/camt053/CAMT.053_458b71be-2ba3-488e-a898-11e6a5b421d6-parsed-by-gem.json'))
    end

    let(:expected_parsed_statement2) do
      [
        { 'amount_in_cents' => 68,
          'bic' => nil,
          'currency' => 'EUR',
          'end_to_end_reference' => nil,
          'executed_on' => '2021-11-01',
          'iban' => nil,
          'name' => nil,
          'reference' =>
          'BERECHTIGTE ABLEHNUNG EINER AUTORISIERTEN UBERWEISUNG / LASTSCHRIFT MANGELS ' \
          'KONTODECKUNG ODER WEGEN FEHLENDER / FEHLERHAFTEN ANGABEN.',
          'type' => 'debit' }
      ]
    end

    let(:expected_parsed_statements) do
      expected_parsed_statement1 + expected_parsed_statement2
    end

    it 'returns list of statements' do
      allow(client).to receive(:new_statements).with({}).and_return(statements_parsed_json)
      allow(client).to receive(:camt_file).with(r_id1, true).and_return(parsed_camt_file1)
      allow(client).to receive(:camt_file).with(r_id2, true).and_return(parsed_camt_file2)
      expect(fetch_it).to eq(expected_parsed_statements)
    end

    context 'when api returns empty list' do
      it 'returns empty list' do
        allow(client).to receive(:new_statements).with({}).and_return(nil)
        expect(fetch_it).to eq([])
      end
    end

    context 'with filters' do
      it 'passes iban filter to client' do
        allow(client).to receive(:new_statements).with({ 'iban' => iban }).and_return(statements_parsed_json)
        allow(client).to receive(:camt_file).with(r_id1, true).and_return(parsed_camt_file1)
        allow(client).to receive(:camt_file).with(r_id2, true).and_return(parsed_camt_file2)
        expect(operation.fetch('new', { 'iban' => iban })).to eq(expected_parsed_statements)
      end
    end

    context 'with options' do
      it 'passes mark_as_read to client' do
        allow(client).to receive(:new_statements).with({}).and_return(statements_parsed_json)
        allow(client).to receive(:camt_file).with(r_id1, false).and_return(parsed_camt_file1)
        allow(client).to receive(:camt_file).with(r_id2, false).and_return(parsed_camt_file2)
        expect(operation.fetch('new', {}, { 'mark_as_read' => false })).to eq(expected_parsed_statements)
      end
    end
  end
end
