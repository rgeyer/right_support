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

require 'logger'

module RightSupport::Rack
  # A Rack middleware that allows an arbitrary object to be used as the Rack logger.
  # This is more flexible than Rack's built-in Logger middleware, which always logs
  # to a file-based Logger and doesn't allow you to control anything other than the
  # filename.
  class CustomLogger
    # Initialize an instance of the middleware. For backward compatibility, the order of the
    # logger and level parameters can be switched.
    #
    # === Parameters
    # app(Object):: the inner application or middleware layer; must respond to #call
    # logger(Logger):: (optional) the Logger object to use, defaults to a STDERR logger
    # level(Integer):: (optional) a Logger level-constant (INFO, ERROR) to set the logger to
    #
    def initialize(app, arg1=nil, arg2=nil)
      if arg1.is_a?(Integer)
        level = arg1
      elsif arg1.is_a?(Logger)
        logger = arg1
      end

      if arg2.is_a?(Integer)
        level = arg2
      elsif arg2.is_a?(Logger)
        logger = arg2
      end

      if level
        warn 'Passing a log level is deprecated and will be removed in RightSupport 2.0!'
      end
      unless logger
        warn 'No logger provided; using STDERR. Passing a logger will become mandatory in RightSupport 2.0!'
      end

      @app    = app
      @logger = logger
      @level  = level
    end

    # Add a logger to the Rack environment and call the next middleware.
    #
    # === Parameters
    # env(Hash):: the Rack environment
    #
    # === Return
    # always returns whatever value is returned by the next layer of middleware
    def call(env)
      #emulate the behavior of Rack::CommonLogger middleware, which instantiates a
      #default logger if one has not been provided in the initializer
      unless @logger
        @logger = ::Logger.new(env['rack.errors'] || STDERR)
        @logger.level = @level if @level
      end

      env['rack.logger'] = @logger

      status, header, body = @app.call(env)
      log_exception(env['sinatra.error']) if env['sinatra.error']

      return [status, header, body]
    rescue Exception => e
      log_exception(e)
      raise e
    end

    protected

    def log_exception(e)
      msg = ["#{e.class} - #{e.message}", *e.backtrace].join("\n")
      @logger.error(msg)
    rescue
      #no-op, something is seriously messed up by this point...
    end
  end
end
