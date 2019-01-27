# frozen_string_literal: true

require 'spec_helper'
require_relative '../../lib/campaigns_service'

describe 'Campaigns Service' do
  context 'process URL parameter' do
    before do
      allow(CampaignsService).to receive(:load_campaigns).and_return({})
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

  xcontext 'detect discrepancies' do
    it 'should be OK without discrepancies' do; end
    it 'should detect discrepancies when field value(s) is/are changed' do; end
    it 'should detect missed campaign(s)' do; end
    it 'should detect new field(s) in campaign' do; end
    it 'should detect new field(s) in existing campaign' do; end
    it 'should detect removed campaign(s)' do; end
    it 'should detect removed campaign(s)' do; end
  end
end
