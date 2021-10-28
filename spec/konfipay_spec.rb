# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Konfipay do
  it 'has a version number' do
    expect(Konfipay::VERSION).not_to be nil
  end

  describe 'class methods' do
    let(:callback_class) { 'ExampleCallbackClass' }
    let(:callback_method) { 'example_callback_class_method' }

    describe 'new_statements' do
      subject do
        described_class.new_statements(callback_class, callback_method, iban, mark_as_read)
      end

      let(:iban) { nil }
      let(:mark_as_read) { nil }

      it 'enqueues a job with passed-in arguments' do
        expect(Konfipay::Jobs::FetchStatements).to receive(:perform_async).with(
          callback_class,
          callback_method,
          'new',
          { 'iban' => iban },
          { 'mark_as_read' => mark_as_read }
        )
        subject
      end

      it { is_expected.to eq(true) }

      # TODO: check arguments are checked
      # TODO: check without arguments (errors for needed, defaults)
    end

    xit 'initialize_credit_transfer'
    xit 'initialize_direct_debit'
  end
end
