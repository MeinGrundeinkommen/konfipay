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
        'timestamp' => '2022-01-05T23:21:59+02:00',
        'iban' => iban,
        'isNew' => true,
        'format' => 'camt.053',
        'fileName' => "2021-01-05_C53_#{iban}_EUR_365352.xml"
      },

       {
         'rId' => r_id2,
         'href' => "api/v4.0/Document/Camt/#{r_id2}",
         'timestamp' => '2022-01-21T23:21:59+02:00',
         'iban' => iban,
         'isNew' => true,
         'format' => 'camt.053',
         'fileName' => "2022-01-21_C53_#{iban}_EUR_365352.xml"
       }] }
  end

  let(:parsed_camt_file1) do
    # This file is based on a real example, but anonymized. It contains several types of transactions:
    # * a normal credit - someone sent us money via Dauerauftrag
    # * a debit by our bank - they charge us for account fees
    # * a debit collection - we request money from three different user accounts in one "batch"
    # * a debit return - one of the debits has "bounced" as the account is no more (it is an ex-account), with fees charged to us
    # * a debit return - one of the debits is canceled without fees, a "Storno"
    CamtParser::String.parse(File.read('spec/examples/camt053/mixed_examples.xml'))
  end

  let(:parsed_camt_file2) do
    # Just another failed debit, just to have a second file
    CamtParser::String.parse(File.read('spec/examples/camt053/failed_debit_with_charges.xml'))
  end

  let(:expected_parsed_statement1) do
    [
      { 
        'amount_in_cents' => 500,
        'currency' => 'EUR',
        'end_to_end_reference' => "NOTPROVIDED",
        'executed_on' => '2022-01-05',
        'iban' => "DE02120300000000202051",
        'name' => "J.P. Morgan",
        'remittance_information' => 'Spende',
        'type' => 'credit',
        'additional_information' => 'Dauerauftragsgutschr',
        'original_amount_in_cents' => nil,
        'fees' => nil,
        'return_information' => nil,
      },
      { 
        'amount_in_cents' => 2167,
        'currency' => 'EUR',
        'end_to_end_reference' => nil,
        'executed_on' => '2022-01-05',
        'iban' => nil,
        'name' => "Unsere Bank",
        'remittance_information' => 'Einlagenentgelt 11.2021',
        'type' => 'debit',
        'additional_information' => 'Entgelt/Auslagen',
        'original_amount_in_cents' => nil,
        'fees' => nil,
        'return_information' => nil,
      },
      { 
        'amount_in_cents' => 1100,
        'currency' => 'EUR',
        'end_to_end_reference' => "Mandat15-05.01.2022",
        'executed_on' => '2022-01-05',
        'iban' => "DE02500105170137075030",
        'name' => "David Rockefeller",
        'remittance_information' => 'Mandat15: 9.00 EUR in den Grundeinkommenstopf - 2.00 EUR Spende an den Verein. Vielen Dank',
        'type' => 'credit',
        'additional_information' => 'Basislastschrift Ev',
        'original_amount_in_cents' => nil,
        'fees' => nil,
        'return_information' => nil,
      },
      { 
        'amount_in_cents' => 2200,
        'currency' => 'EUR',
        'end_to_end_reference' => "Mandat21-05.01.2022",
        'executed_on' => '2022-01-05',
        'iban' => "DE02100500000054540402",
        'name' => "Mayer Amschel Rothschild",
        'remittance_information' => 'Mandat21: 0.00 EUR in den Grundeinkommenstopf - 22.00 EUR Spende an den Verein. Vielen Dank',
        'type' => 'credit',
        'additional_information' => 'Basislastschrift Ev',
        'original_amount_in_cents' => nil,
        'fees' => nil,
        'return_information' => nil,
      },
      { 
        'amount_in_cents' => 3300,
        'currency' => 'EUR',
        'end_to_end_reference' => "Mandat22-05.01.2022",
        'executed_on' => '2022-01-05',
        'iban' => "DE02300209000106531065",
        'name' => "Herman Cain",
        'remittance_information' => 'Mandat22: 27.00 EUR in den Grundeinkommenstopf - 5.00 EUR Spende an den Verein. Vielen Dank',
        'type' => 'credit',
        'additional_information' => 'Basislastschrift Ev',
        'original_amount_in_cents' => nil,
        'fees' => nil,
        'return_information' => nil,
      },
        { 
        'amount_in_cents' => 1350,
        'currency' => 'EUR',
        'end_to_end_reference' => "Mandat15-05.01.2022",
        'executed_on' => '2022-01-05',
        'iban' => "DE02300606010002474689",
        'name' => "David Rockefeller",
        'remittance_information' => 'Retoure, Rueckgabegrund: AC04 Konto aufgelöst SVWZ: RETURN/REFUND Dibbel dabbel zweite Zeile',
        'type' => 'debit',
        'additional_information' => 'Retourenbelastung',
        'original_amount_in_cents' => 1100,
        'fees' => [
          {
            "amount_in_cents" => 250,
            "from_bic" => "OURBIC123"
          }
        ],
        'return_information' => "Konto aufgelöst",
      },
        { 
        'amount_in_cents' => 2200,
        'currency' => 'EUR',
        'end_to_end_reference' => "Mandat21-05.01.2022",
        'executed_on' => '2022-01-05',
        'iban' => "",
        'name' => "",
        'remittance_information' => 'Retoure aus SEPA Basislastschrift, Rueckweisungsgrund: Wegen Fehler zurückgewiesen SVWZ: RETURN/REFUND',
        'type' => 'debit',
        'additional_information' => nil,
        'original_amount_in_cents' => nil,
        'fees' => nil,
        'return_information' => "Storno",
      }
    ]
  end

  let(:expected_parsed_statement2) do
    [
        { 
        'amount_in_cents' => 1550,
        'currency' => 'EUR',
        'end_to_end_reference' => "MANDATE123-05.01.2022",
        'executed_on' => '2022-01-21',
        'iban' => "DE80733900000100121738",
        'name' => "Max Mustermann",
        'remittance_information' => 'Retoure SEPA Lastschrift',
        'type' => 'debit',
        'additional_information' => 'Retourenbelastung',
        'original_amount_in_cents' => 1000,
        'fees' => [
          {
            "amount_in_cents" => 300,
            "from_bic" => "THEIRBIC123"
          },
          {
            "amount_in_cents" => 250,
            "from_bic" => "OURBIC123"
          }
        ],
        'return_information' => "Lastschriftwiderspruch durch den Zahlungspflichtig",
      }
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
