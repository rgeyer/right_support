# Copyright (c) 2009-2012 RightScale Inc
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

module RightSupport::Stats
  
  # Track statistics for a given kind of activity
  class Activity

    # Number of samples included when calculating average recent activity
    # with the smoothing formula A = ((A * (RECENT_SIZE - 1)) + V) / RECENT_SIZE,
    # where A is the current recent average and V is the new activity value
    # As a rough guide, it takes approximately 2 * RECENT_SIZE activity values
    # at value V for average A to reach 90% of the original difference between A and V
    # For example, for A = 0, V = 1, RECENT_SIZE = 3 the progression for A is
    # 0, 0.3, 0.5, 0.7, 0.8, 0.86, 0.91, 0.94, 0.96, 0.97, 0.98, 0.99, ...
    RECENT_SIZE = 3

    # Maximum string length for activity type
    MAX_TYPE_SIZE = 60

    # (Integer) Total activity count
    attr_reader :total

    # (Hash) Count of activity per type
    attr_reader :count_per_type

    # Initialize activity data
    #
    # === Parameters
    # measure_rate(Boolean):: Whether to measure activity rate
    def initialize(measure_rate = true)
      @measure_rate = measure_rate
      reset
    end

    # Reset statistics
    #
    # === Return
    # true:: Always return true
    def reset
      @interval = 0.0
      @last_start_time = Time.now
      @avg_duration = nil
      @total = 0
      @count_per_type = {}
      @last_type = nil
      @last_id = nil
      true
    end

    # Mark the start of an activity and update counts and average rate
    # with weighting toward recent activity
    # Ignore the update if its type contains "stats"
    #
    # === Parameters
    # type(String|Symbol):: Type of activity, with anything that is not a symbol, true, or false
    #   automatically converted to a String and truncated to MAX_TYPE_SIZE characters,
    #   defaults to nil
    # id(String):: Unique identifier associated with this activity
    #
    # === Return
    # now(Time):: Update time
    def update(type = nil, id = nil)
      now = Time.now
      if type.nil? || !(type =~ /stats/)
        @interval = average(@interval, now - @last_start_time) if @measure_rate
        @last_start_time = now
        @total += 1
        unless type.nil?
          unless [Symbol, TrueClass, FalseClass].include?(type.class)
            type = type.inspect unless type.is_a?(String)
            type = type[0, MAX_TYPE_SIZE - 3] + "..." if type.size > (MAX_TYPE_SIZE - 3)
          end
          @count_per_type[type] = (@count_per_type[type] || 0) + 1
        end
        @last_type = type
        @last_id = id
      end
      now
    end

    # Mark the finish of an activity and update the average duration
    #
    # === Parameters
    # start_time(Time):: Time when activity started, defaults to last time update was called
    # id(String):: Unique identifier associated with this activity
    #
    # === Return
    # duration(Float):: Activity duration in seconds
    def finish(start_time = nil, id = nil)
      now = Time.now
      start_time ||= @last_start_time
      duration = now - start_time
      @avg_duration = average(@avg_duration || 0.0, duration)
      @last_id = 0 if id && id == @last_id
      duration
    end

    # Convert average interval to average rate
    #
    # === Return
    # (Float|nil):: Recent average rate, or nil if total is 0
    def avg_rate
      if @total > 0
        if @interval == 0.0 then 0.0 else 1.0 / @interval end
      end
    end


    # Get average duration of activity
    #
    # === Return
    # (Float|nil) Average duration in seconds of activity weighted toward recent activity, or nil if total is 0
    def avg_duration
      @avg_duration if @total > 0
    end

    # Get stats about last activity
    #
    # === Return
    # (Hash|nil):: Information about last activity, or nil if the total is 0
    #   "elapsed"(Integer):: Seconds since last activity started
    #   "type"(String):: Type of activity if specified, otherwise omitted
    #   "active"(Boolean):: Whether activity still active
    def last
      if @total > 0
        result = {"elapsed" => (Time.now - @last_start_time).to_i}
        result["type"] = @last_type if @last_type
        result["active"] = @last_id != 0 if !@last_id.nil?
        result
      end
    end

    # Convert count per type into percentage by type
    #
    # === Return
    # (Hash|nil):: Converted counts, or nil if total is 0
    #   "total"(Integer):: Total activity count
    #   "percent"(Hash):: Percentage for each type of activity if tracking type, otherwise omitted
    def percentage
      if @total > 0
        percent = {}
        @count_per_type.each { |k, v| percent[k] = (v / @total.to_f) * 100.0 }
        {"percent" => percent, "total" => @total}
      end
    end

    # Get stat summary including all aspects of activity that were measured except duration
    #
    # === Return
    # (Hash|nil):: Information about activity, or nil if the total is 0
    #   "total"(Integer):: Total activity count
    #   "percent"(Hash):: Percentage for each type of activity if tracking type, otherwise omitted
    #   "last"(Hash):: Information about last activity
    #     "elapsed"(Integer):: Seconds since last activity started
    #     "type"(String):: Type of activity if tracking type, otherwise omitted
    #     "active"(Boolean):: Whether activity still active if tracking whether active, otherwise omitted
    #   "rate"(Float):: Recent average rate if measuring rate, otherwise omitted
    def all
      if @total > 0
        result = if @count_per_type.empty?
          {"total" => @total}
        else
          percentage
        end
        result.merge!("last" => last)
        result.merge!("rate" => avg_rate) if @measure_rate
        result
      end
    end

    protected

    # Calculate smoothed average with weighting toward recent activity
    #
    # === Parameters
    # current(Float|Integer):: Current average value
    # value(Float|Integer):: New value
    #
    # === Return
    # (Float):: New average
    def average(current, value)
      ((current * (RECENT_SIZE - 1)) + value) / RECENT_SIZE.to_f
    end

  end # Activity

end # RightScale::Stats
