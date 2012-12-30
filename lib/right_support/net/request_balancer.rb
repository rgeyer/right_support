module RightSupport::Net
  # Raised to indicate the (uncommon) error condition where a RequestBalancer rotated
  # through EVERY URL in a list without getting a non-nil, non-timeout response.
  #
  # If the NoResult was due to a series of errors, then the #details attribute
  # of this exception will let you access detailed information about the errors encountered
  # while retrying the network request. #details is a Hash, the keys of which are endpoints,
  # and the values of which are arrays of exceptions that we encountered while making
  # requests to that endpoint.
  class NoResult < Exception
    # @return [Hash] a map of {endpoint => [exception_1, exception2, ...], ...}
    attr_reader :details

    def initialize(message, details={})
      super(message)
      @details = details
    end
  end

  # Utility class that allows network requests to be randomly distributed across
  # a set of network endpoints. Generally used for REST requests by passing an
  # Array of HTTP service endpoint URLs.
  #
  # Note that this class also serves as a namespace for endpoint selection policies,
  # which are classes that actually choose the next endpoint based on some criterion
  # (round-robin, health of endpoint, response time, etc).
  #
  # The balancer does not actually perform requests by itself, which makes this
  # class usable for various network protocols, and potentially even for non-
  # networking purposes. The block passed to #request does all the work; the
  # balancer merely selects a suitable endpoint to pass to its block.
  #
  # PLEASE NOTE that it is VERY IMPORTANT that the balancer is able to properly
  # distinguish between fatal and non-fatal (retryable) errors. Before you pass
  # a :fatal option to the RequestBalancer constructor, carefully examine its
  # default list of fatal exceptions and default logic for deciding whether a
  # given exception is fatal! There are some subtleties.
  class RequestBalancer
    include RightSupport::Log::Mixin

    DEFAULT_RETRY_PROC = lambda do |ep, n|
      n < ep.size
    end

    # Built-in Ruby exceptions that should be considered fatal. Normally one would be
    # inclined to simply say RuntimeError or StandardError, but because gem authors
    # frequently make unwise choices of exception base class, including these top-level
    # base classes could cause us to falsely think that retryable exceptions are fatal.
    #
    # A good example of this phenomenon is the rest-client gem, whose base exception
    # class is derived from RuntimeError!!
    DEFAULT_FATAL_EXCEPTIONS = [
      NoMemoryError, SystemStackError, SignalException, SystemExit,
      ScriptError,
      # Subclasses of StandardError. We can't include the base class directly as
      # a fatal exception, because there are some retryable exceptions that derive
      # from StandardError.
      ArgumentError, IndexError, LocalJumpError, NameError, RangeError,
      RegexpError, ThreadError, TypeError, ZeroDivisionError
    ]

    # As a kindness to unit test authors, count RSpec exceptions as fatal. Use some
    # reflection to handle ALL RSpec-related exceptions.
    spec_namespaces = if require_succeeds?('rspec')
      # RSpec 2.x
      [::RSpec::Mocks, ::RSpec::Expectations]
    elsif require_succeeds?('spec')
      # RSpec 1.x
      [::Spec::Expectations]
    else
      # RSpec is not present
      []
    end
    spec_namespaces.each do |namespace|
      namespace.constants.each do |konst|
        konst = namespace.const_get(konst)
        if konst.is_a?(Class) && konst.ancestors.include?(Exception)
          DEFAULT_FATAL_EXCEPTIONS << konst
        end
      end
    end

    DEFAULT_FATAL_PROC = lambda do |e|
      if DEFAULT_FATAL_EXCEPTIONS.any? { |c| e.is_a?(c) }
        #Some Ruby builtin exceptions indicate program errors
        true
      elsif e.respond_to?(:http_code) && (e.http_code != nil)
        #RestClient's exceptions all respond to http_code, allowing us
        #to decide based on the HTTP response code.
        #Any HTTP 4xx code EXCEPT 408 (Request Timeout) counts as fatal.
        (e.http_code >= 400 && e.http_code < 500) && (e.http_code != 408)
      else
        #Anything else counts as non-fatal
        false
      end
    end

    DEFAULT_HEALTH_CHECK_PROC = Proc.new do |endpoint|
      true
    end

    DEFAULT_OPTIONS = {
        :policy       => nil,
        :retry        => DEFAULT_RETRY_PROC,
        :fatal        => DEFAULT_FATAL_PROC,
        :on_exception => nil,
        :health_check => DEFAULT_HEALTH_CHECK_PROC
    }

    def self.request(endpoints, options={}, &block)
      new(endpoints, options).request(&block)
    end

    def resolve(endpoints)
      endpoints = RightSupport::Net::DNS.resolve(endpoints)
      @resolved_at = Time.now.to_i
      endpoints
    end

    def expired?
      @options[:resolve] && Time.now.to_i - @resolved_at > @options[:resolve]
    end

    # Constructor. Accepts a sequence of request endpoints which it shuffles randomly at
    # creation time; however, the ordering of the endpoints does not change thereafter
    # and the sequence is tried from the beginning for every request.
    #
    # === Parameters
    # endpoints(Array):: a set of network endpoints (e.g. HTTP URLs) to be load-balanced
    #
    # === Options
    # retry:: a Class, array of Class or decision Proc to determine whether to keep retrying; default is to try all endpoints
    # fatal:: a Class, array of Class, or decision Proc to determine whether an exception is fatal and should not be retried
    # on_exception(Proc):: notification hook that accepts three arguments: whether the exception is fatal, the exception itself,
    #   and the endpoint for which the exception happened
    # health_check(Proc):: callback that allows balancer to check an endpoint health; should raise an exception if the endpoint
    #   is not healthy
    # on_health_change(Proc):: callback that is made when the overall health of the endpoints transition to a different level;
    #   its single argument contains the new minimum health level
    #
    def initialize(endpoints, options={})
      @options = DEFAULT_OPTIONS.merge(options)

      unless endpoints && !endpoints.empty?
        raise ArgumentError, "Must specify at least one endpoint"
      end

      @options[:policy] ||= RightSupport::Net::LB::RoundRobin
      @policy = @options[:policy]
      @policy = @policy.new(options) if @policy.is_a?(Class)

      unless test_policy_duck_type(@policy)
        raise ArgumentError, ":policy must be a class/object that responds to :next, :good and :bad"
      end

      unless test_callable_arity(options[:retry], 2)
        raise ArgumentError, ":retry callback must accept two parameters"
      end

      unless test_callable_arity(options[:fatal], 1)
        raise ArgumentError, ":fatal callback must accept one parameter"
      end

      unless test_callable_arity(options[:on_exception], 3, false)
        raise ArgumentError, ":on_exception callback must accept three parameters"
      end

      unless test_callable_arity(options[:health_check], 1, false)
        raise ArgumentError, ":health_check callback must accept one parameter"
      end

      unless test_callable_arity(options[:on_health_change], 1, false)
        raise ArgumentError, ":on_health_change callback must accept one parameter"
      end

      @endpoints = endpoints

      if @options[:resolve]
        @resolved_at = 0
      else
        @policy.set_endpoints(@endpoints)
      end
    end

    # Perform a request.
    #
    # === Block
    # This method requires a block, to which it yields in order to perform the actual network
    # request. If the block raises an exception or provides nil, the balancer proceeds to try
    # the next URL in the list.
    #
    # === Raise
    # ArgumentError:: if a block isn't supplied
    # NoResult:: if *every* URL in the list times out or returns nil
    #
    # === Return
    # Return the first non-nil value provided by the block.
    def request
      raise ArgumentError, "Must call this method with a block" unless block_given?
      if self.expired?
        @ips = self.resolve(@endpoints)
        @policy.set_endpoints(@ips)
      end

      exceptions = {}
      result     = nil
      complete   = false
      n          = 0

      loop do
        if n > 0
          do_retry = @options[:retry] || DEFAULT_RETRY_PROC
          do_retry = do_retry.call(@ips || @endpoints, n) if do_retry.respond_to?(:call)
          break if (do_retry.is_a?(Integer) && n >= do_retry) || [nil, false].include?(do_retry)
        end

        endpoint, need_health_check  = @policy.next
        break unless endpoint

        n += 1
        t0 = Time.now

        # Perform health check if necessary. Note that we guard this with a rescue, because the
        # health check may raise an exception and we want to log the exception info if this happens.
        if need_health_check
          begin
            unless @policy.health_check(endpoint)
              logger.error "RequestBalancer: health check failed to #{endpoint} because of non-true return value"
              next
            end
          rescue Exception => e
            logger.error "RequestBalancer: health check failed to #{endpoint} because of #{e.class.name}: #{e.message}"
            next
          end

          logger.info "RequestBalancer: health check succeeded to #{endpoint}"
        end

        begin
          result   = yield(endpoint)
          @policy.good(endpoint, t0, Time.now)
          complete = true
          break
        rescue Exception => e
          if to_raise = handle_exception(endpoint, e, t0)
            raise(to_raise)
          else
            @policy.bad(endpoint, t0, Time.now)
            exceptions[endpoint] ||= []
            exceptions[endpoint] << e
          end
        end

      end

      return result if complete

      # Produce a summary message for the exception that gives a bit of detail
      msg = [] 
      exceptions.each_pair do |endpoint, list|
        summary = []
        list.each { |e| summary << e.class }
        msg << "'#{endpoint}' => [#{summary.uniq.join(', ')}]"
      end
      message = "Request failed after #{n} tries to #{exceptions.keys.size} endpoints: (#{msg.join(', ')})"

      logger.error "RequestBalancer: #{message}"
      raise NoResult.new(message, exceptions)
    end

    # Provide an interface so one can query the RequestBalancer for statistics on
    # its endpoints.  Merely proxies the balancing policy's get_stats method. If
    # no method exists in the balancing policy, a hash of endpoints with "n/a" is
    # returned.
    # 
    # Examples
    #
    # A RequestBalancer created with endpoints [1,2,3,4,5] and using a HealthCheck
    # balancing policy may return:
    #
    # {5 => "yellow-3", 1 => "red", 2 => "yellow-1", 3 => "green", 4 => "yellow-2"}
    #
    # A RequestBalancer created with endpoints [1,2,3,4,5] and specifying no
    # balancing policy or using the default RoundRobin balancing policy may return:
    #
    # {2 => "n/a", 1 => "n/a", 3 => "n/a"}
    def get_stats
      stats = {}
      @endpoints.each { |endpoint| stats[endpoint] = 'n/a' }
      stats = @policy.get_stats if @policy.respond_to?(:get_stats)
      stats
    end

    protected

    # Decide what to do with an exception. The decision is influenced by the :fatal
    # option passed to the constructor.
    def handle_exception(endpoint, e, t0)
      fatal = @options[:fatal] || DEFAULT_FATAL_PROC

      #The option may be a proc or lambda; call it to get input
      fatal = fatal.call(e) if fatal.respond_to?(:call)

      #The options may be single exception classes, in which case we want to expand
      #it out into a list
      fatal = [fatal] if fatal.is_a?(Class)

      #The option may be a list of exception classes, in which case we want to evaluate
      #whether the exception we're handling is an instance of any mentioned exception
      #class
      fatal = fatal.any?{ |c| e.is_a?(c) } if fatal.respond_to?(:any?)
      duration = sprintf('%.4f', Time.now - t0)
      msg = "RequestBalancer: rescued #{fatal ? 'fatal' : 'retryable'} #{e.class.name} during request to #{endpoint}: #{e.message} after #{duration} seconds"
      logger.error msg
      @options[:on_exception].call(fatal, e, endpoint) if @options[:on_exception]

      if fatal
        #Final decision: did we identify it as fatal?
        return e
      else
        return nil
      end
    end

    def test_policy_duck_type(object)
      [:next, :good, :bad].all? { |m| object.respond_to?(m) }
    end

    # Test that something is a callable (Proc, Lambda or similar) with the expected arity.
    # Used mainly by the initializer to test for correct options.
    def test_callable_arity(callable, arity, optional=true)
      return true if callable.nil?
      return true if optional && !callable.respond_to?(:call)
      return callable.respond_to?(:arity) && (callable.arity == arity)
    end
  end # RequestBalancer

end # RightScale
