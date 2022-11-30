# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Konfipay do
  it 'has a version number' do
    expect(Konfipay::VERSION).not_to be_nil
  end

  describe 'class methods' do
    let(:callback_class) { 'ExampleCallbackClass' }
    let(:callback_method) { 'example_callback_class_method' }
    let(:queue) { nil }
    let(:iban) { 'DE02120300000000202051' }
    let(:payment_data) { { 'bla' => 'blub' } }
    let(:transaction_id) { '12345' }
    let(:sidekiq_options_dummy) { Class.new }

    describe 'new_statements' do
      subject { request_fetch }

      let(:request_fetch) do
        described_class.new_statements(callback_class, callback_method, queue, iban, mark_as_read)
      end

      let(:mark_as_read) { false }

      before do
        allow(sidekiq_options_dummy).to receive(:perform_async)
        allow(Konfipay::Jobs::FetchStatements).to receive(:set).and_return(sidekiq_options_dummy)
      end

      it { is_expected.to be(true) }

      context 'with passed-in arguments' do
        let(:queue) { :fast }

        it 'enqueues a job' do
          request_fetch
          expect(sidekiq_options_dummy).to have_received(:perform_async).with(
            callback_class,
            callback_method,
            'new',
            { 'iban' => iban },
            { 'mark_as_read' => mark_as_read }
          )
        end

        it 'uses the named queue' do
          request_fetch
          expect(Konfipay::Jobs::FetchStatements).to have_received(:set).with(queue: queue)
        end
      end

      context 'with default arguments' do
        let(:request_fetch) do
          described_class.new_statements(callback_class, callback_method)
        end

        it 'enqueues a job' do
          request_fetch
          expect(sidekiq_options_dummy).to have_received(:perform_async).with(
            callback_class,
            callback_method,
            'new',
            { 'iban' => nil },
            { 'mark_as_read' => true }
          )
        end

        it 'uses the default queue' do
          request_fetch
          expect(Konfipay::Jobs::FetchStatements).to have_received(:set).with(queue: :default)
        end
      end

      # TODO: check arguments are checked
    end

    describe 'statement_history' do
      subject { request_fetch }

      let(:request_fetch) do
        described_class.statement_history(callback_class, callback_method, queue, iban, from, to)
      end

      let(:from) { (Date.today - 100).iso8601 }
      let(:to) { (Date.today - 10).iso8601 }

      before do
        allow(sidekiq_options_dummy).to receive(:perform_async)
        allow(Konfipay::Jobs::FetchStatements).to receive(:set).and_return(sidekiq_options_dummy)
      end

      it { is_expected.to be(true) }

      context 'with passed-in arguments' do
        let(:queue) { :fast }

        it 'enqueues a job' do
          request_fetch
          expect(sidekiq_options_dummy).to have_received(:perform_async).with(
            callback_class,
            callback_method,
            'history',
            { 'from' => from, 'iban' => iban, 'to' => to },
            {}
          )
        end

        it 'uses the named queue' do
          request_fetch
          expect(Konfipay::Jobs::FetchStatements).to have_received(:set).with(queue: queue)
        end
      end

      context 'with default arguments' do
        let(:request_fetch) do
          described_class.statement_history(callback_class, callback_method)
        end

        it 'enqueues a job' do
          request_fetch
          expect(sidekiq_options_dummy).to have_received(:perform_async).with(
            callback_class,
            callback_method,
            'history',
            { 'from' => Date.today.iso8601, 'iban' => nil, 'to' => Date.today.iso8601 },
            {}
          )
        end

        it 'uses the default queue' do
          request_fetch
          expect(Konfipay::Jobs::FetchStatements).to have_received(:set).with(queue: :default)
        end
      end

      # TODO: check arguments are checked
    end

    describe 'initialize_credit_transfer' do
      subject { start_transfer }

      let(:start_transfer) do
        described_class.initialize_credit_transfer(callback_class, callback_method, queue, payment_data,
                                                   transaction_id, false)
      end

      before do
        allow(sidekiq_options_dummy).to receive(:perform_async)
        allow(Konfipay::Jobs::InitializeTransfer).to receive(:set).and_return(sidekiq_options_dummy)
      end

      it { is_expected.to be(true) }

      context 'with passed-in arguments' do
        let(:queue) { :fast }

        it 'enqueues a job' do
          start_transfer
          expect(sidekiq_options_dummy).to have_received(:perform_async).with(
            callback_class,
            callback_method,
            'credit_transfer',
            payment_data,
            transaction_id,
            false
          )
        end

        it 'uses the named queue' do
          start_transfer
          expect(Konfipay::Jobs::InitializeTransfer).to have_received(:set).with(queue: queue)
        end
      end

      context 'with default arguments' do
        let(:start_transfer) do
          described_class.initialize_credit_transfer(callback_class, callback_method, nil, payment_data,
                                                     transaction_id, false)
        end

        it 'uses the default queue' do
          start_transfer
          expect(Konfipay::Jobs::InitializeTransfer).to have_received(:set).with(queue: :default)
        end
      end

      # TODO: check arguments are checked
    end

    describe 'initialize_direct_debit' do
      subject { start_debit }

      let(:start_debit) do
        described_class.initialize_direct_debit(callback_class, callback_method, queue, payment_data, transaction_id)
      end

      before do
        allow(sidekiq_options_dummy).to receive(:perform_async)
        allow(Konfipay::Jobs::InitializeTransfer).to receive(:set).and_return(sidekiq_options_dummy)
      end

      it { is_expected.to be(true) }

      context 'with passed-in arguments' do
        let(:queue) { :fast }

        it 'enqueues a job' do
          start_debit
          expect(sidekiq_options_dummy).to have_received(:perform_async).with(
            callback_class,
            callback_method,
            'direct_debit',
            payment_data,
            transaction_id,
            false
          )
        end

        it 'uses the named queue' do
          start_debit
          expect(Konfipay::Jobs::InitializeTransfer).to have_received(:set).with(queue: queue)
        end
      end

      context 'with default arguments' do
        let(:start_debit) do
          described_class.initialize_direct_debit(callback_class, callback_method, nil, payment_data, transaction_id)
        end

        it 'uses the default queue' do
          start_debit
          expect(Konfipay::Jobs::InitializeTransfer).to have_received(:set).with(queue: :default)
        end
      end

      # TODO: check arguments are checked
    end
  end
end
