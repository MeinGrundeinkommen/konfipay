# frozen_string_literal: true

require 'spec_helper'
# rubocop:disable Metrics/BlockLength
# rubocop:disable Metrics/MethodLength
# rubocop:disable RSpec/MultipleMemoizedHelpers
# rubocop:disable RSpec/NestedGroups
RSpec.describe Konfipay::Client do
  let(:api_key) { "le key d'api" }
  let(:access_token) { 'xyz123' }

  let!(:config) do
    Konfipay.configure do |c|
      c.api_key = api_key
      # Uncomment this for debug output from http gem during specs
      # c.logger = Logger.new($stdout)
    end
  end

  let(:request_headers) do
    {
      'Accept' => 'application/json',
      'Authorization' => "Bearer #{access_token}",
      'Connection' => 'close',
      'Host' => 'portal.konfipay.de',
      'User-Agent' => 'http.rb/5.0.4'
    }
  end

  def stub_login_token_api_call!
    stub_request(:post, 'https://portal.konfipay.de/api/v4/Auth/Login/Token')
      .with(
        body: {
          apiKey: api_key,
          client: {
            name: config.api_client_name,
            version: config.api_client_version
          }
        }.to_json,
        headers: {
          'Accept' => 'application/json',
          'Connection' => 'close',
          'Content-Type' => 'application/json; charset=UTF-8',
          'Host' => 'portal.konfipay.de',
          'User-Agent' => 'http.rb/5.0.4'
        }
      )
      .to_return(status: 200,
                 body: {
                   accessToken: access_token,
                   expiresIn: 1800,
                   tokenType: 'bearer'
                 }.to_json,
                 headers: { 'Content-Type' => 'application/json; charset=UTF-8' })
  end

  describe 'new_statements' do
    let(:stubbed_url) { 'https://portal.konfipay.de/api/v4/Document/Camt' }
    let(:result) { described_class.new.new_statements }

    context 'when konfipay returns no content' do
      before do
        stub_login_token_api_call!
        stub_request(:get, stubbed_url)
          .with(headers: request_headers)
          .to_return(status: 204)
      end

      it 'returns nil' do
        expect(result).to eq(nil)
      end
    end

    context 'when konfipay returns success' do
      let(:expected_parsed_json) do
        { 'documentItems' =>
          [{ 'rId' => '5c19b66h-3d6e-4e8a-4548-622bd50a7af2',
             'href' => 'api/v4.0/Document/Camt/5c19b66h-3d6e-4e8a-4548-622bd50a7af2',
             'timestamp' => '2021-10-28T23:21:59+02:00',
             'iban' => 'DE02300606010002474689',
             'isNew' => true,
             'format' => 'camt.053',
             'fileName' => '2021-10-28_C53_DE02300606010002474689_EUR_365352.xml' }] }
      end

      before do
        stub_login_token_api_call!
        stub_request(:get, stubbed_url)
          .with(headers: request_headers)
          .to_return(status: 200,
                     body: {
                       documentItems: [
                         {
                           rId: '5c19b66h-3d6e-4e8a-4548-622bd50a7af2',
                           href: 'api/v4.0/Document/Camt/5c19b66h-3d6e-4e8a-4548-622bd50a7af2',
                           timestamp: '2021-10-28T23:21:59+02:00',
                           iban: 'DE02300606010002474689',
                           isNew: true,
                           format: 'camt.053',
                           fileName: '2021-10-28_C53_DE02300606010002474689_EUR_365352.xml'
                         }
                       ]
                     }.to_json,
                     headers: { 'Content-Type' => 'application/json; charset=UTF-8' })
      end

      context 'without arguments' do
        it 'returns list of new documents' do
          expect(result).to eq(expected_parsed_json)
        end
      end

      context 'with iban filter argument' do
        let(:stubbed_url) { 'https://portal.konfipay.de/api/v4/Document/Camt?iban=an%20iban%20maybe' }
        let(:result) { described_class.new.new_statements('iban' => 'an iban maybe') }

        it 'returns list of new documents' do
          expect(result).to eq(expected_parsed_json)
        end
      end
    end
  end

  describe 'camt_file' do
  end
end
# rubocop:enable Metrics/BlockLength
# rubocop:enable Metrics/MethodLength
# rubocop:enable RSpec/MultipleMemoizedHelpers
# rubocop:enable RSpec/NestedGroups
