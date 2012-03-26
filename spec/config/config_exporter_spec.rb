require 'spec_helper'
require 'yaml'

describe RightSupport::Config::ConfigExporter do
  
  module HashHelper
    def deep_stringify_keys
      new_hash = {}
      self.each do |key, value|
        new_hash.merge!(key.to_s => (value.is_a?(Hash) ?\
          value.extend(HashHelper).deep_stringify_keys\
          : value))
      end
    end
  end

 
  #generating yml config on fly
  before(:all) do 
    config_hash = {}
    config_hash['speak'] = {}
    config_hash['speak']['belarusian'] = true
    config_hash['eat'] = {}
    config_hash['eat']['khlav kalash'] = 'NO!'
    config_hash.send(:extend, HashHelper)
    config_string = config_hash.deep_stringify_keys.to_yaml
    yaml_config = config_string.gsub('!ruby/symbol ', ':').sub('---','').split('\n').map(&:rstrip).join('\n').strip
    RightSupport::Config::ConfigExporter.yaml_config = yaml_config    
  end

  context 'config exporter generates correct string' do
    it 'export variable in correct way' do
      correct_export_string = 'export IS_EAT_KHLAV_KALASH=false;export IS_SPEAK_BELARUSIAN=true;'
      RightSupport::Config::ConfigExporter.export_to_bash.should == correct_export_string
    end
  end

end
