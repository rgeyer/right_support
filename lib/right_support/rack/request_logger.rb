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

require 'logger'

module RightSupport::Rack
  # A Rack middleware that logs information about every HTTP request received and
  # every exception raised while processing a request.
  #
  # The middleware can be configured to use its own logger, but defaults to using
  # env['rack.logger'] for logging if it is present. If 'rack.logger' is not set,
  # this middleware will set it before calling the next middleware. Therefore,
  # RequestLogger can be used standalone to fulfill all logging needs, or combined
  # with Rack::Logger or another middleware that provides logging services.
  class RequestLogger
    # Initialize an instance of the middleware.
    #
    # === Parameters
    # app(Object):: the inner application or middleware layer; must respond to #call
    #
    def initialize(app)
      @app = app
    end

    # Add a logger to the Rack environment and call the next middleware.
    #
    # === Parameters
    # env(Hash):: the Rack environment
    #
    # === Return
    # always returns whatever value is returned by the next layer of middleware
    def call(env)
      logger = env["rack.logger"]

      began_at = Time.now

      log_request_begin(logger, env)
      status, header, body = @app.call(env)
      log_exception(logger, env['sinatra.error']) if env['sinatra.error']
      log_request_end(logger, status, header, began_at)

      return [status, header, body]
    rescue Exception => e
      log_exception(logger, e)
      raise e
    end

    private

    # Log beginning of request
    #
    # === Parameters
    # logger(Object):: the Rack logger
    # env(Hash):: the Rack environment
    #
    # === Return
    # always returns true
    def log_request_begin(logger, env)
      # Assuming remote addresses are IPv4, make them all align to the same width
      remote_addr = env['HTTP_X_FORWARDED_FOR'] || env["REMOTE_ADDR"] || "-"
      remote_addr = remote_addr.ljust(15)

      # Log the fact that a query string was present, but do not log its contents
      # because it may have sensitive data.
      if (query = env["QUERY_STRING"]) && !query.empty?
        query_info = '?...'
      else
        query_info = ''
      end

      # Session
      if env['global_session']
        cookie = env['global_session']
        info = [ env['global_session'].id,
                 cookie.keys.map{|k| %{"#{k}"=>"#{cookie[k]}"} }.join(', ') ]
        sess = %Q{Session ID: %s  Session Data: {%s}} % info
      else
        sess = ""
      end

      params = [
        env["REQUEST_METHOD"],
        env["PATH_INFO"],
        query_info,
        remote_addr,
        sess,
        env["rack.request_uuid"] || ''
      ]

      logger.info %Q{Processing %s "%s%s" (for %s)  %s  Request ID: %s} % params
    end

    # Log end of request
    #
    # === Parameters
    # logger(Object):: the Rack logger
    # env(Hash):: the Rack environment
    # status(Fixnum):: status of the Rack request
    # began_at(Time):: time of the Rack request begging
    #
    # === Return
    # always returns true
    def log_request_end(logger, status, headers, began_at)
      duration = (Time.now - began_at) * 1000

      content_length = if headers['Content-Length']
        headers['Content-Length'].to_s
      else
        '-'
      end
      
      params = [
        duration,
        status,
        content_length,
      ]

      logger.info %Q{Completed in %dms | %d | %s bytes} % params
    end

    # Log exception
    #
    # === Parameters
    # logger(Object):: the Rack logger
    # e(Exception):: Exception to be logged
    #
    # === Return
    # always returns true
    def log_exception(logger, e)
      msg = ["#{e.class} - #{e.message}", *e.backtrace].join("\n")
      logger.error(msg)
    rescue
      #no-op, something is seriously messed up by this point...
    end
  end
end
