require 'time'
require 'date'

module RightSupport::Data
  # Utility module that implements true, lossless Ruby-to-JSON serialization.
  # With a few small exceptions, this module can #dump any Ruby object in your
  # VM, and later #load the exact same object from its serialized representation.
  #
  # This class works by transforming Ruby object graphs into an intermediate
  # representation that consists solely of JSON-clean Ruby objects (String,
  # Integer, ...). This intermediate format is dubbed "JSONish", and it can
  # be transformed to JSON and back without losing data or creating ambiguity.
  #
  # === JSONish Object Representation
  # Most Ruby simple types (String, Integer, Float, true/false/nil) are
  # represented by their corresponding JSON type. However, some JSONish
  # values have special meaning:
  #  * Strings beginning with a ':' represent a Ruby Symbol
  #  * Strings in the ISO 8601 timestamp format represent a Ruby Time
  #
  # To avoid ambiguity due to Ruby Strings that happen to look like a
  # JSONish Time or Symbol, some Strings are "object-escaped," meaning they
  # are represented as a JSON object with _ruby_class:String.
  #
  # Arbitrary Ruby objects are represented as a Hash that contains a special
  # key '_ruby_class'. The other key/value pairs of the hash consist of the
  # object's instance variables. Any object whose state is solely contained
  # in its instance variables is therefore eligible for serialization.
  #
  # JSONish also has special-purpose logic for some Ruby built-ins,
  # allowing them to be serialized even though their state is not contained in
  # instance variables. The following are all serializable built-ins:
  #  * Class
  #  * Module
  #  * String (see below).
  #
  # === Capabilities
  # The serializer can handle any Ruby object that uses instance variables to
  # record state. It cleanly round-trips the following Ruby object types:
  #  * Collections (Hash, Array)
  #  * JSON-clean data (Numeric, String, true, false, nil)
  #  * Symbol
  #  * Time
  #  * Class
  #  * Module
  #
  # === Known Limitations
  # Cannot record the following kinds of state:
  #  * Class variables of objects
  #  * State that lives outside of instance variables, e.g. IO#fileno
  #
  # Cannot cleanly round-trip the following:
  #  * Objects that represent callable code: Proc, Lambda, etc.
  #  * High-precision floating point numbers (due to truncation)
  #  * Times with timezone other than UTC or precision greater than 1 sec
  #  * Hash keys that are anything other than a String (depends on JSON parser)
  #  * Hashes that contain a String key whose value is '_ruby_class'
  module JsonSerializer
    if require_succeeds?('yajl')
      InnerJSON = ::Yajl
    elsif require_succeeds?('oj')
      InnerJSON = ::Oj
    elsif require_succeeds?('json')
      InnerJSON = ::JSON
    else
      InnerJSON = nil
    end unless defined?(InnerJSON)

    # Format string to use when sprintf'ing a JSONish Time
    TIME_FORMAT       = '%4.4d-%2.2d-%2.2dT%2.2d:%2.2d:%2.2dZ'
    # Pattern to match Strings against for object-escaping
    TIME_PATTERN      = /^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})Z$/
    # Special key that means "serialized object"
    CLASS_KEY         = '_ruby_class'
    # Special key used as a pseudo-instance-variable for Class and Module
    CLASS_ESCAPE_KEY  = 'name'
    # Special key used as a pseudo-instance-variable for String
    STRING_ESCAPE_KEY = 'value'

    module_function

    # @param [String] data valid JSON document representing a serialized object
    # @return [Object] unserialized Ruby object
    def load(data)
      jsonish = InnerJSON.load(data)
      jsonish_to_object(jsonish)
    end

    # @param [Object] object any Ruby object
    # @return [String] JSON document representing the serialized object
    def dump(object)
      jsonish = object_to_jsonish(object)
      InnerJSON.dump(jsonish)
    end

    # Given an Object, transform it into a JSONish Ruby structure.
    # @param [Object] object any Ruby object
    # @return [Object] JSONish representation of input object
    def self.object_to_jsonish(object)
      case object
      when String
        if (object =~ /^:/ ) || (object =~ TIME_PATTERN)
          # Strings that look like a Symbol or Time must be object-escaped.
          {CLASS_KEY => String.name,
           STRING_ESCAPE_KEY => object}
        else
          object
        end
      when Fixnum, Float, TrueClass, FalseClass, NilClass
        object
      when Hash
        object.inject({}) do |result, (k, v)|
          result[object_to_jsonish(k)] = object_to_jsonish(v)
          result
        end
      when Array
        object.map { |e| object_to_jsonish(e) }
      when Symbol
        # Ruby Symbol is represented as a string beginning with ':'
        ":#{object}"
      when Time
        # Ruby Time is represented as an ISO 8601 timestamp in UTC timeztone
        utc = object.utc
        TIME_FORMAT % [utc.year, utc.mon, utc.day, utc.hour, utc.min, utc.sec]
      when Class, Module
        # Ruby Class/Module needs special handling - no instance vars
        { CLASS_KEY      => object.class.name,
          CLASS_ESCAPE_KEY => object.name }
      else
        # Generic serialized object; convert to Hash.
        hash = {}
        hash[CLASS_KEY] = object.class.name

        object.instance_variables.each do |var|
          hash[ var[1..-1] ] = object_to_jsonish(object.instance_variable_get(var))
        end

        hash
      end
    end

    # Given a JSONish structure, transform it back to a Ruby object.
    # @param [Object] jsonish JSONish Ruby structure
    # @return [Object] unserialized Ruby object
    def self.jsonish_to_object(jsonish)
      case jsonish
      when String
        if jsonish =~ /^:/
          # JSONish Symbol
          jsonish[1..-1].to_sym
        elsif TIME_PATTERN.match(jsonish)
          # JSONish Time
          Time.parse(jsonish)
        else
          # Normal String
          jsonish
        end
      when Fixnum, Float, TrueClass, FalseClass, NilClass
        jsonish
      when Hash
        if jsonish.key?(CLASS_KEY) # We have a serialized Ruby object!
          hash   = jsonish
          klass  = hash.delete(CLASS_KEY)
          case klass
          when Class.name, Module.name
            # Serialized instance of Ruby Class or Module
            jsonish = hash.delete(CLASS_ESCAPE_KEY).to_const
          when String.name
            # Object-escaped Ruby String
            jsonish = String.new(hash.delete(STRING_ESCAPE_KEY))
          when Time.name
            # Object-escaped Ruby String
            jsonish = Time.at(hash.delete(TIME_ESCAPE_KEY))
          else
            # Generic serialized object
            klass = klass.to_const
            jsonish = klass.allocate
            hash.each_pair do |k, v|
              jsonish.instance_variable_set("@#{k}", jsonish_to_object(v))
            end
          end

          jsonish
        else # We have a plain old Ruby Hash
          jsonish.inject({}) do |result, (k, v)|
            result[jsonish_to_object(k)] = jsonish_to_object(v)
            result
          end
        end
      when Array
        jsonish.map { |e| jsonish_to_object(e) }
      else
        raise ArgumentError, "Non-JSONish object of type '#{jsonish.class}'"
      end
    end
  end
end
