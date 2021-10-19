module Konfipay

  class Client


    #  class Error < StandardError; end


    def initialize
      @config = Konfipay.configuration
      @bearer_token = nil
    end

    def new_statements(params = {})
      authenticate if @bearer_token.nil?
      # TODO: Catch and retry 401 error
      response = http.auth("Bearer #{@bearer_token}").get("#{@config.base_url}/api/v4/Document/Camt#{query_params(params)}")
      raise_error_or_parse!(response)
    end

    def camt_file(r_id)
      authenticate if @bearer_token.nil?
      # this also marks this file as "read" and it will not show up in the default overview
      response = http.auth("Bearer #{@bearer_token}").get("#{@config.base_url}/api/v4/Document/Camt/#{r_id}")
    end

    def http
      HTTP.timeout(@config.timeout)
        .headers(accept: "application/json")
        .use(logging: { logger: @config.logger })
    end

    def query_params(params)
      if params.any?
        "?" + params.to_query
      else
        ""
      end
    end

    def raise_error_or_parse!(response)
      case response.status
      when 200
        parse(response)
      # TODO: Create error classes for common errors
      when 400
        # {"errorItems":[{"errorCode":"ERR-04-0009","errorMessage":"UnknownBankAccount","timestamp":"2021-10-19T15:10:45.767"}]}
        errors = parse(response)["errorItems"].map { |e| e["errorMessage"] }.join(", ")
        raise "400 Bad Request, errors: #{errors}" 
      when 404
        # {"Message":"Welcome to konfipay. There is no API-Endpoint defined for 'https://portal.konfipay.de/api/v4/Document/Camtiban=aaaa'. Please take a look at the konfipay API-Documentation for valid API-Endpoints","ApiDocumentationLink":"https://portal.konfipay.de/Info/Api_Doc"}
        raise "404 Error: #{parse(response)['Message'].inspect}"
      else
        raise "Unhandled HTTP response code: #{response.status.inspect}: \"#{response.body.to_s}\""
      end
    end

    def parse(response)
      case response.content_type.mime_type
      when "application/json"
        JSON.parse(response.body.to_s)
      else
        raise "Unknown content_type #{response.content_type.inspect}!"
      end
    end

    def authenticate
      response = http.post("#{@config.base_url}/api/v4/Auth/Login/Token",
        json: {
          "apiKey": @config.api_key,
          "client": {
            "name": @config.api_client_name,
            "version": @config.api_client_version
          }
        }
      )
      raise response.inspect unless response.status.success?
      @bearer_token = JSON.parse(response.body.to_s)["accessToken"]
      raise "AAAAAA" unless @bearer_token # TODO: better message/error class?

      # on any other api call, set @bearer_token to nil if response is 401, then use authenticate again and retry (once)
    end
  end
end
