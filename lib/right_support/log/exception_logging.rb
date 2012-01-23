require 'logger'

module RightSupport::Log
  # A mixin for Ruby's built-in Logger class that provides some additional functionality that is
  # widely used by RightScale.
  module ExceptionLogging
    # Log information about an exception. The information is logged with ERROR severity.
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
      error(format_exception(description, exception, backtrace))
    end

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
    def format_exception(description, exception = nil, backtrace = :caller)
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
  end
end

class ::Logger
  include RightSupport::Log::ExceptionLogging
end