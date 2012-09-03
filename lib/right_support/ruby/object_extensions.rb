module RightSupport::Ruby
  module ObjectExtensions
    # Attempt to require one or more source files.
    #
    # This method is useful to conditionally define code depending on the availability
    # of gems or standard-library source files.
    #
    # === Parameters
    # Forwards all parameters transparently through to Kernel#require.
    #
    # === Return
    # Returns true or false
    def require_succeeds?(*args)
      require(*args)
      return true
    rescue LoadError => e
      return false
    end
  end
end

class Object
  include RightSupport::Ruby::ObjectExtensions
end
