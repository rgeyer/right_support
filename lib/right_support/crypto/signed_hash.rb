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

require 'digest/sha1'

module RightSupport::Crypto
  class SignedHash

    if require_succeeds?('yajl')
      DefaultEncoding = ::Yajl
    elsif require_succeeds?('oj')
      DefaultEncoding = ::Oj
    elsif require_succeeds?('json')
      DefaultEncoding = ::JSON
    else
      DefaultEncoding = nil
    end unless defined?(DefaultEncoding)

    DEFAULT_OPTIONS = {
      :digest   => Digest::SHA1,
      :encoding => DefaultEncoding
    }

    def initialize(hash={}, options={})
      options = DEFAULT_OPTIONS.merge(options)
      @hash        = hash
      @digest      = options[:digest]
      @encoding    = options[:encoding]
      @public_key  = options[:public_key]
      @private_key = options[:private_key]
      duck_type_check
    end

    def sign(expires_at)
      raise ArgumentError, "Cannot sign; missing private_key" unless @private_key
      raise ArgumentError, "expires_at must be a Time in the future" unless time_check(expires_at)

      metadata = {:expires_at => expires_at}
      @private_key.private_encrypt( digest( encode( canonicalize( frame(@hash, metadata) ) ) ) )
    end

    def verify!(signature, expires_at)
      raise ArgumentError, "Cannot verify; missing public_key" unless @public_key

      metadata = {:expires_at => expires_at}
      expected = digest( encode( canonicalize( frame(@hash, metadata) ) ) )
      actual = @public_key.public_decrypt(signature)
      raise SecurityError, "Signature mismatch: expected #{expected}, got #{actual}" unless actual == expected
      raise SecurityError, "The signature has expired (or expires_at is not a Time)" unless time_check(expires_at)
    end

    def verify(signature, expires_at)
      verify!(signature, expires_at)
      true
    rescue Exception => e
      false
    end

    def method_missing(meth, *args)
      @hash.__send__(meth, *args)
    end

    private

    def duck_type_check
      unless @digest.is_a?(Class) &&
             @digest.instance_methods.include?(str_or_symb('update')) &&
             @digest.instance_methods.include?(str_or_symb('digest'))
        raise ArgumentError, "Digest class must respond to #update and #digest instance methods"
      end
      unless @encoding.respond_to?(str_or_symb('dump'))
        raise ArgumentError, "Encoding class/module/object must respond to .dump method"
      end
      if @public_key && !@public_key.respond_to?(str_or_symb('public_decrypt'))
        raise ArgumentError, "Public key must respond to :public_decrypt (e.g. an OpenSSL::PKey instance)"
      end
      if @private_key && !@private_key.respond_to?(str_or_symb('private_encrypt'))
        raise ArgumentError, "Private key must respond to :private_encrypt (e.g. an OpenSSL::PKey instance)"
      end
    end

    def str_or_symb(method)
      RUBY_VERSION > '1.9' ? method.to_sym : method.to_s
    end

    def time_check(t)
      t.is_a?(Time) && (t >= Time.now)
    end

    def frame(data, metadata) # :nodoc:
      {:data => data, :metadata => metadata}
    end

    def digest(input) # :nodoc:
      @digest.new.update(input).digest
    end

    def encode(input)
      @encoding.dump(input)
    end

    def canonicalize(input) # :nodoc:
      case input
        when Hash
          # Hash is the only complex case. We canonicalize a Hash as an Array of pairs, each of which
          # consists of one key and one value. The ordering of the pairs is consistent with the
          # ordering of the keys.
          output = Array.new

          # First, transform the original input hash into something that has canonicalized keys
          # (which should make them sortable, too). Also canonicalize the values while we are
          # at it...
          sortable_input = {}
          input.each { |k,v| sortable_input[canonicalize(k)] = canonicalize(v) }

          # Sort the keys; guard this operation so we can raise an intelligent error if
          # something is still not sortable even after canonicalization.
          begin
            ordered_keys = sortable_input.keys.sort
          rescue Exception => e
            msg = "SignedHash requires sortable hash keys; cannot sort #{sortable_input.keys.inspect} " +
                  "due to #{e.class.name}: #{e.message}"
            e2 = ArgumentError.new(msg)
            e2.set_backtrace(e.backtrace)
            raise e2
          end

          ordered_keys.each do |key|
            output << [ key, sortable_input[key] ]
          end
        when Array
          output = input.collect { |x| canonicalize(x) }
        when Time
          output = input.to_i
        when Symbol
          output = input.to_s
        else
          output = input
      end

      output
    end
  end
end
