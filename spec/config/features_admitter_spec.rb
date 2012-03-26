require 'spec_helper'
require 'yaml'

describe RightSupport::Config::FeaturesAdmitter do
  
  class SweetestClass
    include RightSupport::Config::FeaturesAdmitter
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
    config_hash['eat']['khlav kalash'] = 'NO!'
    config_hash.send(:extend, HashHelper)
    config_string = config_hash.deep_stringify_keys.to_yaml
    yaml_config = config_string.gsub('!ruby/symbol ', ':').sub('---','').split('\n').map(&:rstrip).join('\n').strip
    SweetestClass.yaml_config = yaml_config
  end
  
  before(:each) do 
    @test_class = SweetestClass.new
  end

  context 'feature admitter works on instance' do
    it 'works with classic missing works' do
      expect {  @test_class.some_non_existed_method_with_unicorns\
               }.to raise_error(NoMethodError)
    end
    
    it 'evaluate true value from config file as' do
      @test_class.feature_speak_belarusian_allowed?.should be_true
    end

    it 'evaluate false value from config file as false' do
      @test_class.feature_speak_klingonese_allowed?.should_not be_true               
    end
     
    it 'evaluate not boolean value as false' do
      @test_class.send(:'feature_eat_khlav kalash_allowed?').should_not be_true
    end
  end
  
  context 'feature admitter works on class' do
    it 'works with classic missing works' do
      expect {  SweetestClass.some_non_existed_method_with_unicorns\
               }.to raise_error(NoMethodError)
    end

    it 'evaluate true value from config file as' do
      SweetestClass.feature_speak_belarusian_allowed?.should be_true
    end

    it 'evaluate false value from config file as false' do
      SweetestClass.feature_speak_klingonese_allowed?.should_not be_true
    end

    it 'evaluate not boolean value as false' do
      SweetestClass.send(:'feature_eat_khlav kalash_allowed?').should_not be_true
    end
  end

end
