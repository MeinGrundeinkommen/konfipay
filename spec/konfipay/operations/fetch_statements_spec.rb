# frozen_string_literal: true

require 'spec_helper'

# rubocop:disable RSpec/MessageSpies
# rubocop:disable RSpec/StubbedMock
# rubocop:disable RSpec/MultipleExpectations
RSpec.describe Konfipay::Operations::FetchStatements do
  let(:config) { Konfipay.configuration }
  let(:client) do
    Konfipay::Client.new(config)
  end
  let(:operation) { described_class.new(config, client) }
  let(:iban) { 'DE02300606010002474689' }

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

  let(:acknowledged_camt_file_json) do
    {
      'rId' => 'not important',
      'href' => 'not important',
      'timestamp' => 'not important',
      'iban' => 'not important',
      'isNew' => false,
      'format' => 'not important',
      'fileName' => 'not important'
    }
  end

  describe 'fetch new' do
    let(:fetch_it) do
      x = nil
      operation.fetch('new') do |result|
        x = result
      end
      x
    end

    it 'returns list of statements' do
      expect(client).to receive(:new_statements).with({}).and_return(statements_parsed_json)
      expect(client).to receive(:camt_file).with(r_id1, false).and_return(parsed_camt_file1)
      expect(client).to receive(:camt_file).with(r_id2, false).and_return(parsed_camt_file2)
      expect(client).to receive(:acknowledge_camt_file).with(r_id1).and_return(acknowledged_camt_file_json)
      expect(client).to receive(:acknowledge_camt_file).with(r_id2).and_return(acknowledged_camt_file_json)
      expect(fetch_it).to eq(expected_parsed_statements)
    end

    context 'when api returns empty list' do
      it 'returns empty list' do
        allow(client).to receive(:new_statements).with({}).and_return(nil)
        expect(fetch_it).to eq([])
      end
    end

    context 'when there is an error fetching the second camt file' do
      it "doesn't acknowledge the files" do
        expect(client).to receive(:new_statements).with({}).and_return(statements_parsed_json)
        expect(client).to receive(:camt_file).with(r_id1, false).and_return(parsed_camt_file1)
        expect(client).to receive(:camt_file).with(r_id2, false).and_raise('timeout haha')
        expect { fetch_it }.to raise_error('timeout haha')
      end
    end

    context 'when there is an error processing the results' do
      let(:fetch_it) do
        x = nil
        operation.fetch('new') do |_result|
          raise 'whups butter fingers'
        end
        x
      end

      it "doesn't acknowledge the files" do
        expect(client).to receive(:new_statements).with({}).and_return(statements_parsed_json)
        expect(client).to receive(:camt_file).with(r_id1, false).and_return(parsed_camt_file1)
        expect(client).to receive(:camt_file).with(r_id2, false).and_return(parsed_camt_file2)
        expect { fetch_it }.to raise_error('whups butter fingers')
      end
    end

    context "when an acknowledge doesn't work" do
      it 'raises an error about it' do
        expect(client).to receive(:new_statements).with({}).and_return(statements_parsed_json)
        expect(client).to receive(:camt_file).with(r_id1, false).and_return(parsed_camt_file1)
        expect(client).to receive(:camt_file).with(r_id2, false).and_return(parsed_camt_file2)
        expect(client).to receive(:acknowledge_camt_file).with(r_id1).and_return(
          {
            'rId' => 'not important',
            'href' => 'not important',
            'timestamp' => 'not important',
            'iban' => 'not important',
            'isNew' => true,
            'format' => 'not important',
            'fileName' => 'not important'
          }
        )
        expect { fetch_it }.to raise_error("Tried to acknowledge #{r_id1} but was still shown as new after!")
      end
    end

    context 'with filters' do
      let(:fetch_it) do
        x = nil
        operation.fetch('new', { 'iban' => iban }) do |result|
          x = result
        end
        x
      end

      it 'passes iban filter to client' do
        expect(client).to receive(:new_statements).with({ 'iban' => iban }).and_return(statements_parsed_json)
        expect(client).to receive(:camt_file).with(r_id1, false).and_return(parsed_camt_file1)
        expect(client).to receive(:camt_file).with(r_id2, false).and_return(parsed_camt_file2)
        expect(client).to receive(:acknowledge_camt_file).with(r_id1).and_return(acknowledged_camt_file_json)
        expect(client).to receive(:acknowledge_camt_file).with(r_id2).and_return(acknowledged_camt_file_json)
        expect(fetch_it).to eq(expected_parsed_statements)
      end
    end

    context 'with options' do
      let(:fetch_it) do
        x = nil
        operation.fetch('new', {}, { 'mark_as_read' => false }) do |result|
          x = result
        end
        x
      end

      it 'passes mark_as_read to client' do
        expect(client).to receive(:new_statements).with({}).and_return(statements_parsed_json)
        expect(client).to receive(:camt_file).with(r_id1, false).and_return(parsed_camt_file1)
        expect(client).to receive(:camt_file).with(r_id2, false).and_return(parsed_camt_file2)
        expect(fetch_it).to eq(expected_parsed_statements)
      end
    end
  end

  describe 'fetch history' do
    let(:from) { '2021-10-01' }
    let(:to) { '2021-12-01' }
    let(:filters) { { 'from' => from, 'to' => to, 'iban' => iban } }

    let(:fetch_it) do
      x = nil
      operation.fetch('history', filters) do |result|
        x = result
      end
      x
    end

    it 'returns list of statements' do
      expect(client).to receive(:statement_history).with(
        { 'start' => from,
          'end' => to,
          'iban' => iban }
      ).and_return(statements_parsed_json)
      expect(client).to receive(:camt_file).with(r_id1, false).and_return(parsed_camt_file1)
      expect(client).to receive(:camt_file).with(r_id2, false).and_return(parsed_camt_file2)
      expect(client).not_to receive(:acknowledge_camt_file)
      expect(fetch_it).to eq(expected_parsed_statements)
    end

    context 'when api returns empty list' do
      it 'returns empty list' do
        allow(client).to receive(:statement_history).with(
          { 'start' => from,
            'end' => to,
            'iban' => iban }
        ).and_return(nil)
        expect(fetch_it).to eq([])
      end
    end
  end
end
# rubocop:enable RSpec/MessageSpies
# rubocop:enable RSpec/StubbedMock
# rubocop:enable RSpec/MultipleExpectations
