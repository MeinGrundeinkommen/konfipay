# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Konfipay::Jobs::MonitorTransfer do
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
        r_id,
        transaction_id,
        { 'api_key_name' => 'other' }
      )
    end

    let(:transaction_id) { '123xyz' }
    let(:r_id) { 'xxxxxxxxx' }
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
    let(:operation) { Konfipay::Operations::TransferInfo.new }

    before do
      allow(Konfipay).to receive(:configuration).and_call_original
      allow(Konfipay::Operations::TransferInfo).to receive(:new).and_return(operation)
      allow(operation).to receive(:fetch).with(r_id).and_return(data)
      allow(ExampleCallbackClass).to receive(:example_callback_fetch_statements)
      allow(described_class).to receive(:perform_in)
    end

    it 'calls the operation' do
      do_it
      expect(operation).to have_received(:fetch)
    end

    it 'instantiates a new config' do
      do_it
      expect(Konfipay::Operations::TransferInfo).to have_received(:new).with(a_kind_of(Konfipay::Configuration))
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
        expect(described_class).not_to have_received(:perform_in)
      end
    end

    context 'when operation is still ongoing' do
      let(:final) { false }

      it 'schedules a monitoring job' do
        do_it
        expect(described_class).to have_received(:perform_in).with(
          600,
          'ExampleCallbackClass',
          'example_callback_fetch_statements',
          r_id,
          transaction_id,
          { 'api_key_name' => 'other' }
        )
      end
    end
  end
end
