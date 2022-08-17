# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Konfipay::Jobs::InitializeCreditTransfer do
  describe 'perform' do
    let(:do_it) do
      described_class.new.perform(
        'ExampleCallbackClass',
        'example_callback_fetch_statements',
        payment_data,
        transaction_id
      )
    end

    let(:transaction_id) { '123xyz' }
    let(:r_id) { 'xxxxxxxxx' }
    let(:payment_data) { { 'bla' => 'blub' } }
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
    let(:operation) { Konfipay::Operations::InitializeCreditTransfer.new }

    before do
      allow(Konfipay::Operations::InitializeCreditTransfer).to receive(:new).and_return(operation)
      allow(operation).to receive(:submit).with(
        payment_data,
        transaction_id
      ).and_return(data)
      allow(ExampleCallbackClass).to receive(:example_callback_fetch_statements)
      allow(Konfipay::Jobs::MonitorCreditTransfer).to receive(:perform_in)
    end

    it 'calls the operation' do
      do_it
      expect(operation).to have_received(:submit)
    end

    it 'runs the callback' do
      do_it
      expect(ExampleCallbackClass).to have_received(:example_callback_fetch_statements).with(data, transaction_id)
    end

    context 'when operation is done' do
      let(:final) { true }

      it 'does not schedule a monitoring job' do
        do_it
        expect(Konfipay::Jobs::MonitorCreditTransfer).not_to have_received(:perform_in)
      end
    end

    context 'when operation is still ongoing' do
      let(:final) { false }

      it 'schedules a monitoring job' do
        do_it
        expect(Konfipay::Jobs::MonitorCreditTransfer).to have_received(:perform_in).with(
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
