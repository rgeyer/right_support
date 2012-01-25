#
# Copyright (c) 2012 RightScale Inc
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

module RightSupport::Log
  # A logger that prepends a tag to every message that is emitted. Can be used to
  # correlate logs with a Web session ID, transaction ID or other context.
  #
  # The user of this logger is responsible for calling #tag= to set the tag as
  # appropriate, e.g. in a Web request around-filter.
  #
  # This logger uses thread-local storage (TLS) to provide tagging on a per-thread
  # basis; however, it does not account for EventMachine, neverblock, the use of
  # Ruby fibers, or any other phenomenon that can "hijack" a thread's call stack.
  #
  class ExceptionLogger < FilterLogger
    # Format exception information
    #
    # === Parameters
    # description(String):: Error description
    # exception(Exception|String):: Associated exception or other parenthetical error information
    # backtrace(Symbol):: Exception backtrace extent: :no_trace, :caller, or :trace,
    #   defaults to :caller
    #
    # === Return
    # (String):: Information about the exception in a format suitable for logging
    def self.format_exception(description, exception = nil, backtrace = :caller)
      if exception
        if exception.respond_to?(:message)
          description += " (#{exception.class}: #{exception.message}"
        else
          description += " (#{exception}"
        end

        unless exception.respond_to?(:backtrace) && exception.backtrace
          backtrace = :no_trace
        end

        case backtrace
          when :no_trace
            description += ")"
          when :caller
            description += " in " + exception.backtrace[0] + ")"
          when :trace
            description += " in\n  " + exception.backtrace.join("\n  ") + ")"
          else
            raise ArgumentError, "Unknown backtrace value #{backtrace.inspect}"
        end
      end

      description
    end

    # Log information about an exception. The information is logged with FATAL severity.
    #
    # === Parameters
    # description(String):: Error description
    # exception(Exception|String):: Associated exception or other parenthetical error information
    # backtrace(Symbol):: Exception backtrace extent: :no_trace, :caller, or :trace,
    #   defaults to :caller
    #
    # === Return
    # Forwards the return value of its underlying logger's #error method
    def exception(description, exception = nil, backtrace = :caller)
      fatal(self.class.format_exception(description, exception, backtrace))
    end
  end
end