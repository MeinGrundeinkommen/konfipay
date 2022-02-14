# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Konfipay::Configuration do
  context 'with default config' do
    [
      [:api_key, nil],
      [:logger, nil],
      [:timeout, 180],
      [:base_url, 'https://portal.konfipay.de'],
      [:api_client_name, 'Konfipay Ruby Client'],
      [:api_client_version, Konfipay::VERSION],
      [:credit_monitoring_interval, 36_000]
    ].each do |setting, value|
      it "defaults #{setting.inspect} to #{value.inspect}" do
        expect(Konfipay.configuration.send(setting)).to eq(value)
      end
    end
  end

  context 'with setting changed' do
    [
      [:api_key, 'aaaaaaaaaaaaaaaa'],
      [:logger, Logger.new($stdout)],
      [:timeout, 666],
      [:base_url, 'https://zombo.com'],
      [:api_client_name, 'die singende Herrentorte'],
      [:api_client_version, '12.11.10'],
      [:credit_monitoring_interval, 111_111]
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

  describe 'validating settings' do
    let(:configure) do
      Konfipay.configure do |config|
        config.api_key = 'has to be set by default'
        config.send("#{setting}=", value)
      end
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

    %i[timeout credit_monitoring_interval].each do |number_in_seconds|
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
