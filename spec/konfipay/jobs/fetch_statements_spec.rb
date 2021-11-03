# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Konfipay::Jobs::FetchStatements do
  describe 'perform' do
    let(:do_it) do
      described_class.new.perform(
        'ExampleCallbackClass',
        'example_callback_fetch_statements',
        'new',
        { 'bla' => 'blub' },
        { 'ladi' => 'da' }
      )
    end

    let(:data) { 'le_data' }
    let(:operation) { Konfipay::Operations::FetchStatements.new }

    before do
      allow(Konfipay::Operations::FetchStatements).to receive(:new).and_return(operation)
      allow(operation).to receive(:fetch).with(
        'new',
        { 'bla' => 'blub' },
        { 'ladi' => 'da' }
      ).and_return(data)
    end

    it 'just calls the operation and runs the callback with the result' do
      expect(do_it).to eq([:example_callback_fetch_statements, data])
    end
  end
end
