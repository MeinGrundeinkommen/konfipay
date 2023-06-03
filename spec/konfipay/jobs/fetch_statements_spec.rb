# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Konfipay::Jobs::FetchStatements do
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
        'new',
        { 'bla' => 'blub' },
        { 'ladi' => 'da' },
        { 'api_key_name' => 'other' }
      )
    end

    let(:data) { 'le_data' }
    let(:operation) { Konfipay::Operations::FetchStatements.new }

    before do
      allow(Konfipay).to receive(:configuration).and_call_original
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

    it 'instantiates a new config' do
      do_it
      expect(Konfipay::Operations::FetchStatements).to have_received(:new).with(a_kind_of(Konfipay::Configuration))
    end

    it 'passes the config the config options' do
      do_it
      expect(Konfipay).to have_received(:configuration).with(api_key_name: 'other')
    end
  end
end
