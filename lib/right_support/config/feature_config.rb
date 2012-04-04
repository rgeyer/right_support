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

module RightSupport::Config
   
  def self.read(something)
    return_value = nil
    if (yaml = YAMLConfig.read(something))
      return_value = FeatureConfig.new(yaml)
      return_value.configuration_source = something
    else 
      raise ArgumentError, "Can`t load yaml configuration."
    end
    return_value
  end  

  class FeatureConfig

    def initialize(yaml)
      @configuration = yaml
    end

    attr_accessor :configuration_source
    attr_writer  :configuration
    
    def configuration
      @configuration = YAMLConfig.read(configuration_source) unless @configuration
      @configuration  
    end    
  
    def [](feature_group, feature=nil)
      return_value = true      
      if self.configuration[feature_group]
        if feature == nil
          return_value = self.configuration[feature_group]
        else         
          return_value = self.configuration[feature_group][feature]
        end
      end      
      if return_value.kind_of?(String) || return_value == nil
        return_value = true
      end
      return_value
    end

  end
  
end
