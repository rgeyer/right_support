# Copyright (c) 2009-2011 RightScale, Inc, All Rights Reserved Worldwide.
#
# THIS PROGRAM IS CONFIDENTIAL AND PROPRIETARY TO RIGHTSCALE
# AND CONSTITUTES A VALUABLE TRADE SECRET.  Any unauthorized use,
# reproduction, modification, or disclosure of this program is
# strictly prohibited.  Any use of this program by an authorized
# licensee is strictly subject to the terms and conditions,
# including confidentiality obligations, set forth in the applicable
# License Agreement between RightScale.com, Inc. and the licensee.

module RightSupport::Net
  # A helper module that provides monkey patch for OpenSSL::SSL.verify_certificate_identity method.
  #
  # To start use it, all you need is to enable it and then register DNS name of the host, which 
  # you will trust for sure. This module automatically adds OpenSSL library and reopens 
  # verify_certificate_identity method, to change the SSL algorythm of hostname verification.
  module SSLPatch
  class << self
    @@status = false

    def enable!
      return if @@status
      @@status = true

      require 'openssl'
      OpenSSL::SSL.module_exec do
        def verify_certificate_identity(cert, hostname)
          actual_hostname = DNSResolver.get_trusted_dns_name(hostname)
          verify_certificate_identity_without_hack(cert, actual_hostname ? actual_hostname : hostname)
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
      @@status = false
    end

    def enabled?
      @@status
    end

  end
end

module DNSResolver
  class << self
    @@registered_hostnames_hash = {}

    def get_trusted_dns_name(ip)
      @@registered_hostnames_hash[ip] if SSLPatch.enabled?
    end

    def register_trusted_dns_name(hostname)
      unless SSLPatch.enabled?
        puts "You have to enbale SSL monkey patch to use it!"
        return
      end
      begin
        infos = Socket.getaddrinfo(hostname, 443, Socket::AF_INET, Socket::SOCK_STREAM, Socket::IPPROTO_TCP)
      rescue Exception => e
        Log.error "Rescued #{e.class.name} resolving Repose hostnames: #{e.message}; retrying"
        retry
      end

      #Randomly permute the addrinfos of each hostname to help spread load.
      infos.shuffle.each do |info|
        ip = info[3]
        @@registered_hostnames_hash[ip] = hostname
      end
    end

  end
end

end
