require 'spec_helper'

describe RightSupport::Net::LB::HealthCheck do
  context :initialize do

  end

  before(:each) do
    @endpoints = [1,2,3,4,5]
    @yellow_states = 4
    @reset_time = 60
    @policy = RightSupport::Net::LB::HealthCheck.new(
                :yellow_states => @yellow_states,
                :reset_time => @reset_time)
    @policy.set_endpoints(@endpoints)
    @trials = 2500
  end

  context :initialize do
    it 'starts endpoints in yellow-1 state' do
      stats = @policy.get_stats
      @endpoints.each { |ep| stats[ep].should == 'yellow-1' }
    end
  end

  context :good do
    context 'given a red server' do
      before(:each) do
        @red = @endpoints.first
        @yellow_states.times { @policy.bad(@red, 0, Time.now) }
        @policy.should have_red_endpoint(@red)
      end

      it "changes to yellow-N" do
        @policy.good(@red, 0, Time.now)
        @policy.should have_yellow_endpoint(@red, @yellow_states-1)
      end
    end

    context 'given a yellow-N server' do
      before(:each) do
        @yellow = @endpoints.first
        (@yellow_states-1).times { @policy.bad(@yellow, 0, Time.now) }
        @policy.should have_yellow_endpoint(@yellow, @yellow_states)
      end

      it 'decreases the yellow level to N-1' do
        @policy.good(@yellow, 0, Time.now)
        @policy.should have_yellow_endpoint(@yellow, @yellow_states-1)
      end

      context 'when N == 1' do
        before(:each) do
          @yellow = @endpoints[1] #this should be yellow-1 since we haven't tampered with it yet
          @policy.get_stats[@yellow].should == 'yellow-1'
        end

        it 'changes to green' do
          @policy.should have_yellow_endpoint(@yellow, 1)
          @policy.good(@yellow, 0, Time.now)
          @policy.should have_green_endpoint(@yellow)
        end
      end
    end

    context 'when on_health_change callback is enabled' do
      before(:each) do
        @yellow_states = 3
        @health_updates = []
        @policy = RightSupport::Net::LB::HealthCheck.new({
                    :yellow_states => @yellow_states, :reset_time => @reset_time,
                    :on_health_change => lambda { |health| @health_updates << health }})
        @policy.set_endpoints(@endpoints)

        # put everyone into green state, then forget all health updates. this helps us write an
        # easier test.
        @endpoints.each { |ep| @policy.good(ep, 0, Time.now) }
        @health_updates = []
      end

      it "notifies of overall improving health only at transition points" do
        endpoints = @endpoints.shuffle
        endpoints.shuffle.each { |ep| @policy.bad(ep, 0, Time.now) }
        endpoints.shuffle.each { |ep| @policy.bad(ep, 0, Time.now) }
        endpoints.shuffle.each { |ep| @policy.bad(ep, 0, Time.now) }
        @health_updates.should == ['yellow-1', 'yellow-2', 'red']
        @policy.good(endpoints[0], 0, Time.now)
        @health_updates.should == ['yellow-1', 'yellow-2', 'red', 'yellow-2']
        endpoints[1..-1].each { |ep| @policy.good(ep, 0, Time.now) }
        @health_updates.should == ['yellow-1', 'yellow-2', 'red', 'yellow-2']
        @policy.good(endpoints[0], 0, Time.now)
        @health_updates.should == ['yellow-1', 'yellow-2', 'red', 'yellow-2', 'yellow-1']
        @policy.bad(endpoints[0], 0, Time.now)
        @health_updates.should == ['yellow-1', 'yellow-2', 'red', 'yellow-2', 'yellow-1', 'yellow-2']
        @policy.good(endpoints[0], 0, Time.now)
        @health_updates.should == ['yellow-1', 'yellow-2', 'red', 'yellow-2', 'yellow-1', 'yellow-2', 'yellow-1']
        2.times { @policy.good(endpoints[1], 0, Time.now) }
        @health_updates.should == ['yellow-1', 'yellow-2', 'red', 'yellow-2', 'yellow-1', 'yellow-2', 'yellow-1', 'green']
        endpoints.each { |ep| @policy.good(ep, 0, Time.now) }
        @health_updates.should == ['yellow-1', 'yellow-2', 'red', 'yellow-2', 'yellow-1', 'yellow-2', 'yellow-1', 'green']
        endpoints.each { |ep| @policy.good(ep, 0, Time.now) }
        @health_updates.should == ['yellow-1', 'yellow-2', 'red', 'yellow-2', 'yellow-1', 'yellow-2', 'yellow-1', 'green']
      end
    end
  end

  context :bad do
    context 'given a green server' do
      before(:each) do
        @green = @endpoints.first
        @policy.good(@green, 0, Time.now)
        @policy.should have_green_endpoint(@green)
      end

      it 'changes to yellow-1' do
        @policy.bad(@green, 0, Time.now)
        @policy.should have_yellow_endpoint(@green, 1)
      end
    end

    context 'given a yellow-N server' do
      before(:each) do
        @yellow = @endpoints.first
      end

      it 'increases the yellow level to N+1' do
        @policy.bad(@yellow, 0, Time.now)
        @policy.should have_yellow_endpoint(@yellow, 2)
      end

      context 'when N == yellow_states-1' do
        before(:each) do
          n = @yellow_states - 2
          n.times { @policy.bad(@yellow, 0, Time.now) }
          @policy.should have_yellow_endpoint(@yellow, n+1)
        end

        it 'changes to red' do
          @policy.bad(@yellow, 0, Time.now)
          @policy.should have_red_endpoint(@yellow)
        end
      end
    end

    context 'given a red server' do
      it 'does nothing' do
        @red = @endpoints.first
        @yellow_states.times { @policy.bad(@red, 0, Time.now) }
        @policy.should have_red_endpoint(@red)

        @policy.bad(@red, 0, Time.now)
        @policy.should have_red_endpoint(@red)
      end
    end

    context 'when on_health_change callback is enabled' do
      before(:each) do
        @yellow_states = 3
        @health_updates = []
        @policy = RightSupport::Net::LB::HealthCheck.new({
                    :yellow_states => @yellow_states, :reset_time => @reset_time,
                    :on_health_change => lambda { |health| @health_updates << health }})
        @policy.set_endpoints(@endpoints)

        # put everyone into green state, then forget all health updates. this helps us write an
        # easier test.
        @endpoints.each { |ep| @policy.good(ep, 0, Time.now) }
        @health_updates = []
      end

      it "notifies of overall worsening health only at transition points" do
        # make most endpoints yellow-1
        endpoints = @endpoints.shuffle
        endpoints[1..-1].each { |ep| @policy.bad(ep, 0, Time.now) }
        @policy.bad(endpoints[0], 0, Time.now)
        @health_updates.should == ['yellow-1']
        endpoints.each { |ep| @policy.bad(ep, 0, Time.now) }
        @health_updates.should == ['yellow-1', 'yellow-2']
        endpoints[1..-1].each { |ep| @policy.bad(ep, 0, Time.now) }
        @health_updates.should == ['yellow-1', 'yellow-2']
        @policy.bad(endpoints[0], 0, Time.now)
        @health_updates.should == ['yellow-1', 'yellow-2', 'red']
        @policy.bad(endpoints[0], 0, Time.now)
        @health_updates.should == ['yellow-1', 'yellow-2', 'red']
      end
    end
  end

  context :next do

    context 'given all green servers' do
      it 'chooses fairly' do
        test_random_distribution do 
          @policy.next
        end
      end
    end

    context 'given all red servers' do
      it 'returns nil to indicate no servers are available' do
        @endpoints.each do |endpoint|
          @yellow_states.times { @policy.bad(endpoint, 0, Time.now) }
          @policy.should have_red_endpoint(endpoint)
        end
        @policy.next.should be_nil
      end
    end

    context 'given a mixture of servers' do
      it 'never chooses red servers' do
        @red = @endpoints.first
        @yellow_states.times { @policy.bad(@red, 0, Time.now) }
        @policy.should have_red_endpoint(@red)

        seen = find_empirical_distribution(@trials,@endpoints) do 
          @policy.next
        end

        seen.include?(@red).should be_false
      end

      it 'chooses fairly from the green and yellow servers' do
        @red = @endpoints.first
        @yellow_states.times { @policy.bad(@red, 0, Time.now) }
        @policy.should have_red_endpoint(@red)

        seen = find_empirical_distribution(@trials,@endpoints) do
          @policy.next
        end

        seen.include?(@red).should be_false
        should_be_chosen_fairly(seen, @trials, @endpoints.size - 1)
      end

      it 'demands a health check for yellow servers' do
        pending
      end

      it "maintains the same order of green and yellow servers" do
        actual = []
        expected = [3,4,1,2]

        endpoints = [1,2,3,4]
        policy = RightSupport::Net::LB::HealthCheck.new(:yellow_states => 1)
        policy.set_endpoints(endpoints)
        policy.instance_variable_set(:@counter, 1)
        endpoints.size.times do
          endpoint, yellow = policy.next
          policy.bad(endpoint, 0, Time.now) unless endpoint == 4
          actual << endpoint
        end

        actual.should == expected
      end
    end

    context 'given a red server' do
      before(:each) do
        @red = @endpoints.first
        (@yellow_states-1).times { @policy.bad(@red, 0, Time.now - 60) }
      end

      context 'when @reset_time passes' do
        it 'resets the server to yellow' do
          @policy.should have_red_endpoint(@red)
          @policy.next
          @policy.should have_yellow_endpoint(@red, @yellow_states-1)
        end
      end

    end

    context 'given a yellow-2 server' do
      before(:each) do
        @yellow = @endpoints.first
        @policy.bad(@yellow, 0, Time.now - 60)
        @policy.should have_yellow_endpoint(@yellow, 2)
      end

      context 'when @reset_time passes' do
        it 'decreases the yellow level to N-1' do
          @policy.next
          @policy.should have_yellow_endpoint(@yellow, 1)
        end
      end
    end

    context 'given a yellow-1 server' do
      before(:each) do
        @yellow = @endpoints.first
        @policy.good(@yellow, 0, Time.now - 60)
        @policy.bad(@yellow, 0, Time.now - 60)
        @policy.should have_yellow_endpoint(@yellow, 1)
      end

      context 'when @reset_time passes' do
        it 'resets the server to green' do
          @policy.next
          @policy.should have_green_endpoint(@yellow)
        end
      end
    end
  end

  context :get_stats do
    context 'given all green servers' do
      before(:each) do
        @endpoints.each { |ep| @policy.good(ep, 0, Time.now) }
      end

      it 'reports all endpoints as green' do
        expected_stats = {}
        @endpoints.each { |ep| expected_stats[ep] = 'green' }

        @policy.get_stats.should_not be_nil
        @policy.get_stats.should == expected_stats
      end
    end

    context 'given all red servers' do
      it 'reports all endpoints as red' do
        expected_stats = {}
        @endpoints.each { |ep| expected_stats[ep] = 'red' }

        @endpoints.each do |endpoint|
          @yellow_states.times { @policy.bad(endpoint, 0, Time.now) }
        end

        @policy.get_stats.should_not be_nil
        @policy.get_stats.should == expected_stats
      end
    end

    context 'given all yellow-N servers' do
      it 'reports all endpoints as yellow-N' do
        expected_stats = {}
        @endpoints.each { |ep| expected_stats[ep] = "yellow-#{@yellow_states - 1}" }

        @endpoints.each do |endpoint|
          @yellow_states.times { @policy.bad(endpoint, 0, Time.now) }
          @policy.good(endpoint, 0, Time.now)
        end

        @policy.get_stats.should_not be_nil
        @policy.get_stats.should == expected_stats
      end
    end
  end

  context :set_endpoints do
    context 'given endpoints stack does not exist' do
      before(:each) do
        @policy = RightSupport::Net::LB::HealthCheck.new({
                    :yellow_states => @yellow_states, :reset_time => @reset_time})
      end

      it 'acts as initializer' do
        @policy.set_endpoints(@endpoints)
        @endpoints.include?(@policy.next.first).should be_true
      end
    end

    context 'given an existing endpoints stack' do
      it 'updates composition and saves previous statuses of endpoints' do
        expected_stats = {}
        @endpoints.each { |ep| expected_stats[ep] = "yellow-#{@yellow_states - 1}" }

        @endpoints.each do |endpoint|
          @yellow_states.times { @policy.bad(endpoint, 0, Time.now) }
          @policy.good(endpoint, 0, Time.now)
        end

        @new_endpoins = [6,7]
        @new_endpoins.each { |ep| expected_stats[ep] = "yellow-1" }

        @updated_endpoints = @endpoints + @new_endpoins
        @policy.set_endpoints(@updated_endpoints)
        @policy.get_stats.should eql(expected_stats)
      end
    end
  end #:set_endpoints
end
