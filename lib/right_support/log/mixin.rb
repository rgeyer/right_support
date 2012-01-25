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
  # A mixin that facilitates access to a logger for classes that want logging functionality.
  #
  # === Basic Usage
  # Your class must opt into logging by including the mixin:
  #   class AwesomenessProcessor
  #     include RightSupport::Log::Mixin
  #
  # Having opted in, your class now has a #logger instance method, as well as a .logger
  # class method, which allows logging from either instance or class methods:
  #
  #   def self.prepare_awesomeness_for_processing(input)
  #     logger.info "Preparing a #{input.class.name} for additional awesomeness"
  #   end
  #
  #   def process_awesomeness(input)
  #     input = self.class.prepare_awesomeness(input)
  #     logger.info "Processing #{input.size} units of awesomeness"
  #   end
  #
  # === Controlling Where Log Messages Go
  # By default, your class shares a Logger object with all other classes that include the mixin.
  # This process-wide default logger can be set or retrieved using module-level accessors:
  #
  #   # default_logger starts out as a NullLogger; you probably want to set it to something different
  #   puts "Current logger: "+ RightSupport::Log::Mixin.default_logger.class
  #   RightSupport::Log::Mixin.default_logger = SyslogLogger.new('my program')
  #
  # It is good form to set the default logger; however, if your class needs additional or different
  # logging functionality, you can override the logger on a per-class level:
  #   AwesomenessProcessor.logger = Logger.new(File.open('awesomeness.log', 'w'))
  #
  # Finally, you can override the logger on a per-instance level for truly fine-grained control.
  # This is generally useless, but just in case:
  #   processor = AwesomenessProcessor.new
  #   processor.logger = Logger.new(File.open("#{processor.object_id}.log", 'w'))
  #
  module Mixin
    # A decorator class which will be wrapped around any logger that is
    # provided to any of the setter methods. This ensures that ExceptionLogger's
    # methods will always be available to anyone who uses this mixin for logging.
    Decorator = RightSupport::Log::ExceptionLogger

    # Class methods that become available to classes that include Mixin.
    module ClassMethods
      def logger
        @logger || RightSupport::Log::Mixin.default_logger
      end

      def logger=(logger)
        logger = Decorator.new(logger) unless logger.nil? || logger.is_a?(Decorator)
        @logger = logger
      end
    end

    # Instance methods that become available to classes that include Mixin.
    module InstanceMethods
      def logger
        @logger || self.class.logger
      end

      def logger=(logger)
        logger = Decorator.new(logger) unless logger.nil? || logger.is_a?(Decorator)
        @logger = logger
      end
    end

    def self.default_logger
      @default_logger ||= Decorator.new(RightSupport::Log::NullLogger.new)
    end

    def self.default_logger=(logger)
      logger = Decorator.new(logger) unless logger.nil? || logger.is_a?(Decorator)
      @default_logger = logger
    end

    def self.included(base)
      base.extend(ClassMethods)
      base.__send__(:include, InstanceMethods)
    end
  end
end