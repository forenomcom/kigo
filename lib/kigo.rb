require "kigo/version"
require "kigo/configuration"
require "typhoeus"

module Kigo
  APIUrl = 'https://app.kigo.net/api/ra/v1'

  def self.request(end_point, data = nil)
    request = self.wrap_request(end_point, data)
    request.on_complete do |response|
      if response.code == 409 # for some reason instead of 429
        sleep Kigo.configuration.concurrency
        hydra.queue(request)
      else
        yield self.parse_response response
      end
    end
    hydra.queue(request)
    hydra.run
  end

  private

  def self.hydra
    @@hydra ||= Typhoeus::Hydra.new max_concurrency: Kigo.configuration.concurrency
  end

  def self.wrap_request(end_point, data = nil, headers={})
    request_options = {
      method: :post,
      body: data.to_json,
      userpwd: [Kigo.configuration.username, Kigo.configuration.password].join(":"),
      headers: headers.merge({
        'Content-Type' => 'application/json'
      })
    }
    Typhoeus::Request.new("#{APIUrl}#{end_point}", request_options)
  end

  def self.parse_response(response)
    if response.success?
      begin
        result = JSON.parse(response.body)
        if result["API_RESULT_CODE"] == "E_OK"
          result["API_REPLY"]
        else
          { error: "#{result["API_RESULT_CODE"]} #{result["API_RESULT_TEXT"]}" }
        end
      rescue
        { error: "Error parsing reply" }
      end
    else
      { http_code: response.code, error: "Response error. #{response.body}" }
    end
  end
end