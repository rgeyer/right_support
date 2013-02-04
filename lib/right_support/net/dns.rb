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

require 'socket'
require 'uri'

module RightSupport::Net
  module DNS
    DEFAULT_RESOLVE_OPTIONS = {
      :address_family => Socket::AF_INET,
      :socket_type    => Socket::SOCK_STREAM,
      :protocol       => Socket::IPPROTO_TCP,
      :retry          => 3
    }

    # Resolve a set of DNS hostnames to the individual IP addresses to which they map. Only handles
    # IPv4 addresses.
    #
    # @deprecated due to broken error handling - do not use; please use #resolve instead!
    def self.resolve_all_ip_addresses(hostnames)
      ips       = []
      hostnames = [hostnames] unless hostnames.respond_to?(:each)
      hostnames.each do |hostname|
        infos = nil
        begin
          infos = Socket.getaddrinfo(hostname, 443, Socket::AF_INET, Socket::SOCK_STREAM, Socket::IPPROTO_TCP)
        rescue Exception => e
          # NOTE: Need to figure out, which logger can we use here?
          # Log.error "Rescued #{e.class.name} resolving Repose hostnames: #{e.message}; retrying"
          retry
        end

        #Randomly permute the addrinfos of each hostname to help spread load.
        infos.shuffle.each do |info|
          ips << info[3]
        end
      end
      ips
    end

    # Perform DNS resolution on a set of endpoints, where the endpoints may be hostnames or URIs.
    # Expand out the list to include one entry per distinct address that is assigned to a given
    # hostname, but preserve other aspects of the endpoints --. URIs will remain URIs with the
    # same protocol, path-info, and so forth, but the hostname component will be resolved to IP
    # addresses and the URI will be duplicated in the output, once for each distinct IP address.
    #
    # Although this method does accept IPv4 dotted-quad addresses as input, it does not accept
    # IPv6 addresses. However, given hostnames or URIs as input, one _can_ resolve the hostnames
    # to IPv6 addresses by specifying the appropriate address_family in the options.
    #
    # It should never be necessary to specify a different :socket_type or :protocol, but these
    # options are exposed just in case.
    #
    # @param [Array<String>] endpoints a mixed list of hostnames, IPv4 addresses or URIs that contain them
    # @option opts [Integer] :retry number of times to retry SocketError; default is 3
    # @option opts [Integer] :address_family what kind of IP addresses to resolve; default is Socket::AF_INET (IPv4)
    # @option opts [Integer] :socket_type socket-type context to pass to getaddrinfo, default is Socket::SOCK_STREAM
    # @option opts [Integer] :protocol protocol context to pass to getaddrinfo, default is Socket::IPPROTO_TCP
    #
    # @return [Array<String>] larger list of endpoints with all hostnames resolved to IP addresses
    #
    # @raise URI::InvalidURIError if endpoints contains an invalid or URI
    # @raise SocketError if endpoints contains an invalid or unresolvable hostname
    def self.resolve(endpoints, opts={})
      opts = DEFAULT_RESOLVE_OPTIONS.merge(opts)
      endpoints = [endpoints] unless endpoints.respond_to?(:each)

      resolved_endpoints = []
      retries = 0

      endpoints.each do |endpoint|
        begin
          if endpoint.include?(':')
            # It contains a colon, therefore it must be a URI -- we don't support IPv6
            uri = URI.parse(endpoint)
            hostname = uri.host
            raise URI::InvalidURIError, "Could not parse host component of URI" unless hostname

            infos = Socket.getaddrinfo(hostname, nil,
                                       opts[:address_family], opts[:socket_type], opts[:protocol])

            infos.each do |info|
              transformed_uri = uri.dup
              transformed_uri.host = info[3]
              resolved_endpoints << transformed_uri.to_s
            end
          else
            # No colon; it's a hostname or IP address
            infos = Socket.getaddrinfo(endpoint, nil,
                                       opts[:address_family], opts[:socket_type], opts[:protocol])

            infos.each do |info|
              resolved_endpoints << info[3]
            end
          end
        rescue SocketError => e
          retries += 1
          if retries < opts[:retry]
            retry
          else
            raise
          end
        end
      end

      resolved_endpoints
    end

  end
end


