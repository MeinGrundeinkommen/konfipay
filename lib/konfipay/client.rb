# frozen_string_literal: true

module Konfipay
  # API Client for the Konfipay API (see https://portal.konfipay.de/api-docs/index.html)
  # Only selected API Endpoints are implemented.
  # Authentication is done automatically, and the auth token is cached in an instance of this class.
  class Client
    class Error < StandardError; end
    class Unauthorized < Error; end

    def initialize(config = Konfipay.configuration)
      @config = config
      @bearer_token = nil
    end

    def logger
      @config.logger
    end

    # Get a bearer token to use in subsequent requests from the same client instance.
    # This will be called automatically by other methods on this class, no need to use it directly.
    # Uses https://portal.konfipay.de/api-docs/index.html#tag/Auth/paths/~1api~1v5~1Auth~1Login~1Token/post
    def authenticate
      response = http.post(authentication_url(@config), authentication_params(@config))
      json = raise_error_or_parse!(response)
      @bearer_token = json['accessToken']
      raise "Couldn't get a bearer token in #{json.inspect}! What now?" unless @bearer_token.present?

      @bearer_token
    end

    def authentication_url(config)
      "#{config.base_url}/api/v5/Auth/Login/Token"
    end

    def authentication_params(config)
      {
        json: {
          apiKey: config.api_key,
          client: {
            name: config.api_client_name,
            version: config.api_client_version
          }
        }
      }
    end

    # Get "new" statements from Konfipay API from this endpoint:
    # https://portal.konfipay.de/api-docs/index.html#tag/Document-Camt/paths/~1api~1v5~1Document~1Camt/get
    # Returns the parsed JSON as Ruby objects, or nil if there are no (new) documents:
    #
    # {"documentItems"=>
    #  [{"rId"=>"5c19b66h-3d6e-4e8a-4548-622bd50a7af2",
    #    "href"=>"api/v4.0/Document/Camt/5c19b66h-3d6e-4e8a-4548-622bd50a7af2",
    #    "timestamp"=>"2021-10-28T23:21:59+02:00",
    #    "iban"=>"DE02300606010002474689",
    #    "isNew"=>true,
    #    "format"=>"camt.053",
    #    "fileName"=>"2021-10-28_C53_DE02300606010002474689_EUR_365352.xml"}
    # ]}
    #
    # Pass in a params hash, it will be turned into query params, for example for iban filtering:
    # { "iban" => "DE02300606010002474689" }
    #
    # Can raise various network errors.
    def new_statements(params = {})
      with_auth_retry do
        response = authed_http.get(new_statements_url(@config, params))
        raise_error_or_parse!(response)
      end
    end

    def new_statements_url(config, params)
      "#{config.base_url}/api/v5/Document/Camt#{query_params(params)}"
    end

    # Get "history" statements from Konfipay API from this endpoint:
    # https://portal.konfipay.de/api-docs/index.html#tag/Document-Camt/paths/~1api~1v5~1Document~1Camt~1History/get
    #
    # Same return format as #new_statements
    #
    # Pass in a params hash, it will be turned into query params.
    #
    # You will always need "start" and "end" as date strings in format
    # "yyyy-MM-dd", i.e. ISO 8601.
    #
    # Optonally an IBAN to filter by.
    #
    # {
    #   "iban"  => "DE02300606010002474689",
    #   "start" => "1999-12-31",
    #   "end"   => "3000-01-01"
    # }
    #
    # Can raise various network errors.
    def statement_history(params = {})
      with_auth_retry do
        response = authed_http.get(statement_history_url(@config, params))
        raise_error_or_parse!(response)
      end
    end

    def statement_history_url(config, params)
      "#{config.base_url}/api/v5/Document/Camt/History#{query_params(params)}"
    end

    # Get and parse a single camt.053 document with given r_id from endpoint:
    # https://portal.konfipay.de/api-docs/index.html#tag/Document-Camt/paths/~1api~1v5~1Document~1Camt~1{rId}/get
    # If mark_as_read = false, will not mark the document as read, i.e. keep as "new".
    # Returns an instance of CamtParser::Format053::Base :
    # https://github.com/viafintech/camt_parser/blob/master/lib/camt_parser/053/base.rb
    # Can raise various network errors.
    def camt_file(r_id, mark_as_read = true) # rubocop:disable Style/OptionalBooleanParameter
      params = {}
      params['ack'] = 'false' unless mark_as_read
      with_auth_retry do
        response = authed_http.get(camt_file_url(@config, r_id, params))
        raise_error_or_parse!(response)
      end
    end

    def camt_file_url(config, r_id, params)
      "#{config.base_url}/api/v5/Document/Camt/#{r_id}#{query_params(params)}"
    end

    # Acknowledge a camt file, i.e. mark it as "read".
    # https://portal.konfipay.de/api-docs/index.html#tag/Document-Camt/paths/~1api~1v5~1Document~1Camt~1{rId}~1Acknowledge/post
    # Returns the same output as #new_statements, but with only one document.
    # Can raise various network errors.
    def acknowledge_camt_file(r_id)
      with_auth_retry do
        response = authed_http.post(acknowledge_camt_file_url(@config, r_id))
        raise_error_or_parse!(response)
      end
    end

    def acknowledge_camt_file_url(config, r_id)
      "#{config.base_url}/api/v5/Document/Camt/#{r_id}/Acknowledge"
    end

    def http
      http = HTTP.timeout(@config.timeout).headers(accept: 'application/json')
      # the api doesn't seem to support compression but it can't hurt to ask for it
      http = http.use(:auto_inflate).headers('Accept-Encoding' => 'deflate, gzip;q=1.0, *;q=0.5')
      http = http.use(logging: { logger: logger }) if logger
      http
    end

    def authed_http
      authenticate if @bearer_token.nil?
      raise 'Something went really wrong with the authentication!' if @bearer_token.nil?

      http.auth("Bearer #{@bearer_token}")
    end

    def with_auth_retry(retries = 1, &block)
      logger&.info("API call with #{retries} retries...")
      begin
        yield
      rescue Unauthorized => e
        if retries <= 0
          logger&.error('No retries left, raising error')
          raise e
        else
          logger&.error("#{e.class.name} error on retry #{retries}, retrying...")
          authenticate
          with_auth_retry(retries - 1, &block)
        end
      end
    end

    def query_params(params)
      if params.any?
        "?#{params.to_query}"
      else
        ''
      end
    end

    def raise_error_or_parse!(response)
      status = response.status
      case status
      when 200
        parse(response)
      when 204
        # "The request was processed successfully, but no data is available."
        nil
      when 401
        # 401 responses are text/plain, but without a body, some info is in the header:
        # usually just '"Bearer error=\"invalid_token\", error_description=\"The signature key was not found\""'
        message = response.headers['Www-Authenticate']
        logger&.error("Got 401 response: #{message.inspect}")
        raise Unauthorized, message
      when 400, 403
        # {"errorItems":[{"errorCode":"ERR-04-0009","errorMessage":"UnknownBankAccount",
        #  "timestamp":"2021-10-19T15:10:45.767"}]}
        errors = parse(response)['errorItems'].map { |e| e['errorMessage'] }.join(', ')
        raise "#{status}, messages: #{errors}"
      when 404
        # {"Message":"Welcome to konfipay. There is no API-Endpoint defined for
        #  'https://portal.konfipay.de/api/v4/Document/Camtiban=aaaa'. Please take a
        #  look at the konfipay API-Documentation for valid API-Endpoints",
        #  "ApiDocumentationLink":"https://portal.konfipay.de/Info/Api_Doc"}
        raise "#{status}, message: #{parse(response)['Message'].inspect}"
      else
        raise "Unhandled HTTP response code: #{status.inspect}: \"#{response.body}\""
      end
    end

    def parse(response)
      body = response.body.to_s
      content_type = response.content_type
      case content_type.mime_type
      when 'application/json'
        parse_json(body)
      when 'text/xml' # sigh, the schema is not part of the mimetype...
        parse_xml(body)
      else
        raise "Unknown content_type #{content_type.inspect}!"
      end
    end

    def parse_json(string)
      JSON.parse(string)
    end

    def parse_xml(string)
      if string.include?('urn:iso:std:iso:20022:tech:xsd:camt.053.001.02') # rubocop:disable Style/GuardClause
        CamtParser::String.parse(string)
      else
        raise 'Response is XML, but no known XML Schema found! Sad.'
      end
    end
  end
end
