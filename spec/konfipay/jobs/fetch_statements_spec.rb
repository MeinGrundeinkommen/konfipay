# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Konfipay::Jobs::FetchStatements do
  describe 'perform' do
    let(:do_it) do
      described_class.new(config).perform(
        'ExampleCallbackClass',
        'example_callback_fetch_statements',
        'new',
        { 'bla' => 'blub' },
        { 'ladi' => 'da' }
      )
    end

    let(:data) { 'le_data' }
    let(:config) { Konfipay.configuration(api_key: '<key>') }
    let(:operation) { Konfipay::Operations::FetchStatements.new(config) }

    before do
      allow(Konfipay::Operations::FetchStatements).to receive(:new).and_return(operation)
      allow(operation).to receive(:fetch).with(
        'new',
        { 'bla' => 'blub' },
        { 'ladi' => 'da' }
      ).and_return(data)
      allow(ExampleCallbackClass).to receive(:example_callback_fetch_statements)
    end

    it 'calls the operation' do
      do_it
      expect(operation).to have_received(:fetch)
    end
  end
end
