require 'spec_helper'

describe RightSupport::Net::Balancing::StickyPolicy do
  context :initialize do

  end

  before(:each) do
    @endpoints = [1,2,3,4,5]
    @policy = RightSupport::Net::Balancing::StickyPolicy.new({})
    @policy.set_endpoints(@endpoints)
    @trials = 2500
  end


  context :next do

    context 'given all servers are healthy' do
      it 'sticks to chosen one' do
        chance = 1.0
        seen = find_empirical_distribution(@trials,@endpoints) do 
          @policy.next
        end
        seen.each_pair do |_, count|
          (Float(count) / Float(@trials)).should be_close(chance, 0.025) #allow 5% margin of error
        end
      end
    end

    context 'given a chosen server becomes unavailable' do
      it 'chooses the next server and sticks to it' do
        @ep1, @hc = @policy.next

        seen = find_empirical_distribution(@trials,@endpoints) do
          @policy.next
        end
        seen[[@ep1,true]].should eql(@trials)

        @policy.bad(@chosen,0,0)
        @ep2, @hc = @policy.next

        seen = find_empirical_distribution(@trials,@endpoints) do
          @policy.next
        end
        seen[[@ep1,true]].should be_nil
        seen[[@ep2,true]].should eql(@trials)
      end
    end
  end
end
