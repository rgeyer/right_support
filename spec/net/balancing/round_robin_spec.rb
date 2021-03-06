require 'spec_helper'

describe RightSupport::Net::LB::RoundRobin do
  before(:each) do
    @endpoints = [1,2,3,4,5]
    @policy = RightSupport::Net::LB::RoundRobin.new()
    @policy.set_endpoints(@endpoints)
  end

  it 'chooses fairly' do
    test_random_distribution do
      @policy.next
    end
  end
end
