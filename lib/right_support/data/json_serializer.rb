module RightSupport::Data
  # Utility module that implements true, lossless Ruby-to-JSON serialization.
  # With a few small exceptions, this module can #dump any Ruby object in your
  # VM, and later #load the exact same object from its serialized representation.
  #
  # === Capabilities
  # The serializer can handle any Ruby object that uses instance variables to
  # record state. It cleanly round-trips the following "JSONish" object types:
  #  * JSON primitives (Numeric, String, true, false, nil)
  #  * JSON collections (Hash, Array)
  #  * Symbol
  #  * Time
  #
  # To represent Symbol and Time, we use a human-readable string format.
  # When Ruby Strings happen to look like a Symbol, Time or escaped
  # String, their serialized representation is prefixed with an escape
  # character in order to prevent ambiguity.
  #
  # Non-JSONish objects are represented as a Hash that contains a special
  # key '_ruby_class'. The other key/value pairs of the hash consist of
  # instance variables.
  #
  # === Known Limitations
  # Cannot record the following kinds of state:
  #  * Class variables of objects
  #  * State that lives outside of instance variables, e.g. IO#fileno
  #
  # Cannot cleanly round-trip the following:
  #  * Objects that represent callable code: Proc, Lambda, etc.
  #  * Hash keys that are themselves a Hash or Array (depends on JSON parser)
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

    TIME_FORMAT    = '%Y-%m-%d %H:%M:%S %z'
    TIME_PATTERN   = /\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}( [+-]\d{1,5})?/
    CLASS_KEY      = '_ruby_class'
    CLASS_NAME_KEY = 'name'
    ESCAPE         = '\\\\'

    module_function

    def load(data)
      jsonish = InnerJSON.load(data)
      jsonish_to_object(jsonish)
    end

    def dump(object)
      jsonish = object_to_jsonish(object)
      InnerJSON.dump(jsonish)
    end

    protected

    # Given an Object, transform it into a JSONish
    def self.object_to_jsonish(object)
      case object
      when String
        if (object =~ /^[#{ESCAPE}:]/) || (object =~ TIME_PATTERN)
          # Strings that look like a Symbol, escaped String or Time, must be escaped!
          "#{ESCAPE}#{object}"
        else
          object
        end
      when Symbol
        ":#{object}"
      when Numeric, TrueClass, FalseClass, NilClass
        object
      when Array
        object.map { |e| object_to_jsonish(e) }
      when Hash
        object.inject({}) do |result, (k, v)|
          result[object_to_jsonish(k)] = object_to_jsonish(v)
          result
        end
      when Time
        object.strftime(TIME_FORMAT)
      when Class
        # Ruby class object; special handling (no instance vars)
        { CLASS_KEY      => Class.name,
          CLASS_NAME_KEY => object.name }
      when Module
        # Ruby module object; special handling (no instance vars)
        { CLASS_KEY      => Module.name,
          CLASS_NAME_KEY => object.name }
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

    # Given a JSONish, transform it into the equivalent Ruby object
    def self.jsonish_to_object(object)
      case object
      when String
        if object =~ /^#{ESCAPE}/
          # Remove escaping from Strings
          object[1..-1]
        elsif object =~ /^:/
          object[1..-1].to_sym
        elsif object =~ TIME_PATTERN
          Time.parse(object)
        else
          object
        end
      when Numeric, TrueClass, FalseClass, NilClass
        object
      when Array
        object.map { |e| jsonish_to_object(e) }
      when Hash
        if object.key?(CLASS_KEY)
          hash   = object
          klass  = hash.delete(CLASS_KEY)
          case klass
          when Class.name, Module.name
            # Serialized instance of Ruby class or module
            object = object.delete(CLASS_NAME_KEY).to_const
          else
            # Generic serialized object
            klass = klass.to_const
            object = klass.allocate
            hash.each_pair do |k, v|
              object.instance_variable_set("@#{k}", jsonish_to_object(v))
            end
          end

          object
        else
          object.inject({}) do |result, (k, v)|
            result[jsonish_to_object(k)] = jsonish_to_object(v)
            result
          end
        end
      else
        raise ArgumentError, "Non-JSONish class: #{object.class}"
      end
    end
  end
end
