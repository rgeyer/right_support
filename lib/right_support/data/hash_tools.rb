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

module RightSupport::Data

  # various tools for manipulating hash-like classes.
  module HashTools

    # Determines if given object is hashable (i.e. object responds to hash methods).
    #
    # === Parameters
    # @param [Object] object to be tested
    #
    # === Return
    # @return [TrueClass|FalseClass] true if object is hashable, false otherwise
    def self.hashable?(object)
      # note that we could obviously be more critical here, but this test has always been
      # sufficient and excludes Arrays and Strings which respond to [] but not has_key?
      #
      # what we specifically don't want to do is .kind_of?(Hash) because that excludes the
      # range of hash-like classes (such as Chef::Node::Attribute)
      object.respond_to?(:has_key?)
    end

    # Determines if given class is hash-like (i.e. instance of class responds to hash methods).
    #
    # === Parameters
    # @param [Class] clazz to be tested
    #
    # === Return
    # @return [TrueClass|FalseClass] true if clazz is hash-like, false otherwise
    def self.hash_like?(clazz)
      clazz.public_instance_methods.include?('has_key?')
    end

    # Gets a value from a (deep) hash using a path given as an array of keys.
    #
    # === Parameters
    # @param [Hash] hash for lookup or nil or empty
    # @param [Array] path to existing value as array of keys or nil or empty
    #
    # === Return
    # @return [Object] value or nil
    def self.deep_get(hash, path)
      hash ||= {}
      path ||= []
      last_index = path.size - 1
      path.each_with_index do |key, index|
        value = hash[key]
        if index == last_index
          return value
        elsif hashable?(value)
          hash = value
        else
          break
        end
      end
      nil
    end

    # Set a given value on a (deep) hash using a path given as an array of keys.
    #
    # === Parameters
    # @param [Hash] hash for insertion
    # @param [Array] path to new value as array of keys
    # @param [Object] value to insert
    # @param [Class] clazz to allocate as needed when building deep hash or nil to infer from hash argument
    #
    # === Return
    # @return [TrueClass] always true
    def self.deep_set!(hash, path, value, clazz=nil)
      raise ArgumentError.new("hash is invalid") unless hashable?(hash)
      raise ArgumentError.new("path is invalid") if path.empty?
      clazz ||= hash.class
      raise ArgumentError.new("clazz is invalid") unless hash_like?(clazz)
      last_index = path.size - 1
      path.each_with_index do |key, index|
        if index == last_index
          hash[key] = value
        else
          subhash = hash[key]
          unless hashable?(subhash)
            subhash = clazz.new
            hash[key] = subhash
          end
          hash = subhash
        end
      end
      true
    end

    # Creates a deep clone of the given hash.
    #
    # note that not all objects are clonable in Ruby even though all respond to clone
    # (which is completely counter-intuitive and contrary to all other managed languages).
    # Java, for example, has the built-in Cloneable marker interface which we will simulate
    # here with .duplicable? (because cloneable isn't actually a word) in case you need
    # non-hash values to be deep-cloned by this method.
    #
    # also note that .duplicable? may imply caling .dup instead of .clone but developers tend
    # to override .clone and totally forget to override .dup (and having two names for the
    # same method is, yes, a bad idea in any language).
    #
    # === Parameters
    # @param [Hash] original hash to clone
    #
    # === Block
    # @yieldparam [Object] value of leaf
    # @yieldreturn [Object] cloned value of leaf or original value
    #
    # === Return
    # @return [Hash] deep cloned hash
    def self.deep_clone(original, &leaf_callback)
      result = original.clone
      result.each do |k, v|
        if hashable?(v)
          result[k] = deep_clone(v)
        elsif leaf_callback
          result[k] = leaf_callback.call(v)
        elsif v.respond_to?(:duplicable?)
          result[k] = (v.duplicable? ? v.clone : v)
        else
          result[k] = v
        end
      end
      result
    end

    # Performs a deep merge (but not a deep clone) of one hash into another.
    #
    # === Parameters
    # @param [Hash] target hash to contain original and merged data
    # @param [Hash] source hash containing data to recursively assign or nil or empty
    #
    # === Return
    # @return [Hash] to_hash result of merge
    def self.deep_merge!(target, source)
      source.each do |k, v|
        if hashable?(target[k]) && hashable?(v)
          deep_merge!(target[k], v)
        else
          target[k] = v
        end
      end if source
      target
    end

    # Remove recursively values that exist equivalently in the match hash.
    #
    # === Parameters
    # @param [Hash] target hash from which to remove matching values
    # @param [Hash] source hash to compare against target for removal or nil or empty
    #
    # === Return
    # @return [Hash] target hash with matching values removed, if any
    def self.deep_remove!(target, source)
      source.each do |k, v|
        if target.has_key?(k)
          if target[k] == v
            target.delete(k)
          elsif hashable?(v) && hashable?(target[k])
            deep_remove!(target[k], v)
          end
        end
      end if source
      target
    end

    # Produce a difference from two hashes. The difference excludes any values which are
    # common to both hashes.
    #
    # The result is a hash with the following keys:
    #   - :diff = hash with key common to both input hashes and value composed of the corresponding different values: { :left => <left value>, :right => <right value> }
    #   - :left_only = hash composed of items only found in left hash
    #   - :right_only = hash composed of items only found in right hash
    #
    # === Parameters
    # @param [Hash] left side
    # @param [Hash] right side
    #
    # === Return
    # @return [Hash] result as hash of diffage
    def self.deep_create_patch(left, right)
      result = { :diff=>{}, :left_only=>{}, :right_only=>{} }
      right.each do |k, v|
        if left.include?(k)
          if hashable?(v) && hashable?(left[k])
            subdiff = deep_create_patch(left[k], v)
            result[:right_only].merge!(k=>subdiff[:right_only]) unless subdiff[:right_only].empty?
            result[:left_only].merge!(k=>subdiff[:left_only]) unless subdiff[:left_only].empty?
            result[:diff].merge!(k=>subdiff[:diff]) unless subdiff[:diff].empty?
          elsif v != left[k]
            result[:diff].merge!(k=>{:left => left[k], :right=>v})
          end
        else
          result[:right_only].merge!({ k => v })
        end
      end
      left.each { |k, v| result[:left_only].merge!({ k => v }) unless right.include?(k) }
      result
    end

    # Perform 3-way merge using given target and a patch hash (generated by deep_create_patch, etc.).
    # values in target whose keys are in :left_only component of patch are removed
    # values in :right_only component of patch get deep merged into target
    # values in target whose keys are in :diff component of patch and which are identical to left
    # side of diff get overwritten with right side of patch
    #
    # === Parameters
    # @param [Hash] target hash where patch will be applied.
    # @param [Hash] patch hash containing changes to apply.
    #
    # === Return
    # @param [Hash] target hash with patch applied.
    def self.deep_apply_patch!(target, patch)
      deep_remove!(target, patch[:left_only])
      deep_merge!(target, patch[:right_only])
      deep_apply_diff!(target, patch[:diff])
      target
    end

    # Recursively apply diff portion of a patch (generated by deep_create_patch, etc.).
    #
    # === Parameters
    # @param [Hash] target hash where diff will be applied.
    # @param [Hash] diff hash containing changes to apply.
    #
    # === Return
    # @param [Hash] target hash with diff applied.
    def self.deep_apply_diff!(target, diff)
      diff.each do |k, v|
        if v[:left] && v[:right]
          target[k] = v[:right] if v[:left] == target[k]
        elsif target.has_key?(k)
          deep_apply_diff!(target[k], v)
        end
      end
      target
    end

  end
end
