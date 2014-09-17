require "kigo/version"
require "kigo/configuration"
require "typhoeus"

module Kigo
  APIUrl = 'https://app.kigo.net/api/ra/v1'

  def self.wrap_request(end_point, data = nil, headers={})
    request_options = {
      method: :post,
      body: self.filter_params(data).to_json,
      userpwd: [Kigo.configuration.username, Kigo.configuration.password].join(":"),
      headers: headers.merge({
        'Content-Type' => 'application/json'
      })
    }
    Typhoeus::Request.new("#{APIUrl}#{end_point}", request_options)
  end

  def self.access_multiple(resources=[])
    hydra = Typhoeus::Hydra.new
    request_responses = []

    resources.each do |resource|
      request = self.wrap_request(resource[:end_point], resource[:verb], resource[:params], resource[:headers])
      request.on_complete do |response|
        request_responses << self.parse_response(response)
      end
      hydra.queue(request)
    end
    hydra.run
    request_responses
  end

  def self.access(end_point, data = nil, headers={})
    request = self.wrap_request(end_point, data, headers)
    request.on_complete do |response|
      return self.parse_response(response)
    end
    hydra = Typhoeus::Hydra.new
    hydra.queue(request)
    hydra.run
  end

  def self.parse_response(response)
    if response.success?
      begin
        result = JSON.parse(response.body)
        return result["API_RESULT_CODE"] == "E_OK" ? result["API_REPLY"] : { 'error' => "#{result["API_RESULT_CODE"]} #{result["API_RESULT_TEXT"]}" }
      rescue
        return { 'error' => "Error parsing reply" }
      end
    else
      return { 'error' => "Response error. #{response.code} #{response.body}" }
    end
  end

  def self.filter_params(params)
    filtered_attr = {}
    if params.is_a? Hash
      params.each do |param_name, value|
        if value.is_a? Hash
          filtered_attr = filtered_attr.merge(param_name => filter_params(value))
        elsif value.is_a? Array
          filtered_attr = filtered_attr.merge(param_name => filter_array_params(value))
        else
          if value.class == ActionDispatch::Http::UploadedFile
            filtered_attr = filtered_attr.merge(param_name => value.tempfile)
          else
            filtered_attr = filtered_attr.merge(param_name => value)
          end
        end
      end
      filtered_attr
    else
      params
    end
  end

  def self.filter_array_params(array)
    array.map { |a| a.is_a?(Hash) ? self.filter_params(a) : a }
  end

  def self.ping
    self.access('/ping', {})
  end


  # Reservations
  def self.diff_property_calendar_reservations(diff_id = nil)
    self.access('/diffPropertyCalendarReservations', { 'DIFF_ID' => diff_id })
  end

  def self.create_confirmed_reservation(params)
    # params example:
    # {
    #   "PROP_ID" => 1434,
    #   "RES_CHECK_IN" => "2011-07-21",
    #   "RES_CHECK_OUT" => "2011-07-26",
    #   "RES_N_ADULTS" => 2,
    #   "RES_N_CHILDREN" => 1,
    #   "RES_N_BABIES" => 0,
    #   "RES_GUEST" => {
    #     "RES_GUEST_FIRSTNAME" => "Robert",
    #     "RES_GUEST_LASTNAME" => "Roquefort",
    #     "RES_GUEST_EMAIL" => "robert@yahoo.co.uk",
    #     "RES_GUEST_PHONE" => "",
    #     "RES_GUEST_COUNTRY" => "GB"
    #   },
    #   "RES_COMMENT" => "",
    #   "RES_COMMENT_GUEST" => "",
    #   "RES_UDRA" => [
    #     {
    #       "UDRA_ID" => 161,
    #       "UDRA_CHOICE_ID" => 199
    #     },
    #     {
    #       "UDRA_ID" => 162,
    #       "UDRA_TEXT" => "John Smith told me about you!"
    #     }
    #   ]
    # }
    self.access('/createConfirmedReservation', params)
  end

  #Properties
  def self.list_properties
    self.access('/listProperties2')
  end

  def self.read_property(property_id)
    self.access('/readProperty2', { 'PROP_ID' => property_id })
  end

  # Pricing
  def self.read_property_pricing_setup(property_id)
    self.access('/readPropertyPricingSetup', { 'PROP_ID' => property_id })
  end

  def self.diff_property_pricing_setup(diff_id = nil)
    self.access('/diffPropertyPricingSetup', { 'DIFF_ID' => diff_id })
  end

#  Example of pricing hash:
#  { "RENT" => {
#      "PERGUEST_CHARGE" => nil,
#      "PERIODS" => [
#        { "CHECK_IN" => "2014-01-01",
#          "CHECK_OUT" => "2014-03-01",
#          "NAME" => "Winter 2014",
#          "STAY_MIN" => { "UNIT" => "NIGHT", "NUMBER" => 3 },
#          "WEEKLY" => false,
#          "NIGHTLY_AMOUNTS" => [
#            { "GUESTS_FROM" => 1,
#              "WEEK_NIGHTS" => [ 1, 2, 3, 4, 5, 6, 7 ],
#              "STAY_FROM" => { "UNIT" => "NIGHT", "NUMBER" => 1 },
#              "AMOUNT" => "100.00"
#            }
#          ]
#        },
#        { "CHECK_IN" => "2014-03-01",
#          "CHECK_OUT" => "2014-05-31",
#          "NAME" => "",
#          "STAY_MIN" => { "UNIT" => "NIGHT", "NUMBER" => 7 },
#          "WEEKLY" => true,
#          "WEEKLY_AMOUNTS" => [
#            { "GUESTS_FROM" => 1,
#              "AMOUNT" => "650.00"
#            }
#          ]
#        }
#      ]
#    }
#  }
  def self.update_property_pricing_setup(property_id, pricing)
    self.access('/updatePropertyPricingSetup', { 'PROP_ID' => property_id, 'PRICING' => pricing })
  end
end