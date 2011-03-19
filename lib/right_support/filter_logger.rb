module RightSupport
  class FilterLogger < Logger
    def initialize(actual_logger)
      @actual_logger = actual_logger

    end

    def add(severity, message = nil, progname = nil, &block)
      severity ||= UNKNOWN
      return true if severity < level

      if message.nil?
        if block_given?
          message = yield
        else
          message = progname
        end
      end

      message = filter(severity, message)
      return @actual_logger.add(severity, message) if message
    end

    def <<(msg)
      @actual_logger << msg
    end

    def close
      @actual_logger.close
    end

    def level
      @actual_logger.level
    end

    def level=(new_level)
      @actual_logger.level = new_level
    end

    # Returns +true+ iff the current severity level allows for the printing of
    # +DEBUG+ messages.
    def debug?; @actual_logger.debug?; end

    # Returns +true+ iff the current severity level allows for the printing of
    # +INFO+ messages.
    def info?; @actual_logger.info?; end

    # Returns +true+ iff the current severity level allows for the printing of
    # +WARN+ messages.
    def warn?; @actual_logger.warn?; end

    # Returns +true+ iff the current severity level allows for the printing of
    # +ERROR+ messages.
    def error?; @actual_logger.error?; end

    # Returns +true+ iff the current severity level allows for the printing of
    # +FATAL+ messages.
    def fatal?; @actual_logger.fatal?; end

    protected

    def filter(severity, message)
      message
    end
  end
end