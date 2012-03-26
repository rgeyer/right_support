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
  module FeaturesAdmitter

    def self.included(base)
      unless defined? base.features_config
        base.send(:include, InstanceMethods)
        base.extend(ClassMethods)
      end    
    end
    
    def self.yaml_config
      @@yml_cnfg ||= File.expand_path('../config/features.yml', __FILE__)
    end
    
    def self.yaml_config=(src)
      @@yml_cnfg = src
    end

    module ClassMethods
      def yaml_config
        @yml_cfg ||= RightSupport::Config::FeaturesAdmitter.yaml_config        
      end

      def yaml_config=(src)        
        @yml_cfg = src
      end
      
      def features_config
        @cfg ||= RightSupport::Config::YAMLConfig.read(self.yaml_config)
      end
      
      def get_config_for_feature(feature_group, feature)
        return_value = true
        if self.features_config && self.features_config[feature_group]
          return_value = self.features_config[feature_group][feature]
        end
        return_value == true
      end
      
      def method_missing(method, *args, &block)
        if method.to_s[/^feature_.+_allowed\?$/]
          feature_group, feature = method.to_s.split('_')[1], method.to_s.split('_')[2]
          self.get_config_for_feature(feature_group, feature)
        else
          self.class_eval do
            self.superclass.method_missing(method, *args, &block)
          end
        end
      end

    end

    module InstanceMethods            

      def method_missing(method, *args, &block)
        if method.to_s[/^feature_.+_allowed\?$/]
          feature_group, feature = method.to_s.split('_')[1], method.to_s.split('_')[2]
          self.class.get_config_for_feature(feature_group, feature)       
        else          
          self.class.class_eval do
            self.superclass.method_missing(method, *args, &block)
          end        
        end
      end      
      
    end
  end  
end
