#
# Copyright (c) 2011 RightScale Inc
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

require 'set'

module RightSupport::Net::LB

  # TODO refactor this class. We store too much unstructured data about EPs; should have a simple
  # class representing EP state, and then perhaps move what logic remains into the HealthCheck class
  # instead of putting it here.
  class EndpointsStack
    DEFAULT_YELLOW_STATES = 4
    DEFAULT_RESET_TIME    = 60
    INITIAL_N_LEVEL       = 1

    def initialize(policy, endpoints, yellow_states=nil, reset_time=nil, on_health_change=nil)
      @policy = policy
      @endpoints = Hash.new
      @yellow_states = yellow_states || DEFAULT_YELLOW_STATES
      @reset_time = reset_time || DEFAULT_RESET_TIME
      @on_health_change = on_health_change
      @min_n_level = 0
      endpoints.each { |ep| @endpoints[ep] = {:n_level => INITIAL_N_LEVEL, :timestamp => 0} }
    end

    def inspect
      "<#{self.class.name}: #{get_stats.inspect}>"
    end

    def to_s
      inspect
    end

    def sweep
      @endpoints.each { |k,v| decrease_state(k, 0, Time.now) if Float(Time.now - v[:timestamp]) > @reset_time }
    end

    def sweep_and_return_yellow_and_green
      sweep
      @endpoints.select { |k,v| v[:n_level] < @yellow_states }
    end

    def decrease_state(endpoint, t0, t1)
      update_state(endpoint, -1, t1) unless @endpoints[endpoint][:n_level] == 0
    end

    def increase_state(endpoint, t0, t1)
      update_state(endpoint, 1, t1) unless @endpoints[endpoint][:n_level] == @yellow_states
    end

    def update_state(endpoint, change, t1)
      @endpoints[endpoint][:timestamp] = t1
      n_level = @endpoints[endpoint][:n_level] += change
      logger.info("RequestBalancer: Health of endpoint '#{endpoint}' #{change < 0 ? 'improved' : 'worsened'} to '#{state_color(n_level)}'")
      if @on_health_change &&
         (n_level < @min_n_level ||
         (n_level > @min_n_level && n_level == @endpoints.map { |(k, v)| v[:n_level] }.min))
        @min_n_level = n_level
        @on_health_change.call(state_color(n_level))
      end
    end

    def state_color(n_level)
      color = 'green' if n_level == 0
      color = 'red' if n_level >= @yellow_states
      color = "yellow-#{n_level}" if n_level > 0 && n_level < @yellow_states
      color
    end

    # Returns a hash of endpoints and their colored health status
    # Useful for logging and debugging
    def get_stats
      stats = {}
      @endpoints.each { |k, v| stats[k] = state_color(v[:n_level]) }
      stats
    end

    # Replace the set of endpoints that this object knows about. If any
    # endpoint in the new set is already being tracked, remember its
    # health. For any new endpoint, set its health to INITIAL_N_LEVEL.

    def update!(new_endpoints)
      new_endpoints = new_endpoints.dup # duplicate the array, so we don't modify the passed one.
      @endpoints.each { |k,v| new_endpoints.include?(k) ? new_endpoints.delete(k) : @endpoints.delete(k) }
      new_endpoints.each  { |ep| @endpoints[ep] = {:n_level => INITIAL_N_LEVEL, :timestamp => 0} }
    end

    # Return the logger that our surrounding policy uses
    def logger
      @policy.logger
    end
  end
  # has several levels (@yellow_states) to determine the health of the endpoint. The
  # balancer works by avoiding "red" endpoints and retrying them after awhile.  Here is a
  #    * on success: remain green
  #    * on failure: change state to yellow and set it's health to healthiest (1)
  # * red: skip this server
  #    * after @reset_time passes change state to yellow and set it's health to
  #      sickest (@yellow_states)
  # * yellow: last request was either successful or failed
  #    * on success: change state to green if it's health was healthiest (1), else
  #      retain yellow state and improve it's health
  #    * on failure: change state to red if it's health was sickest (@yellow_states), else
  #      retain yellow state and decrease it's health
  # A callback option is provided to receive notification of changes in the overall
  # health of the endpoints. The overall health starts out green. When the last
  # endpoint transitions from green to yellow, a callback is made to report the overall
  # health as yellow (or level of yellow). When the last endpoint transitions from yellow
  # to red, a callback is made to report the transition to red. Similarly transitions are
  # reported on the way back down, e.g., yellow is reported as soon as the first endpoint
  # transitions from red to yellow, and so on.

  class HealthCheck
    include RightSupport::Log::Mixin

    def initialize(options = {})
      @options = options
    end

    def set_endpoints(endpoints)
      if @stack
        @stack.update!(endpoints)
      else
        @health_check = @options.delete(:health_check)
        @counter = Process.pid
        @last_size = endpoints.size
        @stack = EndpointsStack.new(self, endpoints, @options[:yellow_states], @options[:reset_time], @options[:on_health_change])
      end
    end

    def next
      # Returns the array of hashes which consists of yellow and green endpoints with the
      # following structure: [ [EP1, {:n_level => ..., :timestamp => ... }], [EP2, ... ] ]
      endpoints = @stack.sweep_and_return_yellow_and_green
      return nil if endpoints.empty?

      # From the available set, use a RoundRobin-like algorithm to select the next endpoint.
      # When the size of the available set changes, try not to disturb our index into the list.
      @counter += 1 unless endpoints.size < @last_size
      @counter %= endpoints.size
      @last_size = endpoints.size

      # Hash#select returns a Hash in ruby1.9, but an Array of pairs in ruby1.8.
      # This should really be encapsulated in EndpointsStack...
      if RUBY_VERSION >= '1.9'
        key = endpoints.keys[@counter]
        next_endpoint = [ key, endpoints[key][:n_level] != 0 ]
      else
        next_endpoint = [ endpoints[@counter][0], endpoints[@counter][1][:n_level] != 0 ]
      end

      next_endpoint
    end

    def good(endpoint, t0, t1)
      @stack.decrease_state(endpoint, t0, t1)
    end

    def bad(endpoint, t0, t1)
      @stack.increase_state(endpoint, t0, t1)
    end

    def health_check(endpoint)
      t0 = Time.now
      result = @health_check.call(endpoint)
      t1 = Time.now
      if result
        @stack.decrease_state(endpoint, t0, t1)
        return true
      else
        @stack.increase_state(endpoint, t0, t1)
        return false
      end
    rescue Exception => e
      t1 = Time.now
      @stack.increase_state(endpoint, t0, t1)
      raise e
    end

    # Proxy to EndpointStack
    def get_stats
      if @stack
        @stack.get_stats
      else
        {}
      end
    end

  end
end
