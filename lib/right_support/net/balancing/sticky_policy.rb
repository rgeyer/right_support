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

module RightSupport::Net::LB

  # Implementation concepts: Create a policy that selects an endpoint and sticks with it.
  #
  # The policy should:
  # - iterate through each endpoint until a valid endpoint is found;
  # - continue returning the same endpoint until it is no longer valid;
  # - re-iterate through each endpoint when it's endpoint loses validity;
  # - return an Exception if it performs a complete iteration though each endpoint and finds none valid;

  class Sticky

    def initialize(options = {})
      @health_check = options.delete(:health_check)
      @endpoints = []
      @counter = rand(0xffff)
    end

    def set_endpoints(endpoints)
      unless @endpoints.empty?
        last_chosen = self.next.first
        @endpoints = []
        if endpoints.include?(last_chosen)
          @endpoints << last_chosen
          @counter = 0
        end
      end
      @endpoints |= endpoints
    end

    def next
      [ @endpoints[@counter % @endpoints.size], true ] unless @endpoints.empty?
    end

    def good(endpoint, t0, t1)
      #no-op; round robin does not care about failures
    end

    def bad(endpoint, t0, t1)
      @counter += 1
    end

    def health_check(endpoint)
      t0 = Time.now
      result = @health_check.call(endpoint)
      t1 = Time.now
      if result
        return true
      else
        @counter += 1
        return false
      end
    rescue Exception => e
      t1 = Time.now
      @counter += 1
      raise e
    end

  end
end
