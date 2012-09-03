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
require 'yaml'

module RightSupport::Config

  # Helper that encapsulates logic for loading YAML configuration hashes from various sources
  # which can include strings, IO objects, or already-loaded YAML in the form of a Hash.
  module YAMLConfig

    class << self

      # Load yaml source
      #
      # === Parameters
      # something(IO|String|Hash):: File path, IO, raw YAML string, or a pre-loaded Hash
      #
      # === Returns
      # (Boolean|Hash):: Loaded yaml file or false if a RuntimeError occurred while loading
      def read(something)
        return_value = false

        begin
          if something.kind_of?(Hash)
            return_value = something
          elsif File.exists?(something)
            return_value = YAML.load_file(something)
          else
            return_value = YAML.load(something)
          end 
          raise unless return_value.kind_of?(Hash)
        rescue
          return_value = false
        end

        return_value
      end

    end

  end  

end

