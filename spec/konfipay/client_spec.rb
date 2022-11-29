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

  let(:request_user_agent) { "http.rb/#{HTTP::VERSION}" }

  let(:request_headers) do
    {
      'Accept' => 'application/json',
      'Authorization' => "Bearer #{access_token}",
      'Connection' => 'close',
      'Host' => 'portal.konfipay.de',
      'User-Agent' => request_user_agent
    }
  end

  # i.e. an API request that sends XML needs the correct content type header
  let(:xml_request_headers) do
    request_headers.merge({
                            'Content-Type' => 'application/xml'
                          })
  end

  let(:access_token) { 'xyz123' }

  let(:content_type_json) do
    { 'Content-Type' => 'application/json; charset=UTF-8' }
  end

  let(:content_type_xml) do
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
          'User-Agent' => request_user_agent
        }
      )
      .to_return(status: 200,
                 body: {
                   accessToken: access_token,
                   expiresIn: 1800,
                   tokenType: 'bearer'
                 }.to_json,
                 headers: content_type_json)
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

    let(:generic_xml_error_body) do
      <<-XML
      <ErrorItemContainer xmlns:i="http://www.w3.org/2001/XMLSchema-instance">
        <ErrorItems>
          <ErrorItem>
            <ErrorCode>ERR-00-0000</ErrorCode>
            <ErrorMessage>ErrorMessage1</ErrorMessage>
            <ErrorDetails>ErrorDetails1</ErrorDetails>
            <Timestamp>2022-05-17T17:02:19+02:00</Timestamp>
          </ErrorItem>
          <ErrorItem>
            <ErrorCode>ERR-11-1111</ErrorCode>
            <ErrorMessage>ErrorMessage2</ErrorMessage>
            <ErrorDetails>ErrorDetails2</ErrorDetails>
            <Timestamp>2022-05-17T17:02:19+02:00</Timestamp>
          </ErrorItem>
        </ErrorItems>
      </ErrorItemContainer>
      XML
    end

    context 'when konfipay returns 400 error' do
      before do
        stub_login_token_api_call!
        stub_request(http_method, stubbed_url)
          .with(headers: request_headers)
          .to_return(status: 400,
                     body: generic_error_body.to_json,
                     headers: content_type_json)
      end

      it 'raises error message with details from api response' do
        expect { result }.to raise_error(Konfipay::Client::BadRequest, 'ErrorMessage1, ErrorMessage2')
      end
    end

    context 'when konfipay returns 400 error with xml instead of json as the error content type' do
      before do
        stub_login_token_api_call!
        stub_request(http_method, stubbed_url)
          .with(headers: request_headers)
          .to_return(status: 400,
                     body: generic_xml_error_body,
                     headers: content_type_xml)
      end

      it 'raises error message with details from api response' do
        expect { result }.to raise_error(Konfipay::Client::BadRequest, 'ErrorMessage1, ErrorMessage2')
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
                     headers: content_type_json)
      end

      it 'raises error message with details from api response' do
        expect { result }.to raise_error(Konfipay::Client::Forbidden, 'ErrorMessage1, ErrorMessage2')
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
                     headers: content_type_json)
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
                     headers: content_type_json)
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
                     headers: content_type_json)
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
                     headers: content_type_xml)
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
                     headers: content_type_xml)
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
                     headers: content_type_json)
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
                     headers: content_type_json)
      end

      it_behaves_like 'success'
    end
  end

  describe 'submit_pain_file' do
    let(:stubbed_url) { 'https://portal.konfipay.de/api/v5/Payment/Sepa/Pain' }
    let(:pain_xml) { File.read('spec/examples/pain.001.001.03/credit_transfer.xml') }
    let(:expected_parsed_json) do
      {
        'rId' => '491c7a47-6aec-47b2-b3ef-488d2ca7f4d4',
        'timestamp' => '2022-08-09T16:53:37+02:00',
        'type' => 'pain',
        'paymentStatusItem' => { 'status' => 'FIN_UPLOAD_SUCCEEDED',
                                 'uploadTimestamp' => '2022-08-09T16:53:43+02:00',
                                 'orderID' => 'N9G8' }
      }
    end
    let(:result) { client.submit_pain_file(pain_xml) }

    it_behaves_like 'api error handling', :post

    shared_examples_for 'success' do
      it 'returns parsed response' do
        expect(result).to eq(expected_parsed_json)
      end
    end

    context 'when konfipay returns success' do
      before do
        stub_login_token_api_call!
        stub_request(:post, stubbed_url)
          .with(headers: xml_request_headers)
          .to_return(status: 201,
                     body: expected_parsed_json.to_json,
                     headers: content_type_json)
      end

      it_behaves_like 'success'
    end

    context 'when konfipay returns first 401, then success' do
      before do
        stub_login_token_api_call!
        stub_request(:post, stubbed_url)
          .with(headers: xml_request_headers)
          .to_return(status: 401,
                     body: nil,
                     headers: response_is_auth_error)
          .then
          .to_return(status: 201,
                     body: expected_parsed_json.to_json,
                     headers: content_type_json)
      end

      it_behaves_like 'success'
    end
  end

  describe 'pain_file_info' do
    let(:r_id) { 'a-b-c' }
    let(:expected_parsed_json) do
      {
        'rId' => r_id,
        'timestamp' => '2022-08-09T17:10:19+02:00',
        'type' => 'pain',
        'paymentStatusItem' => {
          'status' => 'FIN_ACCEPTED',
          'uploadTimestamp' => '2022-08-09T17:10:21+02:00',
          'orderID' => 'N9GB',
          'reasonCode' => 'DS07',
          'reason' => 'Alle den Auftrag betreffenden Aktionen konnten durch den Bankrechner durchgeführt werden',
          'additionalInformation' => '(big block of paper-printable info about the process)'
        }
      }
    end
    let(:stubbed_url) { "https://portal.konfipay.de/api/v5/Payment/Sepa/Pain/#{r_id}/item" }
    let(:result) { client.pain_file_info(r_id) }

    it_behaves_like 'api error handling', :get

    shared_examples_for 'success' do
      it 'returns parsed response' do
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
                     headers: content_type_json)
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
                     headers: content_type_json)
      end

      it_behaves_like 'success'
    end
  end
end
