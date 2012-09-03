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

module RightSupport::Rack
  # TODO docs
  class RequestTracker
    REQUEST_LINEAGE_UUID_HEADER = "HTTP_X_REQUEST_LINEAGE_UUID".freeze
    REQUEST_UUID_HEADER         = "X-Request-Uuid".freeze
    REQUEST_UUID_ENV_NAME       = "rack.request_uuid".freeze
    UUID_SEPARATOR              = " ".freeze

    # Make a new Request tracker.
    #
    # Tags the requset with a new request UUID
    #
    # === Parameters
    # app(Rack client): application to run
    def initialize(app)
      @app = app
    end

    def call(env)
      if env.has_key? REQUEST_LINEAGE_UUID_HEADER
        request_uuid = env[REQUEST_LINEAGE_UUID_HEADER] + UUID_SEPARATOR +
                       generate_request_uuid
      else
        request_uuid = generate_request_uuid
      end

      env[REQUEST_UUID_ENV_NAME] = request_uuid

      status, headers, body = @app.call(env)

      headers[REQUEST_UUID_HEADER] = request_uuid
      [status, headers,body]
    end


    def generate_request_uuid
      ::RightSupport::Data::UUID.generate
    end
  end

end