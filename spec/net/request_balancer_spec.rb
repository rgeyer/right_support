require 'spec_helper'

class TestException < Exception; end
class OtherTestException < Exception; end
class BigDeal < TestException; end
class NoBigDeal < TestException; end

class MockHttpError < Exception
  attr_reader :http_code
  def initialize(message=nil, code=400)
    super(message)
    @http_code = code
  end
end

class MockResourceNotFound < MockHttpError
  def initialize(message=nil)
    super(message, 404)
  end
end

class MockRequestTimeout < MockHttpError
  def initialize(message=nil)
    super(message, 408)
  end
end

describe RightSupport::Net::RequestBalancer do
  def test_raise(fatal, do_raise, expect)
    bases = []
    base = do_raise.superclass
    while base != Exception
      bases << base
      base = base.superclass
    end

    exception = expect.first
    count = expect.last
    rb = RightSupport::Net::RequestBalancer.new([1,2,3], :fatal=>fatal)
    @tries = 0

    code = lambda do
      rb.request do |_|
        @tries += 1
        next unless do_raise
        if bases.include?(RestClient::ExceptionWithResponse)
          #Special case: RestClient exceptions need an HTTP response, but they
          #have stack recursion if we give them something other than a real
          #HTTP response. Blech!
          raise do_raise, nil
        else
          #Generic exception with message
          raise do_raise, 'Bah humbug; fie on thee!'
        end
      end
    end

    if exception
      code.should raise_error(expect[0])
    else
      code.should_not raise_error
    end

    @tries.should == count
  end

  def test_bad_endpoint_requests(number_of_endpoints)
    test = Proc.new do |endpoint|
      @health_checks += 1
      false
    end

    expect = number_of_endpoints
    yellow_states = 4
    rb = RightSupport::Net::RequestBalancer.new((1..expect).to_a,
                                                :policy => RightSupport::Net::Balancing::HealthCheck,
                                                :health_check => test,
                                                :yellow_states => yellow_states)
    @health_checks = 0
    tries = 0
    l = lambda do
      rb.request do |endpoint|
        tries += 1
        raise Exception
      end
    end
    yellow_states.times do
      l.should raise_error
    end
    tries.should == expect
    @health_checks.should == expect * (yellow_states - 1)
  end

  context :initialize do
    it 'requires a list of endpoint URLs' do
      lambda do
        RightSupport::Net::RequestBalancer.new(nil)
      end.should raise_exception(ArgumentError)
    end

    context 'with Integer :retry option' do
      it 'stops after N total tries' do
        lambda do
          @tries = 0
          RightSupport::Net::RequestBalancer.new([1, 2, 3], :retry=>1).request do |u|
            @tries += 1
            raise NoBigDeal
          end
        end.should raise_error
        @tries.should == 1
      end
    end

    context 'with Proc :retry option' do
      it 'stops when call evaluates to false' do
        @tries = 0

        proc = Proc.new do |ep, n|
          @tries < 1
        end

        balancer = RightSupport::Net::RequestBalancer.new([1, 2, 3], :retry => proc)
        lambda do
          balancer.request do |u|
            @tries += 1
            raise NoBigDeal
          end
        end.should raise_error(RightSupport::Net::NoResult)

        @tries.should == 1
      end
    end

    context ':fatal option' do
      it 'has reasonable defaults' do
        exceptions = RightSupport::Net::RequestBalancer::DEFAULT_FATAL_EXCEPTIONS - [SignalException]
        balancer = RightSupport::Net::RequestBalancer.new([1])
        exceptions.each do |klass|
          lambda do
            balancer.request { |ep| raise klass }
          end.should raise_error(klass)
        end
      end

      context 'with a Proc' do
        it 'validates the arity' do
          bad_lambda = lambda { |too, many, arguments| }
          lambda do
            RightSupport::Net::RequestBalancer.new([1,2], :fatal=>bad_lambda)
          end.should raise_error(ArgumentError)
        end

        it 'delegates to the Proc' do
          always_retry = lambda { |e| false }
          balancer = RightSupport::Net::RequestBalancer.new([1,2], :fatal=>always_retry)

          lambda do
            balancer.request do |ep|
              raise BigDeal
            end
          end.should raise_error(RightSupport::Net::NoResult)

          lambda do
            balancer.request do |ep|
              raise ArgumentError
            end
          end.should raise_error(RightSupport::Net::NoResult)
        end
      end

      context 'with an Exception' do
        it 'considers that class of Exception to be fatal' do
          balancer = RightSupport::Net::RequestBalancer.new([1], :fatal=>BigDeal)
          lambda do
            balancer.request { |ep| raise BigDeal }
          end.should raise_error(BigDeal)
        end
      end

      context 'with an Array' do
        it 'considers any class in the array to be fatal' do
          exceptions = [ArgumentError, BigDeal]
          balancer = RightSupport::Net::RequestBalancer.new([1], :fatal=>exceptions)
          exceptions.each do |klass|
            lambda do
              balancer.request { |ep| raise klass }
            end.should raise_error(klass)
          end
        end
      end
    end

    context 'with :on_exception option' do
      it 'validates the arity' do
        bad_lambda = lambda { |way, too, many, arguments| }
        lambda do
          RightSupport::Net::RequestBalancer.new([1,2], :on_exception=>bad_lambda)
        end.should raise_error(ArgumentError)
      end
    end

    context 'with :policy option' do
      it 'accepts a Class' do
        policy = RightSupport::Net::Balancing::RoundRobin
        lambda {
          RightSupport::Net::RequestBalancer.new([1,2], :policy=>policy)
        }.should_not raise_error
      end

      it 'accepts an object' do
        policy = RightSupport::Net::Balancing::RoundRobin.new([1,2])
        lambda {
          RightSupport::Net::RequestBalancer.new([1,2], :policy=>policy)
        }.should_not raise_error
      end

      it 'checks for duck-type compatibility' do
        lambda {
          RightSupport::Net::RequestBalancer.new([1,2], :policy=>String)
        }.should raise_error
        lambda {
          RightSupport::Net::RequestBalancer.new([1,2], :policy=>'I like cheese')
        }.should raise_error
      end
    end

    context 'with :health_check option' do

      before(:each) do
        @health_check = Proc.new {|endpoint| "HealthCheck passed for #{endpoint}!" }
      end

      it 'accepts a block' do
        lambda {
          RightSupport::Net::RequestBalancer.new([1,2], :health_check => @health_check)
        }.should_not raise_error
      end

      it 'calls specified block' do 
        @balancer = RightSupport::Net::RequestBalancer.new([1,2], :health_check => @health_check)
        @options = @balancer.instance_variable_get("@options")
        @options[:health_check].call(1).should be_eql("HealthCheck passed for 1!")
      end

    end

    context 'with default :health_check option' do
      it 'calls default block' do 
        @balancer = RightSupport::Net::RequestBalancer.new([1,2])
        @options = @balancer.instance_variable_get("@options")
        @options[:health_check].call(1).should be_true
      end
    end

    context 'with :on_health_change option' do

      before(:each) do
        @health_updates = []
        @on_health_change = Proc.new {|health| @health_updates << health }
      end

      it 'accepts a block' do
        lambda {
          RightSupport::Net::RequestBalancer.new([1,2], :on_health_change => @on_health_change)
        }.should_not raise_error
      end
    end

    context 'with :resolve option' do

      before(:each) do
        @resolve = 15
        @balancer = RightSupport::Net::RequestBalancer.new([1,2], :resolve => @resolve)
      end

      it 'initializes an empty balancing policy' do
        @policy = @balancer.instance_variable_get("@policy")
        @policy.next.should be_nil
      end

      it 'initializes timestamp as a TTL for resolver' do
        @balancer.instance_variable_get("@resolved_at").should == 0
      end
    end
  end

  context :request do
    it 'requires a block' do
      lambda do
        RightSupport::Net::RequestBalancer.new([1]).request
      end.should raise_exception(ArgumentError)
    end

    it 'retries until a request completes' do
      list = [1,2,3,4,5,6,7,8,9,10]

      10.times do
        x = RightSupport::Net::RequestBalancer.new(list).request do |l|
          raise NoBigDeal, "Fall down go boom!" unless l == 5
          l
        end

        x.should == 5
      end
    end

    it 'raises if no request completes' do
      lambda do
        RightSupport::Net::RequestBalancer.request([1,2,3]) do |l|
          raise NoBigDeal, "Fall down go boom!"
        end
      end.should raise_exception(RightSupport::Net::NoResult, /NoBigDeal/)
    end

    context 'without :fatal option' do
      it 're-raises reasonable default fatal errors' do
        test_raise(nil, ArgumentError, [ArgumentError, 1])
        test_raise(nil, MockResourceNotFound, [MockResourceNotFound, 1])
      end

      it 'swallows StandardError and friends' do
        [SystemCallError, SocketError].each do |klass|
          test_raise(nil, klass, [RightSupport::Net::NoResult, 3])
        end
      end
    end

    context 'with :fatal option' do
      it 're-raises fatal errors' do
        test_raise(BigDeal, BigDeal, [BigDeal, 1])
        test_raise([BigDeal, NoBigDeal], NoBigDeal, [NoBigDeal, 1])
        test_raise(true, NoBigDeal, [NoBigDeal, 1])
        test_raise(lambda {|e| e.is_a? BigDeal }, BigDeal, [BigDeal, 1])
      end

      it 'swallows nonfatal errors' do
        test_raise(nil, BigDeal, [RightSupport::Net::NoResult, 3])
        test_raise(BigDeal, NoBigDeal, [RightSupport::Net::NoResult, 3])
        test_raise([BigDeal], NoBigDeal, [RightSupport::Net::NoResult, 3])
        test_raise(false, NoBigDeal, [RightSupport::Net::NoResult, 3])
        test_raise(lambda {|e| e.is_a? BigDeal }, NoBigDeal, [RightSupport::Net::NoResult, 3])
      end
    end

    context 'with default :fatal option' do
      it 'retries most Ruby builtin errors' do
        list = [1,2,3,4,5,6,7,8,9,10]
        rb = RightSupport::Net::RequestBalancer.new(list)

        [IOError, SystemCallError, SocketError].each do |klass|
          test_raise(nil, klass, [RightSupport::Net::NoResult, 3])
        end
      end

      it 'does not retry program errors' do
        list = [1,2,3,4,5,6,7,8,9,10]
        rb = RightSupport::Net::RequestBalancer.new(list)

        [ArgumentError, LoadError, NameError].each do |klass|
          test_raise(nil, klass, [klass, 1])
        end
      end

      it 'retries HTTP timeouts' do
        test_raise(nil, MockRequestTimeout, [RightSupport::Net::NoResult, 3])
        test_raise(nil, RestClient::RequestTimeout, [RightSupport::Net::NoResult, 3])
      end

      it 'does not retry HTTP 4xx other than timeout' do
        list = [1,2,3,4,5,6,7,8,9,10]
        rb = RightSupport::Net::RequestBalancer.new(list)

        codes = [401, 402, 403, 404, 405, 406, 407, 409]
        codes.each do |code|
          lambda do
            rb.request { |l| raise MockHttpError.new(nil, code) }
          end.should raise_error(MockHttpError)
        end
      end

      context 'with default :retry option' do
        it 'does mark endpoints as bad if they encounter retryable errors' do
          rb = RightSupport::Net::RequestBalancer.new([1,2,3], :policy => RightSupport::Net::Balancing::HealthCheck, :health_check => Proc.new {|endpoint| false})
          expect = rb.get_stats
          codes = [401, 402, 403, 404, 405, 406, 407, 408, 409]
          codes.each do |code|
            lambda do
              rb.request { |l| raise MockHttpError.new(nil, code) }
            end.should raise_error
          end

          rb.get_stats.should_not == expect
        end

        it 'does not mark endpoints as bad if they raise fatal errors' do
          rb = RightSupport::Net::RequestBalancer.new([1,2,3], :policy => RightSupport::Net::Balancing::HealthCheck, :health_check => Proc.new {|endpoint| false})
          expect = rb.get_stats
          codes = [401, 402, 403, 404, 405, 406, 407, 409]
          codes.each do |code|
            lambda do
              rb.request { |l| raise MockHttpError.new(nil, code) }
            end.should raise_error
          end

          rb.get_stats.should == expect
        end
      end
    end

    context 'with :on_exception option' do
      before(:each) do
        @list = [1,2,3,4,5,6,7,8,9,10]
        @callback = flexmock('Callback proc')
        @callback.should_receive(:respond_to?).with(:call).and_return(true)
        @callback.should_receive(:respond_to?).with(:arity).and_return(true)
        @callback.should_receive(:arity).and_return(3)
        @rb = RightSupport::Net::RequestBalancer.new(@list, :fatal=>BigDeal, :on_exception=>@callback)
      end

      it 'calls me back with fatal exceptions' do
        @callback.should_receive(:call).with(true, BigDeal, Integer)
        lambda {
          @rb.request { raise BigDeal }
        }.should raise_error(BigDeal)
      end

      it 'calls me back with nonfatal exceptions' do
        @callback.should_receive(:call).with(false, NoBigDeal, Integer)
        lambda {
          @rb.request { raise NoBigDeal }
        }.should raise_error(RightSupport::Net::NoResult)

      end
    end

    context 'given a class logger' do
      before(:all) do
        @logger = Logger.new(StringIO.new)
        RightSupport::Net::RequestBalancer.logger = @logger
      end

      after(:all) do
        RightSupport::Net::RequestBalancer.logger = nil
      end

      context 'when a retryable exception is raised' do
        it 'logs an error' do
          flexmock(@logger).should_receive(:error).times(4)

          lambda {
            balancer = RightSupport::Net::RequestBalancer.new([1,2,3])
            balancer.request do |ep|
              raise NoBigDeal, "Too many cows on the moon"
            end
          }.should raise_error(RightSupport::Net::NoResult)
        end
      end
    end

    context 'given a class health check policy' do
      it 'retries and health checks the correct number of times' do
        (1..10).to_a.each {|endpoint| test_bad_endpoint_requests(endpoint) }
      end
    end

    context 'with :resolve option' do
      before(:each) do
        @endpoints = [1,2,3,4]
        @resolved_set_1 = ['1.1.1.1','2.2.2.2','3.3.3.3','4.4.4.4']
        @resolved_set_2 = ['5.5.5.5','6.6.6.6','7.7.7.7','8.8.8.8']
        @dns = flexmock(RightSupport::Net::DNS)
        @rb = RightSupport::Net::RequestBalancer.new(@endpoints, :resolve => 15)
      end

      it 'resolves ip addresses for specified list of endpoints' do
        @dns.should_receive(:resolve_all_ip_addresses).with(@endpoints).once.and_return(@resolved_set_1)
        @rb.request { true }
        @policy = @rb.instance_variable_get("@policy")
        @resolved_set_1.include?(@policy.next.first).should be_true
      end

      it 're-resolves list of ip addresses if TTL is expired' do
        @dns.should_receive(:resolve_all_ip_addresses).with(@endpoints).twice.and_return(@resolved_set_1, @resolved_set_2)
        @rb.request { true }
        @policy = @rb.instance_variable_get("@policy")
        @resolved_set_1.include?(@policy.next.first).should be_true

        @rb.instance_variable_set("@resolved_at", Time.now.to_i - 16)
        @rb.request { true }
        @policy = @rb.instance_variable_get("@policy")
        @resolved_set_2.include?(@policy.next.first).should be_true
      end
    end
  end

  context :get_stats do
    context 'using default balancing profile' do
      it 'returns stats in an endpoint-keyed hash' do
        expected_hash = {}
        list = [1,2,3,4]
        list.each { |k| expected_hash[k] = 'n/a' }
        rb = RightSupport::Net::RequestBalancer.new(list)

        rb.get_stats.should_not be_nil
        rb.get_stats.should == expected_hash
      end
    end

    context 'using health check balancing profile' do
      it 'returns stats in an endpoint-keyed hash' do
        expected_hash = {}
        list = [1,2,3,4]
        rb = RightSupport::Net::RequestBalancer.new(list,
                                                :policy => RightSupport::Net::Balancing::HealthCheck,
                                                :health_check => Proc.new {|endpoint| "HealthCheck passed for #{endpoint}!"})
        rb.get_stats.should_not be_nil
        rb.get_stats.should_not == expected_hash
      end
    end
  end
end
