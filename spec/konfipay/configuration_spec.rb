# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Konfipay::Configuration do
  after do
    described_class.initializer_block = nil
  end

  context 'with gem defaults' do
    let(:config) { Konfipay.configuration(api_key: '<key>') }

    [
      [:api_key, '<key>'],
      [:logger, nil],
      [:timeout, 600],
      [:base_url, 'https://portal.konfipay.de'],
      [:api_client_name, 'Konfipay Ruby Client'],
      [:api_client_version, Konfipay::VERSION],
      [:transfer_monitoring_interval, 600]
    ].each do |setting, value|
      it "defaults #{setting.inspect} to #{value.inspect}" do
        expect(config.send(setting)).to eq(value)
      end
    end
  end

  context 'with initializer block provided' do
    [
      [:api_key, 'aaaaaaaaaaaaaaaa'],
      [:logger, Logger.new($stdout)],
      [:timeout, 666],
      [:base_url, 'https://zombo.com'],
      [:api_client_name, 'die singende Herrentorte'],
      [:api_client_version, '12.11.10'],
      [:transfer_monitoring_interval, 111_111]
    ].each do |setting, value|
      it "sets #{setting.inspect} to #{value.inspect}" do
        Konfipay.configure do |config|
          config.api_key = 'has to be set by default'
          config.send("#{setting}=", value)
        end
        expect(Konfipay.configuration.send(setting)).to eq(value)
      end
    end
  end

  context 'with options provided' do
    [
      [:api_key, 'maybe better not do this'],
      [:logger, Logger.new($stdout)],
      [:timeout, 123],
      [:base_url, 'https://very.de'],
      [:api_client_name, 'I was born in a water moon'],
      [:api_client_version, 'hunderttausend'],
      [:transfer_monitoring_interval, 1]
    ].each do |setting, value|
      it "sets #{setting.inspect} to #{value.inspect}" do
        Konfipay.configure do |config|
          config.api_key = 'has to be set by default'
        end
        expect(Konfipay.configuration(**{ setting => value }).send(setting)).to eq(value)
      end
    end
  end

  describe 'validating settings' do
    let(:configure) do
      Konfipay.configure do |config|
        config.api_key = 'has to be set by default'
        config.send("#{setting}=", value)
      end
      Konfipay.configuration
    end

    shared_examples 'raising an ArgumentError' do
      it 'raises an ArgumentError' do
        expect { configure }.to raise_error(ArgumentError)
      end
    end

    %i[api_key base_url api_client_name api_client_version].each do |string|
      context string.to_s do
        let(:setting) { string }

        context 'when nil' do
          let(:value) { nil }

          it_behaves_like 'raising an ArgumentError'
        end

        context 'when empty' do
          let(:value) { '' }

          it_behaves_like 'raising an ArgumentError'
        end
      end
    end

    describe 'logger' do
      let(:setting) { :logger }

      context 'when not a logger' do
        let(:value) { 'imaloggeryiss' }

        it_behaves_like 'raising an ArgumentError'
      end
    end

    %i[timeout transfer_monitoring_interval].each do |number_in_seconds|
      describe number_in_seconds.to_s do
        let(:setting) { number_in_seconds }

        context 'when nil' do
          let(:value) { nil }

          it_behaves_like 'raising an ArgumentError'
        end

        context 'when not a number' do
          let(:value) { 'twelve' }

          it_behaves_like 'raising an ArgumentError'
        end

        context 'when zero' do
          let(:value) { 0 }

          it_behaves_like 'raising an ArgumentError'
        end

        context 'when negative' do
          let(:value) { -1 }

          it_behaves_like 'raising an ArgumentError'
        end
      end
    end
  end
end
