# frozen_string_literal: true

require 'spec_helper'

# rubocop:disable RSpec/MessageSpies
# rubocop:disable RSpec/StubbedMock
# rubocop:disable RSpec/MultipleExpectations
RSpec.describe Konfipay::Operations::InitializeCreditTransfer do
  let(:config) { Konfipay.configuration }
  let(:client) do
    Konfipay::Client.new(config)
  end
  let(:operation) { described_class.new(config, client) }
  let(:transaction_id) { 'Transaction-ID-123-xyz' }
  let(:first_iban) { 'DE36733900000000121738' }
  let(:payment_data) do
    { 'debtor' =>
      { 'name' => 'Unsere Organisation',
        'iban' => 'DE62650700240021982400',
        'bic' => nil },
      'creditors' =>
      [
        { 'name' => 'Daniela Bartell',
          'iban' => first_iban,
          'bic' => nil,
          'amount_in_cents' => 100_000,
          'currency' => 'EUR',
          'remittance_information' => 'Ihre Auszahlung, viel Freude!',
          'end_to_end_reference' => 'XXX-0008-01',
          'execute_on' => '2022-09-01' },
        { 'name' => 'Iluminada Pfeffer',
          'iban' => 'DE87290400900104040100',
          'bic' => nil,
          'amount_in_cents' => 100_000,
          'currency' => 'EUR',
          'remittance_information' => 'Ihre Auszahlung, viel Freude!',
          'end_to_end_reference' => 'XXX-0011-02',
          'execute_on' => '2022-09-01' },
        { 'name' => 'Alexa Medhurst',
          'iban' => 'DE36733900000000121738',
          'bic' => nil,
          'amount_in_cents' => 100_000,
          'currency' => 'EUR',
          'remittance_information' => 'Ihre Auszahlung, viel Freude!',
          'end_to_end_reference' => 'XXX-0012-03',
          'execute_on' => '2022-09-01' }
      ] }
  end
  let(:expected_generated_xml) { File.read('spec/examples/pain.001.003.03/credit_transfer.xml') }
  let(:parsed_data_from_api) do
    {
      'rId' => 'ef2abc7e-62b8-4603-8994-61a716e9fa81',
      'timestamp' => '2022-08-09T17:10:19+02:00',
      'type' => 'pain',
      'paymentStatusItem' => {
        'status' => 'FIN_UPLOAD_SUCCEEDED',
        'uploadTimestamp' => '2022-08-09T17:10:21+02:00',
        'orderID' => 'N9GB'
      }
    }
  end

  describe 'submit' do
    let(:submit_it) do
      operation.submit(payment_data, transaction_id)
    end

    around do |example|
      Time.use_zone('US/Eastern') do
        travel_to(Time.zone.parse('2022-08-09T16:38:56')) do
          example.run
        end
      end
    end

    it 'generates and submits pain xml, then returns parsed initial status' do
      expect(client).to receive(:submit_pain_file).with(expected_generated_xml).and_return(parsed_data_from_api)
      expect(submit_it).to eq({
                                'final' => false,
                                'success' => true,
                                'data' => parsed_data_from_api
                              })
    end

    context 'when payment_data is invalid' do
      let(:first_iban) { 'nope' }

      it 'returns error and failure state' do
        expect(client).not_to receive(:submit_pain_file)
        expect(submit_it).to eq({
                                  'final' => true,
                                  'success' => false,
                                  'data' => { 'SEPA builder error' => '#<ArgumentError: Iban nope is invalid>' }
                                })
      end
    end

    describe 'api error handling' do
      let(:error_message) { 'Whooops' }

      shared_examples_for 'api error handler' do
        it 'returns error info and failed status' do
          expect(client).to receive(:submit_pain_file)
            .with(expected_generated_xml)
            .and_raise(error_class.new(error_message))
          expect(submit_it).to eq({
                                    'final' => true,
                                    'success' => false,
                                    'data' => {
                                      'error_class' => error_class.name,
                                      'message' => error_message
                                    }
                                  })
        end
      end

      context 'when client throws Konfipay::Client::Unauthorized' do
        let(:error_class) { Konfipay::Client::Unauthorized }

        it_behaves_like 'api error handler'
      end

      context 'when client throws Konfipay::Client::BadRequest' do
        let(:error_class) { Konfipay::Client::BadRequest }

        it_behaves_like 'api error handler'
      end
    end
  end
end
# rubocop:enable RSpec/MessageSpies
# rubocop:enable RSpec/StubbedMock
# rubocop:enable RSpec/MultipleExpectations
