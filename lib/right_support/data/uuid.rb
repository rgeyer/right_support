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

module RightSupport::Data
  module UUID
    # Exception that indicates a given implementation is unavailable.
    class Unavailable < Exception; end

    # The base class for all UUID implementations. Subclasses must override
    # #initialize such that they raise an exception if the implementation is
    # not available, and #generate such that it returns a String containing
    # a UUID.
    class Implementation
      @subclasses = Set.new

      def self.inherited(klass)
        @subclasses << klass
      end

      # Determine which UUID implementations are available in this Ruby VM.
      #
      # === Return
      # available(Array):: the available implementation classes
      def self.available
        avail = []

        @subclasses.each do |eng|
          begin
            eng.new #if it initializes, it's available!
            avail << eng
          rescue Exception => e
            #must not be available!
          end
        end

        avail
      end

      # Determine the default UUID implementation in this Ruby VM.
      #
      # === Return
      # available(Array):: the available implementation classes
      def self.default
        #completely arbitrary
        available.first
      end

      def generate
        raise Unavailable, "This implementation is currently not available"
      end
    end

    # An implementation that uses the SimpleUUID gem.
    class SimpleUUID < Implementation
      def initialize
        require 'simple_uuid'
        generate
      end

      def generate
        ::SimpleUUID::UUID.new.to_guid
      end
    end

    # An implementation that uses UUIDTools v1.
    class UUIDTools1 < Implementation
      def initialize
        require 'uuidtools'
        generate
      end

      def generate
        ::UUID.timestamp_create.to_s
      end
    end

    # An implementation that uses UUIDTools v2.
    class UUIDTools2 < Implementation
      def initialize
        require 'uuidtools'
        generate
      end

      def generate
        ::UUIDTools::UUID.timestamp_create.to_s
      end
    end

    # An implementation that uses the "uuid" gem.
    class UUIDGem < Implementation
      def initialize
        require 'uuid'
        generate
      end

      def generate
        ::UUID.new.to_s
      end
    end

    module_function

    def generate
      impl = implementation
      raise Unavailable, "No implementation is available" unless impl
      impl.generate
    end

    # Return the implementation that will be used to generate UUIDs.
    #
    # === Return
    # The implementation object.
    #
    # === Raise
    # Unavailable:: if no suitable implementation is available
    #
    def implementation
      return @implementation if @implementation

      if (defl = Implementation.default)
        self.implementation = defl
      else
        raise Unavailable, "No implementation is available"
      end

      @implementation
    end

    # Set the implementation that will be used to generate UUIDs.
    #
    # === Parameters
    # klass(inherits-from Implementation):: the implementation class
    #
    # === Return
    # The class that was passed as a parameter
    #
    # === Raise
    # Unavailable:: if the specified implementation is not available
    # ArgumentError:: if klass is not a subclass of Implementation, or is not available
    #
    def implementation=(klass)
      if klass.is_a?(Implementation)
        @implementation = klass
      elsif klass.is_a?(Class) && klass.ancestors.include?(Implementation)
        @implementation = klass.new
      elsif klass.nil?
        @implementation = nil
      else
        raise ArgumentError, "Expected Implementation instance or subclass, got #{klass}"
      end
    rescue Exception => e
      raise Unavailable, "#{klass} is not available due to a #{e.class}: #{e.message}"
    end
  end
  
end