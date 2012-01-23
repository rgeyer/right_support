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

  # Track statistics for exceptions
  class Exceptions

    include RightSupport::Log::Mixin

    # Maximum number of recent exceptions to track per category
    MAX_RECENT_EXCEPTIONS = 10

    # (Hash) Exceptions raised per category with keys
    #   "total"(Integer):: Total exceptions for this category
    #   "recent"(Array):: Most recent as a hash of "count", "type", "message", "when", and "where"
    attr_reader :stats
    alias :all :stats

    # Initialize exception data
    #
    # === Parameters
    # server(Object):: Server where exceptions are originating, must be defined for callbacks
    # callback(Proc):: Block with following parameters to be activated when an exception occurs
    #   exception(Exception):: Exception
    #   message(Packet):: Message being processed
    #   server(Server):: Server where exception occurred
    def initialize(server = nil, callback = nil)
      @server = server
      @callback = callback
      reset
    end

    # Reset statistics
    #
    # === Return
    # true:: Always return true
    def reset
      @stats = nil
      true
    end

    # Track exception statistics and optionally make callback to report exception
    # Catch any exceptions since this function may be called from within an EM block
    # and an exception here would then derail EM
    #
    # === Parameters
    # category(String):: Exception category
    # exception(Exception):: Exception
    #
    # === Return
    # true:: Always return true
    def track(category, exception, message = nil)
      begin
        @callback.call(exception, message, @server) if @server && @callback && message
        @stats ||= {}
        exceptions = (@stats[category] ||= {"total" => 0, "recent" => []})
        exceptions["total"] += 1
        recent = exceptions["recent"]
        last = recent.last
        if last && last["type"] == exception.class.name && last["message"] == exception.message && last["where"] == exception.backtrace.first
          last["count"] += 1
          last["when"] = Time.now.to_i
        else
          backtrace = exception.backtrace.first if exception.backtrace
          recent.shift if recent.size >= MAX_RECENT_EXCEPTIONS
          recent.push({"count" => 1, "when" => Time.now.to_i, "type" => exception.class.name,
                       "message" => exception.message, "where" => backtrace})
        end
      rescue Exception => e
        logger.exception("Failed to track exception '#{exception}'", e, :trace) rescue nil
      end
      true
    end

  end # Exceptions

end # RightSupport::Stats
