require 'spec_helper'

describe RightSupport::Net::LB::Sticky do

  before(:all) do
    @endpoints = [1,2,3,4,5]
    @trials = 2500
  end

  before(:each) do
    @policy = RightSupport::Net::LB::Sticky.new({})
  end

  context :initialize do
    it 'creates policy with an empty list of endpoints' do
      @policy.next.should be_nil
    end
  end

  context :next do

    before(:each) do
      @policy.set_endpoints(@endpoints)
    end

    context 'given all servers are healthy' do
      it 'sticks to chosen one' do
        chance = 1.0
        seen = find_empirical_distribution(@trials,@endpoints) do 
          @policy.next
        end
        seen.each_pair do |_, count|
          (Float(count) / Float(@trials)).should be_within(0.025).of(chance) #allow 5% margin of error
        end
      end
    end

    context 'given a chosen server becomes unavailable' do
      it 'chooses the next server and sticks to it' do
        @ep1 = @policy.next.first

        seen = find_empirical_distribution(@trials,@endpoints) do
          @policy.next
        end
        seen[[@ep1,false]].should eql(@trials)

        @policy.bad(@chosen,0,0)
        @ep2 = @policy.next.first

        seen = find_empirical_distribution(@trials,@endpoints) do
          @policy.next
        end
        seen[[@ep1,false]].should be_nil
        seen[[@ep2,false]].should eql(@trials)
      end
    end
  end

  context :set_endpoints do
    context 'given an empty list of endpoints' do
      it 'acts as initializer' do
        @policy.next.should be_nil
        @policy.set_endpoints(@endpoints)
        @endpoints.include?(@policy.next.first).should be_true
      end
    end

    context 'given an existing list endpoints' do
      before(:each) do
        @policy.set_endpoints(@endpoints)
      end

      context 'and updated list of endpoints contains a chosen server' do
        it 'updates composition, but still using chosen server' do
          @chosen_endpoint = @policy.next.first
          @updated_endpoints = @endpoints + [6,7]
          @policy.set_endpoints(@updated_endpoints)
          @policy.next.first.should be_eql(@chosen_endpoint)
        end
      end

      context 'and updated list of endpoints does not contain a chosen server' do
        it 'updates composition and chooses new server' do
          @chosen_endpoint = @policy.next.first
          @updated_endpoints = @endpoints - [@chosen_endpoint]
          @policy.set_endpoints(@updated_endpoints)
          @policy.next.first.should_not be_eql(@chosen_endpoint)
        end
      end
    end
  end #:set_endpoints
end
