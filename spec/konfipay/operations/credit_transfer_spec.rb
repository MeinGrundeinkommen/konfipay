# frozen_string_literal: true

require 'spec_helper'

# rubocop:disable RSpec/MessageSpies
# rubocop:disable RSpec/StubbedMock
# rubocop:disable RSpec/MultipleExpectations
RSpec.describe Konfipay::Operations::CreditTransfer do
  let(:config) { Konfipay.configuration }
  let(:client) do
    Konfipay::Client.new(config)
  end
  let(:operation) { described_class.new(config, client) }
  let(:r_id) { 'x-y-z' }
  let(:parsed_data_from_api) do
    {
      'rId' => r_id,
      'timestamp' => '2022-08-09T17:10:19+02:00',
      'type' => 'pain',
      'paymentStatusItem' => {
        'status' => 'FIN_ACCEPTED',
        'uploadTimestamp' => '2022-08-09T17:10:21+02:00',
        'orderID' => 'N9GB',
        'reasonCode' => 'DS07',
        'reason' => 'Alle den Auftrag betreffenden Aktionen konnten durch den Bankrechner durchgeführt werden',
        'additionalInformation' => '(big block of paper-printable info about the process)'
      }
    }
  end

  describe 'fetch' do
    let(:fetch_it) do
      operation.fetch(r_id)
    end

    it 'returns parsed data with success and final states' do
      expect(client).to receive(:pain_file_info).with(r_id).and_return(parsed_data_from_api)
      expect(fetch_it).to eq({
                               'final' => true,
                               'success' => true,
                               'data' => parsed_data_from_api
                             })
    end

    describe 'api error handling' do
      let(:error_message) { 'Whooops' }

      shared_examples_for 'api error handler' do
        it 'returns error info and failed status' do
          expect(client).to receive(:pain_file_info).with(r_id).and_raise(error_class.new(error_message))
          expect(fetch_it).to eq({
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
