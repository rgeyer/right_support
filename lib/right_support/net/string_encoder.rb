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

require 'cgi'
require 'base64'
require 'zlib'

module RightSupport::Net
  #
  # A tool that encodes (binary or ASCII) strings into 7-bit ASCII
  # using one or more encoding algorithms which are applied sequentially.
  # The order of algorithms is reversed on decode, naturally!
  #
  # This class is designed to be used with network protocols implemented
  # on top of HTTP, where binary data needs to be encapsulated in URL query
  # strings, request bodies or other textual payloads. Sometimes multiple
  # encodings are necessary in order to prevent unnecessary expansion of
  # the encoded text.
  #
  # == Ruby 1.9 and Character Encodings
  #
  # === Input Strings
  # The #encode and #decode methods accept strings with any encoding, and do not perform
  # any conversion or coercion between encodings. Strings are passed unmodified to the
  # underlying encoding libraries.
  #
  # === Output Strings
  # The #encode method always returns strings with an encoding of US-ASCII, because the
  # output of all encodings is guaranteed to be 7-bit ASCII.
  #
  # The #decode method always returns strings with an encoding of ASCII-8BIT (aka BINARY)
  # because there is no way to determine the correct encoding. The caller of #decode
  # should use String#force_encoding to coerce the output value to an appropriate encoding
  # before displaying or manipulating the output.
  #
  class StringEncoder
    ENCODINGS = [:base64, :url]
    ENCODINGS.freeze

    #
    # Create a new instance.
    #
    # === Parameters
    # *encodings:: list of Symbols representing an ordered sequence of encodings
    #
    def initialize(*args)
      args = args.flatten
      args.each do |enc|
        raise ArgumentError, "Unknown encoding #{enc}" unless ENCODINGS.include?(enc)
      end

      @encodings = args
    end

    #
    # Encode a binary or textual string.
    #
    # === Parameters
    # value(String):: the value to be encoded
    #
    # === Return
    # The encoded value, with all encodings applied.
    def encode(value)
      @encodings.each do |enc|
        case enc
          when :base64
            value = Base64.encode64(value)
          when :url
            value = CGI.escape(value)
        end
      end

      value
    end

    #
    # Decode a binary or textual string.
    #
    # === Parameters
    # value(String):: the value to be decoded
    #
    # === Return
    # The decoded string value
    def decode(value)
      @encodings.reverse.each do |enc|
        case enc
          when :base64
            value = Base64.decode64(value)
          when :url
            value = CGI.unescape(value)
        end
      end

      value.force_encoding(Encoding::ASCII_8BIT) if value.respond_to?(:force_encoding)
      value
    end
  end
end
