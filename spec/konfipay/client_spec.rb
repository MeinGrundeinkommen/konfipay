# frozen_string_literal: true

require 'spec_helper'
RSpec.describe Konfipay::Client do
  let(:api_key) { "le key d'api" }

  let(:config) do
    Konfipay.configure do |c|
      c.api_key = api_key
      # Uncomment this for debug output from http gem during specs
      # c.logger = Logger.new($stdout)
    end
  end

  let(:client) do
    described_class.new(config)
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

  let(:access_token) { 'xyz123' }

  let(:response_is_json) do
    { 'Content-Type' => 'application/json; charset=UTF-8' }
  end

  let(:response_is_xml) do
    { 'Content-Type' => 'text/xml; charset=UTF-8' }
  end

  let(:response_is_auth_error) do
    {
      'Content-Type' => 'text/plain',
      'Www-Authenticate' => 'You shall not pass.'
    }
  end

  def stub_login_token_api_call!
    stub_request(:post, 'https://portal.konfipay.de/api/v5/Auth/Login/Token')
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
                 headers: response_is_json)
  end

  shared_examples 'api error handling' do |http_method|
    let(:generic_error_body) do
      {
        errorItems: [
          {
            errorCode: 'ERR-00-0000',
            errorMessage: 'ErrorMessage1',
            errorDetails: 'ErrorDetails1',
            timestamp: '2021-11-02T15:17:42+01:00'
          },
          {
            errorCode: 'ERR-11-1111',
            errorMessage: 'ErrorMessage2',
            errorDetails: 'ErrorDetails2',
            timestamp: '2021-11-02T15:17:42+01:00'
          }
        ]
      }
    end

    context 'when konfipay returns 400 error' do
      before do
        stub_login_token_api_call!
        stub_request(http_method, stubbed_url)
          .with(headers: request_headers)
          .to_return(status: 400,
                     body: generic_error_body.to_json,
                     headers: response_is_json)
      end

      it 'raises error message with details from api response' do
        expect { result }.to raise_error('400 Bad Request, messages: ErrorMessage1, ErrorMessage2')
      end
    end

    context 'when konfipay returns 401 error' do
      before do
        stub_login_token_api_call!
        stub_request(http_method, stubbed_url)
          .with(headers: request_headers)
          .to_return(status: 401,
                     body: nil,
                     headers: response_is_auth_error)
      end

      it 'raises Unauthorized error with message from header' do
        expect { result }.to raise_error(Konfipay::Client::Unauthorized, 'You shall not pass.')
      end
    end

    context 'when konfipay returns 403 error' do
      before do
        stub_login_token_api_call!
        stub_request(http_method, stubbed_url)
          .with(headers: request_headers)
          .to_return(status: 403,
                     body: generic_error_body.to_json,
                     headers: response_is_json)
      end

      it 'raises error message with details from api response' do
        expect { result }.to raise_error('403 Forbidden, messages: ErrorMessage1, ErrorMessage2')
      end
    end

    context 'when konfipay returns 404 error' do
      before do
        stub_login_token_api_call!
        stub_request(http_method, stubbed_url)
          .with(headers: request_headers)
          .to_return(status: 404,
                     body: {
                       Message: 'Welcome to konfipay. Blub blub',
                       ApiDocumentationLink: 'https://portal.konfipay.de/Info/Api_Doc'
                     }.to_json,
                     headers: response_is_json)
      end

      it 'raises error message with details from api response' do
        expect { result }.to raise_error('404 Not Found, message: "Welcome to konfipay. Blub blub"')
      end
    end
  end

  shared_examples_for 'no-content handling' do
    context 'when konfipay returns no content' do
      before do
        stub_login_token_api_call!
        stub_request(:get, stubbed_url)
          .with(headers: request_headers)
          .to_return(status: 204)
      end

      it 'returns nil' do
        expect(result).to be_nil
      end
    end
  end

  shared_examples_for 'documentItems response parsing' do
    let(:expected_parsed_json) do
      { 'documentItems' =>
        [{ 'rId' => '5c19b66h-3d6e-4e8a-4548-622bd50a7af2',
           'href' => 'api/v5.0/Document/Camt/5c19b66h-3d6e-4e8a-4548-622bd50a7af2',
           'timestamp' => '2021-10-28T23:21:59+02:00',
           'iban' => 'DE02300606010002474689',
           'isNew' => true,
           'format' => 'camt.053',
           'fileName' => '2021-10-28_C53_DE02300606010002474689_EUR_365352.xml' }] }
    end

    shared_examples_for 'success' do
      it 'returns list of new documents' do
        expect(result).to eq(expected_parsed_json)
      end
    end

    context 'when konfipay returns first 401, then success' do
      before do
        stub_login_token_api_call!
        stub_request(:get, stubbed_url)
          .with(headers: request_headers)
          .to_return(status: 401,
                     body: nil,
                     headers: response_is_auth_error)
          .then
          .to_return(status: 200,
                     body: expected_parsed_json.to_json,
                     headers: response_is_json)
      end

      it_behaves_like 'success'
    end

    context 'when konfipay returns success' do
      before do
        stub_login_token_api_call!
        stub_request(:get, stubbed_url)
          .with(headers: request_headers)
          .to_return(status: 200,
                     body: expected_parsed_json.to_json,
                     headers: response_is_json)
      end

      it_behaves_like 'success'
    end
  end

  describe 'new_statements' do
    let(:stubbed_url) { 'https://portal.konfipay.de/api/v5/Document/Camt' }
    let(:result) { client.new_statements }

    it_behaves_like 'api error handling', :get
    it_behaves_like 'no-content handling'
    it_behaves_like 'documentItems response parsing'
  end

  describe 'statement_history' do
    let(:stubbed_url) { 'https://portal.konfipay.de/api/v5/Document/Camt/History' }
    let(:result) { client.statement_history }

    it_behaves_like 'api error handling', :get
    it_behaves_like 'no-content handling'
    it_behaves_like 'documentItems response parsing'
  end

  describe 'camt_file' do
    let(:r_id) { 'a-b-c' }
    let(:stubbed_url) { "https://portal.konfipay.de/api/v5/Document/Camt/#{r_id}" }
    let(:result) { client.camt_file(r_id) }

    let(:camt_xml) { File.read('spec/examples/camt053/mixed_examples.xml') }

    it_behaves_like 'api error handling', :get

    shared_examples_for 'success' do
      it 'returns a parsed camt file' do
        expect(result).to be_an_instance_of(CamtParser::Format053::Base)
      end
    end

    context 'when konfipay first returns 401, then success' do
      before do
        stub_login_token_api_call!
        stub_request(:get, stubbed_url)
          .with(headers: request_headers)
          .to_return(status: 401,
                     body: nil,
                     headers: response_is_auth_error)
          .then
          .to_return(status: 200,
                     body: camt_xml,
                     headers: response_is_xml)
      end

      it_behaves_like 'success'
    end

    context 'when konfipay returns success' do
      before do
        stub_login_token_api_call!
        stub_request(:get, stubbed_url)
          .with(headers: request_headers)
          .to_return(status: 200,
                     body: camt_xml,
                     headers: response_is_xml)
      end

      context 'without arguments' do
        it_behaves_like 'success'
      end

      context 'with mark_as_read = false' do
        let(:stubbed_url) { "https://portal.konfipay.de/api/v5/Document/Camt/#{r_id}?ack=false" }
        let(:result) { client.camt_file(r_id, false) }

        it_behaves_like 'success'
      end
    end
  end

  describe 'acknowledge_camt_file' do
    let(:r_id) { 'a-b-c' }
    let(:expected_parsed_json) do
      { 'rId' => r_id,
        'href' => "api/v5.0/Document/Camt/#{r_id}",
        'timestamp' => '2021-10-28T23:21:59+02:00',
        'iban' => 'DE02300606010002474689',
        'isNew' => false,
        'format' => 'camt.053',
        'fileName' => '2021-10-28_C53_DE02300606010002474689_EUR_365352.xml' }
    end
    let(:stubbed_url) { "https://portal.konfipay.de/api/v5/Document/Camt/#{r_id}/Acknowledge" }
    let(:result) { client.acknowledge_camt_file(r_id) }

    it_behaves_like 'api error handling', :post

    shared_examples_for 'success' do
      it 'returns parsed response' do
        expect(result).to eq(expected_parsed_json)
      end
    end

    context 'when konfipay returns first 401, then success' do
      before do
        stub_login_token_api_call!
        stub_request(:post, stubbed_url)
          .with(headers: request_headers)
          .to_return(status: 401,
                     body: nil,
                     headers: response_is_auth_error)
          .then
          .to_return(status: 200,
                     body: expected_parsed_json.to_json,
                     headers: response_is_json)
      end

      it_behaves_like 'success'
    end

    context 'when konfipay returns success' do
      before do
        stub_login_token_api_call!
        stub_request(:post, stubbed_url)
          .with(headers: request_headers)
          .to_return(status: 200,
                     body: expected_parsed_json.to_json,
                     headers: response_is_json)
      end

      it_behaves_like 'success'
    end
  end
end
