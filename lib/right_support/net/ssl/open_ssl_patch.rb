#
# Copyright (c) 2009-2011 RightScale Inc
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

require 'openssl'
# Under Ruby 1.8 the OpenSSL bindings have a stuttering problem
require 'openssl/ssl' if RUBY_VERSION < '1.9'

module RightSupport::Net
  module SSL
    # A helper module that provides monkey patch for OpenSSL::SSL.verify_certificate_identity method.
    #
    # To start use it, all you need is to enable it and then register DNS name of the host, which
    # you will trust for sure. This module automatically adds OpenSSL library and reopens
    # verify_certificate_identity method, to change the SSL algorythm of hostname verification.
    module OpenSSLPatch
      class << self
        @enabled = false

        def enable!
          return if @enabled
          @enabled = true

          OpenSSL::SSL.module_exec do
            def verify_certificate_identity(cert, hostname)
              if RightSupport::Net::SSL::OpenSSLPatch.enabled?
                actual_hostname = RightSupport::Net::SSL.expected_hostname
              end
              actual_hostname ||= hostname
              verify_certificate_identity_without_hack(cert, actual_hostname)
            end
            module_function :verify_certificate_identity

            # The original module function of OpenSSL::SSL
            def verify_certificate_identity_without_hack(cert, hostname)
              should_verify_common_name = true
              cert.extensions.each{|ext|
                next if ext.oid != "subjectAltName"
                ext.value.split(/,\s+/).each{|general_name|
                  if /\ADNS:(.*)/ =~ general_name
                    should_verify_common_name = false
                    reg = Regexp.escape($1).gsub(/\\\*/, "[^.]+")
                    return true if /\A#{reg}\z/i =~ hostname
                  elsif /\AIP Address:(.*)/ =~ general_name
                    should_verify_common_name = false
                    return true if $1 == hostname
                  end
                }
              }
              if should_verify_common_name
                cert.subject.to_a.each{|oid, value|
                  if oid == "CN"
                    reg = Regexp.escape(value).gsub(/\\\*/, "[^.]+")
                    return true if /\A#{reg}\z/i =~ hostname
                  end
                }
              end
              return false
            end
            module_function :verify_certificate_identity_without_hack
          end
        end

        def disable!
          @enabled = false
        end

        def enabled?
          @enabled
        end
      end
    end
  end
end
