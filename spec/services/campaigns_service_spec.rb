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
        expect(second_changed['discrepancies'].count).to eq(2)
      end
    end

    it 'should detect missed campaign(s)' do
      @campaigns.push('reference' => '4', 'status' => 'enabled', 'description' => 'Description for campaign 14')
      @campaigns.push('reference' => '5', 'status' => 'enabled', 'description' => 'Description for campaign 15')
      allow(CampaignsService).to receive(:load_campaigns).and_return(@campaigns)

      VCR.use_cassette('200_response') do
        url = 'https://mockbin.org/bin/fcb30500-7b98-476f-810d-463a0b8fc3df'
        response = CampaignsService.call(url: url)

        expect(response[:result].count).to eq(2)
        expect(response[:result].first['remote_reference']).to eq('missed')
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
      end
    end

    it 'should detect removed campaign(s)' do
      @campaigns.delete_at(2)
      @campaigns.delete_at(0)
      allow(CampaignsService).to receive(:load_campaigns).and_return(@campaigns)

      VCR.use_cassette('200_response') do
        url = 'https://mockbin.org/bin/fcb30500-7b98-476f-810d-463a0b8fc3df'
        response = CampaignsService.call(url: url)

        expect(response[:result].count).to eq(2)
      end
    end

    it 'should detect removed campaign(s)' do
      @campaigns.first.delete('status')
      @campaigns.last.delete('description')
      allow(CampaignsService).to receive(:load_campaigns).and_return(@campaigns)

      VCR.use_cassette('200_response') do
        url = 'https://mockbin.org/bin/fcb30500-7b98-476f-810d-463a0b8fc3df'
        response = CampaignsService.call(url: url)

        expect(response[:result].count).to eq(2)
      end
    end
  end
end
