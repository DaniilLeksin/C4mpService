# frozen_string_literal: true

require 'rest-client'
require 'json-diff'

# CampaignsService is a service ...
class CampaignsService
  class << self
    def call(url: nil)
      return { success: false, error_message: 'No URL' } if url.nil?

      local_campaigns = load_campaigns
      response = RestClient.get(url, content_type: 'application/json')
      remote_campaigns = JSON.parse(response.body)['ads']
      result = JsonDiff.diff(local_campaigns, remote_campaigns)
      formatted = format_it(result: result, local_campaigns: local_campaigns, remote_campaigns: remote_campaigns)
      { success: true, result: formatted }
    rescue JSON::ParserError
      { success: false, error_message: 'Not a HASH response' }
    rescue RestClient::ExceptionWithResponse => e
      { success: false, error_message: e.message }
    end

    def format_it(result:, local_campaigns:, remote_campaigns:)
      formatted_result = []
      grouped_result = result.group_by { |diff| diff['path'].split('/').reject!(&:empty?).first }

      grouped_result.each do |k, v|
        remote_reference = remote_campaigns[k.to_i]
        discrepancies = []
        discrepancy_item = {}
        v.each do |discrepancy|
          case discrepancy['op']
          when 'replace'
            option = discrepancy['path'].split('/').reject!(&:empty?).last
            discrepancy_item[option] = { 'remote' => discrepancy['value'], 'local' => local_campaigns[k.to_i][option] }
            discrepancies.push(discrepancy_item)
          when 'remove'
            if remote_reference.nil?
              new_item_index = discrepancy['path'].split('/').reject!(&:empty?).last
              discrepancies.push('remote' => '', 'local' => local_campaigns[new_item_index.to_i])
            else
              new_option = discrepancy['path'].split('/').reject!(&:empty?).last
              discrepancies.push('remote' => '', 'local' => { new_field: { name: new_option, data: local_campaigns[k.to_i][new_option] } })
            end
          when 'add'
            path = discrepancy['path'].split('/').reject!(&:empty?)
            if path.one?
              discrepancies.push('remote' => discrepancy['value'], 'local' => '')
            else
              option = discrepancy['path'].split('/').reject!(&:empty?).last
              discrepancy_item[option] = { 'remote' => discrepancy['value'], 'local' => '' }
              discrepancies.push(discrepancy_item)
            end
          else
            return { success: false, error_message: 'something strange' }
          end
        end
        formatted_result.push ({
          'remote_reference' => remote_reference.nil? ? 'missed' : remote_reference['reference'],
          'discrepancies' => discrepancies
        })
      end

      formatted_result
    end

    private

    # Any way to extract campaigns through the Campaign
    def load_campaigns; end
  end
end
