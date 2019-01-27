# frozen_string_literal: true

require 'spec_helper'
require_relative '../../lib/campaigns_service'

describe 'Campaigns Service' do
  xcontext 'process URL parameter' do
    it 'should not send empty url' do; end
    it 'should process correct URL' do; end
    it 'should process Bad URLs' do; end
    it 'should process NOT a HASH response' do; end
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
