# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Konfipay::Jobs::InitializeTransfer do
  before do
    Konfipay.configure do |config|
      config.api_keys = {
        'default' => '1',
        'other' => '2'
      }
    end
  end

  after do
    Konfipay::Configuration.initializer_block = nil
  end

  describe 'perform' do
    let(:do_it) do
      described_class.new.perform(
        'ExampleCallbackClass',
        'example_callback_fetch_statements',
        'credit_transfer',
        redis_key,
        transaction_id,
        { 'api_key_name' => 'other' }
      )
    end

    let(:transaction_id) { '123xyz' }
    let(:r_id) { 'xxxxxxxxx' }
    let(:redis_key) { 'konfipay/data/123xyz' }
    let(:payment_data) { { 'bla' => 'blub' } }
    let(:payment_data_json) { '{"bla":"blub"}' }
    let(:final) { true }
    let(:data) do
      {
        'success' => true,
        'final' => final,
        'data' => {
          'rId' => r_id,
          'other' => 'junk'
        }
      }
    end
    let(:operation) { Konfipay::Operations::InitializeTransfer.new }

    before do
      allow(Konfipay).to receive(:configuration).and_call_original
      allow(sidekiq_redis_connection_double).to receive(:call).with('GETDEL', redis_key).and_return(payment_data_json)
      allow(Konfipay::Operations::InitializeTransfer).to receive(:new).and_return(operation)
      allow(operation).to receive(:submit).with(
        'credit_transfer',
        payment_data,
        transaction_id
      ).and_return(data)
      allow(ExampleCallbackClass).to receive(:example_callback_fetch_statements)
      allow(Konfipay::Jobs::MonitorTransfer).to receive(:perform_in)
    end

    it 'calls the operation' do
      do_it
      expect(operation).to have_received(:submit)
    end

    it 'instantiates a new config' do
      do_it
      expect(Konfipay::Operations::InitializeTransfer).to have_received(:new).with(a_kind_of(Konfipay::Configuration))
    end

    it 'passes the config the config options' do
      do_it
      expect(Konfipay).to have_received(:configuration).with(api_key_name: 'other')
    end

    it 'runs the callback' do
      do_it
      expect(ExampleCallbackClass).to have_received(:example_callback_fetch_statements).with(data, transaction_id)
    end

    context 'when operation is done' do
      let(:final) { true }

      it 'does not schedule a monitoring job' do
        do_it
        expect(Konfipay::Jobs::MonitorTransfer).not_to have_received(:perform_in)
      end
    end

    context 'when operation is still ongoing' do
      let(:final) { false }

      it 'schedules a monitoring job' do
        do_it
        expect(Konfipay::Jobs::MonitorTransfer).to have_received(:perform_in).with(
          600,
          'ExampleCallbackClass',
          'example_callback_fetch_statements',
          r_id,
          transaction_id,
          { 'api_key_name' => 'other' }
        )
      end
    end

    context 'when payment_data is somehow missing' do
      it 'throws an exception' do
        allow(sidekiq_redis_connection_double).to receive(:call).and_return(nil)
        expect { do_it }.to raise_error('Could not get payment data from redis at "konfipay/data/123xyz"!')
      end
    end
  end
end
