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

  # Returns new instance of FeatureSet class,
  # with loaded from config_source configuration
  #
  # === Parameters
  # config_source(IO|String):: File` path, IO or raw yaml.
  #
  # === Return
  # (FeatureSet):: new instance of FeatureSet class
  def self.features(config_source)
    return FeatureSet.new(config_source)
  end  
  
  class FeatureSet
    
    attr_accessor :configuration_source
    attr_accessor :configuration
    
    # Create features configuration object
    #
    # === Parameters
    # cfg_source(IO|String):: File path, IO or raw yaml.
    def initialize(cfg_source)
      @configuration = load(cfg_source)
    end

    # Returns configuration value
    #
    # === Parameters
    # feature_group(String):: Feature group name
    # feature(String|nil):: Feature name
    #
    # === Return
    # (String|Boolean):: Configuration value
    def [](feature_group, feature=nil)
      return_value = true
      if @configuration[feature_group]
        if feature == nil
          return_value = @configuration[feature_group]
        else
          return_value = @configuration[feature_group][feature]
        end
      else
        return_value = RecursiveTrueClass.new
      end
      return_value = true if return_value == nil            
      return_value
    end

    # Load configuration source
    #
    # === Parameters
    # something(IO|String|Hash):: File path, IO, raw YAML string, or a pre-loaded Hash
    #
    # === Return
    # (Hash|nil):: Loaded yaml file 
    #
    # === Raise
    # (ArgumentError):: If configuration source can`t be loaded
    def load(something)
      return_value = nil
      error_message = ''
      @configuration_source = something
      begin
        return_value = YAMLConfig.read(something)
      rescue Exception => e
        error_message = "#{e}"
      end
      raise ArgumentError, "Can't coerce #{something} into YAML/Hash. #{e}" unless return_value
      return_value
    end

  end

  # Temporary alias for FeatureSet class, to avoid disrupting downstream development
  Feature = FeatureSet
  
end
