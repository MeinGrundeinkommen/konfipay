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

  context 'with runtime options provided' do
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
    shared_examples 'raising an ArgumentError' do
      it 'raises an ArgumentError' do
        expect { configure }.to raise_error(ArgumentError)
      end
    end

    context 'with initializer block provided' do
      let(:configure) do
        Konfipay.configure do |config|
          config.api_key = 'has to be set by default'
          config.send("#{setting}=", value)
        end
        Konfipay.configuration
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

      describe 'api_keys' do
        let(:setting) { :api_keys }

        context 'when api_key is already configured' do
          context 'when given correct hash' do
            let(:value) { { 'default' => '1', 'backups' => '2' } }

            it_behaves_like 'raising an ArgumentError'
          end
        end

        context 'when api_key is not configured' do
          let(:configure) do
            Konfipay.configure do |config|
              config.send("#{setting}=", value)
            end
            Konfipay.configuration
          end

          context 'when nil' do
            let(:value) { nil }

            it_behaves_like 'raising an ArgumentError'
          end

          context 'when empty hash' do
            let(:value) { {} }

            it_behaves_like 'raising an ArgumentError'
          end

          context 'when hash without default key name' do
            let(:value) { { 'backup' => '2' } }

            it_behaves_like 'raising an ArgumentError'
          end

          context 'when hash with symbol keys' do
            let(:value) { { 'default' => '1', :backups => '2' } }

            it_behaves_like 'raising an ArgumentError'
          end

          context 'when given only default' do
            let(:value) { { 'default' => '1' } }

            it_behaves_like 'raising an ArgumentError'
          end

          context 'when given correct hash' do
            let(:value) { { 'default' => '1', 'backups' => '2' } }

            it 'sets the value' do
              expect(configure.api_keys).to eq(value)
            end
          end
        end
      end
    end
  end

  context 'with options provided' do
    context 'when setting api_key_name' do
      context 'with configured api_keys' do
        before do
          Konfipay.configure do |config|
            config.api_keys = {
              'default' => '1',
              'backup' => '2'
            }
          end
        end

        context 'when selecting a correct key' do
          it 'returns it with api_key' do
            config = Konfipay.configuration(api_key_name: 'backup')
            expect(config.api_key).to eq('2')
          end
        end

        context 'when selecting the default key' do
          it 'returns it with api_key' do
            config = Konfipay.configuration(api_key_name: 'default')
            expect(config.api_key).to eq('1')
          end
        end

        context 'when selecting no key' do
          it 'returns default api_key' do
            config = Konfipay.configuration
            expect(config.api_key).to eq('1')
          end
        end

        context 'when selecting a nil key' do
          it 'returns default api_key' do
            config = Konfipay.configuration(api_key_name: nil)
            expect(config.api_key).to eq('1')
          end
        end

        context 'when selecting a nonexisting key' do
          it 'returns default api_key' do
            expect do
              Konfipay.configuration(api_key_name: 'bollocks')
            end.to raise_error(ArgumentError)
          end
        end
      end

      context 'without configured api_keys' do
        before do
          Konfipay.configure do |config|
            config.api_key = 'lala'
          end
        end

        context 'when selecting any key' do
          it 'throws an error' do
            expect do
              Konfipay.configuration(api_key_name: 'bollocks')
            end.to raise_error(ArgumentError)
          end
        end

        context 'when selecting no key' do
          it 'returns api_key' do
            config = Konfipay.configuration
            expect(config.api_key).to eq('lala')
          end
        end

        context 'when selecting a nil key' do
          it 'returns api_key' do
            config = Konfipay.configuration(api_key_name: nil)
            expect(config.api_key).to eq('lala')
          end
        end
      end
    end
  end
end
