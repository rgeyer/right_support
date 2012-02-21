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
    # Initialize an instance of the middleware. For backward compatibility, the order of the
    # logger and level parameters can be switched.
    #
    # === Parameters
    # app(Object):: the inner application or middleware layer; must respond to #call
    # logger(Logger):: (optional) the Logger object to use, defaults to a STDERR logger
    # level(Integer):: (optional) a Logger level-constant (INFO, ERROR) to set the logger to
    #
    attr_reader :filter_parameters

    def filter_parameters=(val)
      @filter_parameters = case val
                         when NilClass:  //
                         when Regexp: val
                         when Array: Regexp.new(val.join('|'), true)
                         when String: Regexp.new(val, true)
      end
    end

    def initialize(app, options={})
      @app    = app
      @logger = options[:logger]
      @filter_parameters = options[:filter_parameters]
    end

    # Add a logger to the Rack environment and call the next middleware.
    #
    # === Parameters
    # env(Hash):: the Rack environment
    #
    # === Return
    # always returns whatever value is returned by the next layer of middleware
    def call(env)
      if @logger
        logger = @logger
      elsif env['rack.logger']
        logger = env['rack.logger']
      end

      env['rack.logger'] ||= logger

      began_at = Time.now
      status, header, body = @app.call(env)
      log_request(logger, env, status, began_at)
      log_exception(logger, env['sinatra.error']) if env['sinatra.error']

      return [status, header, body]
    rescue Exception => e
      log_exception(logger, e)
      raise e
    end

    private
    def disclose_query_params(request, keep_regex)
      params_hash = {}
      params_hash = request.params.merge(request.params){|k,v| k.match(keep_regex) ? v : '[FILTERED]' }\
                          if request.get?
      [params_hash, request.body.size ]
    end

    # NON Logger functions below
    def log_request(logger, env, status, began_at)
      duration = Time.now - began_at

      # Assuming remote addresses are IPv4, make them all align to the same width
      remote_addr = env['HTTP_X_FORWARDED_FOR'] || env['REMOTE_ADDR'] || "-"
      remote_addr = remote_addr.ljust(15)

      query_info_hash, request_body_size = disclose_query_params(req = Rack::Request.new(env), @filter_parameters)
      query_info = '?' + Rack::Utils.unescape(Rack::Utils.build_query(query_info_hash)) unless query_info_hash.empty?
      params = [
        remote_addr,
        env["REQUEST_METHOD"],
        env["PATH_INFO"],
        query_info || '',
        request_body_size,
        env["HTTP_VERSION"],
        status,
        duration
      ]

      logger.info %Q{%s "%s %s%s" %s %s %s %0.3f} % params
    end

    def log_exception(logger, e)
      msg = ["#{e.class} - #{e.message}", *e.backtrace].join("\n")
      logger.error(msg)
    rescue
      #no-op, something is seriously messed up by this point...
    end
  end
end
