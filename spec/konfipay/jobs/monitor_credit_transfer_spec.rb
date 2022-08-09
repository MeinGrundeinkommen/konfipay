# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Konfipay::Jobs::MonitorCreditTransfer do
  describe 'perform' do
    let(:do_it) do
      described_class.new.perform(
        'ExampleCallbackClass',
        'example_callback_fetch_statements',
        r_id,
        transaction_id
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
    let(:operation) { Konfipay::Operations::CreditTransfer.new }

    before do
      allow(Konfipay::Operations::CreditTransfer).to receive(:new).and_return(operation)
      allow(operation).to receive(:fetch).with(r_id).and_return(data)
      allow(ExampleCallbackClass).to receive(:example_callback_fetch_statements)
      allow(described_class).to receive(:perform_in)
    end

    it 'calls the operation' do
      do_it
      expect(operation).to have_received(:fetch)
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
          transaction_id
        )
      end
    end
  end
end
