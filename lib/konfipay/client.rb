module Konfipay

  class Client


    #  class Error < StandardError; end


    def initialize
      @config = Konfipay.configuration
      @bearer_token = nil
    end

    def new_statements
      authenticate if @bearer_token.nil?
      # TODO: Catch and retry 401 error
      response = http.auth("Bearer #{@bearer_token}").get("#{@config.base_url}/api/v4/Document/Camt")
      json = JSON.parse(response.body.to_s)
      # TODO: Only get each statement doc if iban given and matching
      # TODO: Get each new document, collect and parse each CAMT and get out the actual statement info
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
