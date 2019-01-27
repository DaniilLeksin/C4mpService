# frozen_string_literal: true

require 'rest-client'
require 'json-diff'

# CampaignsService is a service ...
module CampaignsService
  class << self
    def call(url: nil)
      return { success: false, error_message: 'No URL' } if url.nil?

      local_campaigns = load_campaigns
      response = RestClient.get(url, content_type: 'application/json') 
      remote_campaigns = JSON.parse(response.body)['ads']
      result = JsonDiff.diff(local_campaigns, remote_campaigns)
      { success: true, result: result }

    rescue JSON::ParserError
      { success: false, error_message: 'Not a HASH response' }
    rescue RestClient::ExceptionWithResponse => e
      { success: false, error_message: e.message }
    end

    private

    # Any way to extract campaigns through the Campaign
    def load_campaigns; end
  end
end
