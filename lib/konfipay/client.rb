# frozen_string_literal: true

module Konfipay
  # API Client for the Konfipay API (see https://portal.konfipay.de/api-docs/index.html)
  # Only selected API Endpoints are implemented.
  # Authentication is done automatically, and the auth token is cached in an instance of this class.
  class Client
    #  class Error < StandardError; end

    def initialize
      @config = Konfipay.configuration
      @bearer_token = nil
    end

    def logger
      @config.logger
    end

    def authenticate
      response = http.post(authentication_url(@config), authentication_params(@config))
      json = raise_error_or_parse!(response)
      @bearer_token = json['accessToken']
      raise "Couldn't get a bearer token in #{json.inspect}! What now?" unless @bearer_token.present?

      @bearer_token
    end

    def authentication_url(config)
      "#{config.base_url}/api/v4/Auth/Login/Token"
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

    def new_statements(params = {})
      response = authed_http.get(new_statements_url(@config, params))
      raise_error_or_parse!(response)
    end

    def new_statements_url(config, params)
      "#{config.base_url}/api/v4/Document/Camt#{query_params(params)}"
    end

    def camt_file(r_id, mark_as_read = true)
      # this also marks this file as "read" and it will not show up in the default overview, unless
      # we set "ack" = false
      params = {}
      params['ack'] = 'false' unless mark_as_read
      response = authed_http.get(camt_file_url(@config, r_id, params))
      raise_error_or_parse!(response)
    end

    def camt_file_url(config, r_id, params)
      "#{config.base_url}/api/v4/Document/Camt/#{r_id}#{query_params(params)}"
    end

    def http
      HTTP.timeout(@config.timeout)
          .headers(accept: 'application/json')
          .use(logging: { logger: @config.logger })
    end

    def authed_http
      authenticate if @bearer_token.nil?
      raise 'Something went really wrong with the authentication!' if @bearer_token.nil?

      http.auth("Bearer #{@bearer_token}")
    end

    def query_params(params)
      if params.any?
        "?#{params.to_query}"
      else
        ''
      end
    end

    def raise_error_or_parse!(response)
      case response.status
      when 200
        parse(response)
      when 204
        # "The request was processed successfully, but no data is available."
        nil
      # TODO: Create error classes for common errors
      when 400
        # {"errorItems":[{"errorCode":"ERR-04-0009","errorMessage":"UnknownBankAccount","timestamp":"2021-10-19T15:10:45.767"}]}
        errors = parse(response)['errorItems'].map { |e| e['errorMessage'] }.join(', ')
        raise "400 Bad Request, errors: #{errors}"
      when 404
        # {"Message":"Welcome to konfipay. There is no API-Endpoint defined for 'https://portal.konfipay.de/api/v4/Document/Camtiban=aaaa'. Please take a look at the konfipay API-Documentation for valid API-Endpoints","ApiDocumentationLink":"https://portal.konfipay.de/Info/Api_Doc"}
        raise "404 Error: #{parse(response)['Message'].inspect}"
      else
        raise "Unhandled HTTP response code: #{response.status.inspect}: \"#{response.body}\""
      end
    end

    def parse(response)
      case response.content_type.mime_type
      when 'application/json'
        JSON.parse(response.body.to_s)
      when 'text/xml' # sigh, the schema is not part of the mimetype...
        body = response.body.to_s
        if body.include?('urn:iso:std:iso:20022:tech:xsd:camt.053.001.02')
          CamtParser::String.parse(body)
        else
          raise 'Response is XML, but no known XML Schema found! Sad.'
        end
      else
        raise "Unknown content_type #{response.content_type.inspect}!"
      end
    end
  end
end
