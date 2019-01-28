# frozen_string_literal: true

require 'spec_helper'
require_relative '../../lib/campaigns_service'

describe 'Campaigns Service' do
  context 'process URL parameter' do
    before do
      allow(CampaignsService).to receive(:load_campaigns).and_return({})
      allow(CampaignsService).to receive(:format_it).and_return({})
    end

    it 'should not send empty url' do
      response = CampaignsService.call
      expect(response[:success]).to be_falsey
    end

    it 'should process correct URL' do
      VCR.use_cassette('200_response') do
        url = 'https://mockbin.org/bin/fcb30500-7b98-476f-810d-463a0b8fc3df'
        response = CampaignsService.call(url: url)
        expect(response[:success]).to be_truthy
      end
    end

    it 'should process Bad URLs' do
      VCR.use_cassette('404_response') do
        url = 'https://httpstat.us/404'
        response = CampaignsService.call(url: url)
        expect(response[:success]).to be_falsey
        expect(response[:error_message]).to eq '404 Not Found'
      end
    end

    it 'should process NOT a HASH response' do
      VCR.use_cassette('NOT_HASH_response') do
        url = 'https://httpstat.us'
        response = CampaignsService.call(url: url)
        expect(response[:success]).to be_falsey
        expect(response[:error_message]).to eq 'Not a HASH response'
      end
    end
  end

  context 'detect discrepancies' do
    before do
      @campaigns = [
        { 'reference' => '1', 'status' => 'enabled', 'description' => 'Description for campaign 11' },
        { 'reference' => '2', 'status' => 'disabled', 'description' => 'Description for campaign 12' },
        { 'reference' => '3', 'status' => 'enabled', 'description' => 'Description for campaign 13' }
      ]
    end

    it 'should be OK without discrepancies' do
      allow(CampaignsService).to receive(:load_campaigns).and_return(@campaigns)
      VCR.use_cassette('200_response') do
        url = 'https://mockbin.org/bin/fcb30500-7b98-476f-810d-463a0b8fc3df'
        response = CampaignsService.call(url: url)
        expect(response[:result]).to be_empty
      end
    end

    it 'should detect something strang' do
      strange_result = [{ 'op' => 'strange', 'path' => '/2/path', 'value' => 'Description' }]
      allow(JsonDiff).to receive(:diff).and_return(strange_result)
      VCR.use_cassette('200_response') do
        url = 'https://mockbin.org/bin/fcb30500-7b98-476f-810d-463a0b8fc3df'
        response = CampaignsService.call(url: url)
        expect(response[:result]['success']).to be_falsey
        expect(response[:result][:error_message]).to eq('something strange')
      end
    end

    it 'should detect discrepancies when field value(s) is/are changed' do
      @campaigns.first['status'] = 'disabled'
      @campaigns.first['description'] = 'Description for campaign 00'
      @campaigns.last['description'] = 'Description for campaign 55'

      allow(CampaignsService).to receive(:load_campaigns).and_return(@campaigns)

      VCR.use_cassette('200_response') do
        url = 'https://mockbin.org/bin/fcb30500-7b98-476f-810d-463a0b8fc3df'
        response = CampaignsService.call(url: url)

        first_changed = response[:result].first
        second_changed = response[:result].last

        expect(response[:result].count).to eq(2)

        expect(first_changed['discrepancies'].count).to eq(1)
        expect(first_changed['discrepancies'].first['description']['remote']).to eq('Description for campaign 13')
        expect(first_changed['discrepancies'].first['description']['local']).to eq('Description for campaign 55')

        expect(second_changed['discrepancies'].count).to eq(2)
        expect(second_changed['discrepancies'].first['status']['remote']).to eq('enabled')
        expect(second_changed['discrepancies'].first['status']['local']).to eq('disabled')

        expect(second_changed['discrepancies'].last['description']['remote']).to eq('Description for campaign 11')
        expect(second_changed['discrepancies'].last['description']['local']).to eq('Description for campaign 00')
      end
    end

    it 'should detect missed campaign(s)' do
      campaign4 = { 'reference' => '4', 'status' => 'enabled', 'description' => 'Description for campaign 14' }
      @campaigns.push(campaign4)
      campaign5 = { 'reference' => '5', 'status' => 'enabled', 'description' => 'Description for campaign 15' }
      @campaigns.push(campaign5)
      allow(CampaignsService).to receive(:load_campaigns).and_return(@campaigns)

      VCR.use_cassette('200_response') do
        url = 'https://mockbin.org/bin/fcb30500-7b98-476f-810d-463a0b8fc3df'
        response = CampaignsService.call(url: url)

        expect(response[:result].count).to eq(2)

        expect(response[:result].first['remote_reference']).to eq('missed campaign')
        expect(response[:result].first['discrepancies'].first['remote']).to eq('')
        expect(response[:result].first['discrepancies'].first['local']).to include(campaign5)

        expect(response[:result].last['remote_reference']).to eq('missed campaign')
        expect(response[:result].last['discrepancies'].first['remote']).to eq('')
        expect(response[:result].last['discrepancies'].first['local']).to include(campaign4)
      end
    end

    it 'should detect new field(s) in campaign' do
      @campaigns.first['new_filed_one'] = 'some_data_one'
      @campaigns.first['new_filed_two'] = 'some_data_two'
      allow(CampaignsService).to receive(:load_campaigns).and_return(@campaigns)

      VCR.use_cassette('200_response') do
        url = 'https://mockbin.org/bin/fcb30500-7b98-476f-810d-463a0b8fc3df'
        response = CampaignsService.call(url: url)

        expect(response[:result].count).to eq(1)
        expect(response[:result].first['remote_reference']).to eq(@campaigns.first['reference'])
        expect(response[:result].last['discrepancies'].first['local']['new_field']).to include('name' => 'new_filed_one', 'data' => 'some_data_one')
        expect(response[:result].last['discrepancies'].last['local']['new_field']).to include('name' => 'new_filed_two', 'data' => 'some_data_two')
      end
    end

    it 'should detect removed campaign(s)' do
      campaign1 = @campaigns[0]
      campaign3 = @campaigns[2]
      @campaigns.delete_at(2)
      @campaigns.delete_at(0)
      allow(CampaignsService).to receive(:load_campaigns).and_return(@campaigns)

      VCR.use_cassette('200_response') do
        url = 'https://mockbin.org/bin/fcb30500-7b98-476f-810d-463a0b8fc3df'
        response = CampaignsService.call(url: url)

        expect(response[:result].count).to eq(2)
        expect(response[:result].first['remote_reference']).to eq('1')
        expect(response[:result].first['discrepancies'].first['local']).to eq('')
        expect(response[:result].first['discrepancies'].first['remote']).to include(campaign1)

        expect(response[:result].last['remote_reference']).to eq('3')
        expect(response[:result].last['discrepancies'].first['local']).to eq('')
        expect(response[:result].last['discrepancies'].first['remote']).to include(campaign3)
      end
    end

    it 'should detect removed campaign fields' do
      @campaigns.first.delete('status')
      @campaigns.last.delete('description')
      allow(CampaignsService).to receive(:load_campaigns).and_return(@campaigns)

      VCR.use_cassette('200_response') do
        url = 'https://mockbin.org/bin/fcb30500-7b98-476f-810d-463a0b8fc3df'
        response = CampaignsService.call(url: url)

        expect(response[:result].count).to eq(2)
        expect(response[:result].first['remote_reference']).to eq('1')
        expect(response[:result].first['discrepancies'].first['status']['local']).to eq('')
        expect(response[:result].first['discrepancies'].first['status']['remote']).not_to eq('')

        expect(response[:result].last['remote_reference']).to eq('3')
        expect(response[:result].last['discrepancies'].first['description']['local']).to eq('')
        expect(response[:result].last['discrepancies'].first['description']['remote']).not_to eq('')
      end
    end

    it 'should detect mixed changes' do
      @campaigns.first['status'] = 'disabled'
      @campaigns.last.delete('description')

      allow(CampaignsService).to receive(:load_campaigns).and_return(@campaigns)

      VCR.use_cassette('200_response') do
        url = 'https://mockbin.org/bin/fcb30500-7b98-476f-810d-463a0b8fc3df'
        response = CampaignsService.call(url: url)

        second_changed = response[:result].first
        expect(response[:result].count).to eq(2)

        expect(second_changed['discrepancies'].first['status']['remote']).to eq('enabled')
        expect(second_changed['discrepancies'].first['status']['local']).to eq('disabled')

        expect(response[:result].last['discrepancies'].first['description']['local']).to eq('')
        expect(response[:result].last['discrepancies'].first['description']['remote']).not_to eq('')
      end
    end
  end
end
