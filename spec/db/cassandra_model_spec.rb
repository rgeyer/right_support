require 'spec_helper'

describe RightSupport::DB::CassandraModel do
  class Cassandra;end

  def init_app_state(column_family,keyspace,server,env)
    ENV["RACK_ENV"] = env
    RightSupport::DB::CassandraModel.column_family = column_family
    RightSupport::DB::CassandraModel.keyspace = keyspace
    RightSupport::DB::CassandraModel.config = {"test" => {"server" => server}}
  end

  before(:all) do
    @column_family  = "TestApp"
    @keyspace       = "TestAppService"
    @server         = "localhost:9160"
    @env            = "test"
    @timeout        = {:timeout => RightSupport::DB::CassandraModel::DEFAULT_TIMEOUT}

    init_app_state(@column_family,@keyspace,@server,@env)

    @key            = 'key'
    @value          = 'foo'
    @offset         = 'bar'
    @attrs          = {@offset => @value}
    @opt            = {}

    @instance = RightSupport::DB::CassandraModel.new(@key, @attrs)

    @conn = flexmock(:conn)
    flexmock(Cassandra).should_receive(:new).with(@keyspace + "_" + @env,@server,@timeout).and_return(@conn)
    @conn.should_receive(:disable_node_auto_discovery!).and_return(true)
    @conn.should_receive(:insert).with(@column_family,@key, @attrs,@opt).and_return(true)
    @conn.should_receive(:remove).with(@column_family,@key).and_return(true)
    @conn.should_receive(:get).with(@column_family,@key,@opt).and_return(@attrs)
    @conn.should_receive(:multi_get).with(@column_family,[1,2],@opt).and_return(Hash.new)
  end

  describe "instance methods" do
     context :save do
      it 'saves the record' do
        @instance.save.should be_true
      end
    end

    context :destroy do
      it 'destroys the record' do
        @instance.destroy.should be_true
      end
    end

    context :reload do
      it 'returns a new object for the record' do
        @instance.reload.should be_a_kind_of(RightSupport::DB::CassandraModel)
        @instance.reload!.should be_a_kind_of(RightSupport::DB::CassandraModel)
      end
    end
  end

  describe "class methods" do
    context :insert do
      it 'inserts a record by using the class method' do
        RightSupport::DB::CassandraModel.insert(@key, @attrs,@opt).should be_true
      end
    end

    context :remove do
      it 'removes a record by using the class method' do
        RightSupport::DB::CassandraModel.remove(@key).should be_true
      end
    end

    context :all do
      it 'returns all existing records for the specified array of keys' do
        RightSupport::DB::CassandraModel.all([1,2]).should be_a_kind_of(Hash)
      end
    end

    context :conn do
      it 'raises a meaningful exception when a config stanza is missing' do
        old_rack_env = ENV['RACK_ENV']

        begin
          ENV['RACK_ENV'] = 'foobar_12345'
          bad_proc = lambda { RightSupport::DB::CassandraModel.reconnect }
          bad_proc.should raise_error(RightSupport::DB::MissingConfiguration)
          bad_proc = lambda { RightSupport::DB::CassandraModel.conn }
          bad_proc.should raise_error(RightSupport::DB::MissingConfiguration)
        ensure
          ENV['RACK_ENV'] = old_rack_env
        end
      end
    end
  end
end