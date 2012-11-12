require 'spec_helper'

describe RightSupport::DB::CassandraModel do

  class Cassandra
    class OrderedHash < Hash
      def keys
        super.sort
      end
    end
  end

  context "config" do
    let(:config) {  {'test' => {'server' => 'connection'} \
                    ,'developemnt' => {'server' => 'connection1'}} }
    
    ['test', 'developemnt'].each do |env|
      it "should return correct env: #{env.inspect} config" do
        RightSupport::DB::CassandraModel.config = config
        old_rack_env = ENV['RACK_ENV']
        ENV['RACK_ENV'] = env
        config[env].should ==  RightSupport::DB::CassandraModel.env_config
        ENV['RACK_ENV'] = old_rack_env
      end
    end

    it "should raise error if config not set or not Hash" do
        old_rack_env = ENV['RACK_ENV']
        RightSupport::DB::CassandraModel.config = nil
        ENV['RACK_ENV'] = 'nil_config'
        lambda {
          RightSupport::DB::CassandraModel.env_config
        }.should raise_error RightSupport::DB::MissingConfiguration

        ENV['RACK_ENV'] = old_rack_env
    end

    it "should raise error if no configuration find" do
        RightSupport::DB::CassandraModel.config = config
        old_rack_env = ENV['RACK_ENV']
        ENV['RACK_ENV'] = 'super_environment'
        lambda {
          RightSupport::DB::CassandraModel.env_config
        }.should raise_error RightSupport::DB::MissingConfiguration
        ENV['RACK_ENV'] = old_rack_env
    end

  end

  context "initialize" do
    let(:env) { 'server_config' }
    let(:column_family) { 'server_config_column_family' }
    let(:default_keyspace) { 'ServerConfigSatelliteService' }
    let(:default_keyspace_connection) { flexmock('cassandra') }

    {
      '[ring1, ring2, ring3]' => ['ring1', 'ring2', 'ring3'] \
     ,'ring1, ring2, ring3' => ['ring1', 'ring2', 'ring3'] \
     ,['ring1', 'ring2', 'ring3'] => ['ring1', 'ring2', 'ring3']
    }.each do |config_string, congig_test|
      it "shoudl successfully intialize from #{config_string.inspect}" do


        old_rack_env = ENV['RACK_ENV']
        begin
          ENV['RACK_ENV'] = env

          flexmock(Cassandra).should_receive(:new).with(default_keyspace + '_' + env, congig_test , {:timeout=>10}).and_return(default_keyspace_connection)
          default_keyspace_connection.should_receive(:disable_node_auto_discovery!).and_return(true)
        

          RightSupport::DB::CassandraModel.config = {env => {"server" => config_string}}
          RightSupport::DB::CassandraModel.keyspace = default_keyspace
          RightSupport::DB::CassandraModel.reconnect

        ensure
          ENV['RACK_ENV'] = old_rack_env
        end


      end
    end
  end
end