# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Konfipay do
  it 'has a version number' do
    expect(Konfipay::VERSION).not_to be nil
  end

  describe 'class methods' do
    let(:callback_class) { 'ExampleCallbackClass' }
    let(:callback_method) { 'example_callback_class_method' }
    let(:iban) { 'DE02120300000000202051' }

    describe 'new_statements' do
      subject { request_fetch }

      let(:request_fetch) do
        described_class.new_statements(callback_class, callback_method, iban, mark_as_read)
      end
      let(:mark_as_read) { false }

      before do
        allow(Konfipay::Jobs::FetchStatements).to receive(:perform_async)
      end

      it { is_expected.to eq(true) }

      it 'enqueues a job with passed-in arguments' do
        request_fetch
        expect(Konfipay::Jobs::FetchStatements).to have_received(:perform_async).with(
          callback_class,
          callback_method,
          'new',
          { 'iban' => iban },
          { 'mark_as_read' => mark_as_read }
        )
      end

      it 'enqueues a job with default arguments' do
        described_class.new_statements(callback_class, callback_method)
        expect(Konfipay::Jobs::FetchStatements).to have_received(:perform_async).with(
          callback_class,
          callback_method,
          'new',
          { 'iban' => nil },
          { 'mark_as_read' => true }
        )
      end

      # TODO: check arguments are checked
    end

    describe 'statement_history' do
      subject { request_fetch }

      let(:request_fetch) do
        described_class.statement_history(callback_class, callback_method, iban, from, to)
      end
      let(:from) { (Date.today - 100).iso8601 }
      let(:to) { (Date.today - 10).iso8601 }

      before do
        allow(Konfipay::Jobs::FetchStatements).to receive(:perform_async)
      end

      it { is_expected.to eq(true) }

      it 'enqueues a job with passed-in arguments' do
        request_fetch
        expect(Konfipay::Jobs::FetchStatements).to have_received(:perform_async).with(
          callback_class,
          callback_method,
          'history',
          { 'from' => from, 'iban' => iban, 'to' => to },
          {}
        )
      end

      it 'enqueues a job with default arguments' do
        described_class.statement_history(callback_class, callback_method)
        expect(Konfipay::Jobs::FetchStatements).to have_received(:perform_async).with(
          callback_class,
          callback_method,
          'history',
          { 'from' => Date.today.iso8601, 'iban' => nil, 'to' => Date.today.iso8601 },
          {}
        )
      end

      # TODO: check arguments are checked
    end
    # xit 'initialize_credit_transfer'
    # xit 'initialize_direct_debit'
  end
end
