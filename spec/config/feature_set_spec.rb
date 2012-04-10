require 'spec_helper'
require 'yaml'

describe RightSupport::Config::FeatureSet do
  
  class SweetestClass
    attr_accessor :config
  end  

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
    config_hash['speak']['klingonese'] = false
    config_hash['eat'] = {}
    config_hash['eat']['khlav kalash'] = 'YES!'    
    config_hash.send(:extend, HashHelper)
    config_string = config_hash.deep_stringify_keys.to_yaml
    yaml_config = config_string.gsub('!ruby/symbol ', ':').sub('---','').split('\n').map(&:rstrip).join('\n').strip

    @test_class = SweetestClass.new
    @test_class.instance_eval{ @config = RightSupport::Config.features(yaml_config) }
  end
  
  context 'features set config works correctly' do

    it 'evaluates non existed feature as true' do
      @test_class.config['I saw Tom Collins'].should be_true
    end
    
    it 'evaluates true correctly' do
      @test_class.config['speak', 'belarusian'].should be_true
    end
    
    it 'evaluates false correctly' do
      @test_class.config['speak', 'klingonese'].should_not be_true
    end
 
    it 'evaluates string as string' do
      @test_class.config['eat']['khlav kalash'].should == 'YES!'
    end   

    it 'supports [][] calling' do 
      @test_class.config['speak']['klingonese'].should_not be_true      
    end
    
    it 'load hash as config source' do
      hash_config = {:'tom collins'=>{:invisible=>'sure!'}}
      @test_class.instance_eval{ @config = RightSupport::Config.features(hash_config)}
      @test_class.config[:'tom collins'][:invisible].should == 'sure!'
    end
  
    it 'raise error on wrong yaml' do
      wrong_yaml_config = {:a=>:b}.to_yaml + "::\n\na"
      lambda do
        @test_class.instance_eval{ @config = RightSupport::Config.features(wrong_yaml_config)}
      end.should raise_error(ArgumentError)
    end

  end

end
