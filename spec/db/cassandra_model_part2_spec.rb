require 'spec_helper'

describe RightSupport::DB::CassandraModel do

  class Cassandra
    class OrderedHash < Hash
      def keys
        super.sort
      end
    end
  end

  describe "do_op() logging" do

    before(:each) do
      @logger = flexmock(:logger)
      flexmock(RightSupport::Log::Mixin).should_receive(:default_logger).and_return(@logger)
      @logger.should_receive(:debug).with(String)
      @conn = flexmock(:connection)
      flexmock(RightSupport::DB::CassandraModel).should_receive(:conn).and_return(@conn)
      @conn.should_receive(:multi_get).and_return(true)
      @conn.should_receive(:get).and_return(true)
      @conn.should_receive(:get_indexed_slices).and_return(true)
      @conn.should_receive(:get_columns).and_return(true)
      @conn.should_receive(:insert).and_return(true)
      @conn.should_receive(:remove).and_return(true)
    end

    it "logs requests" do
      [:multi_get, :get, :get_indexed_slices, :get_columns, :insert, :remove].each do |method|
        RightSupport::DB::CassandraModel.do_op(method,'test_column_family', 'test_key')
      end
    end

  end

  context "do_op_log" do
    before(:each) do
      @logger = flexmock(:logger)
      flexmock(RightSupport::Log::Mixin).should_receive(:default_logger).and_return(@logger)
      flexmock(Time).should_receive(:now).and_return(100.010)
    end

    it "should display size for the keys if they are array" do
      first_started_at = 100.0
      started_at = 100.0
      @logger.should_receive(:debug).with("CassandraModel get, cf=cf_name, keys=5, time=10.0ms")
      RightSupport::DB::CassandraModel.do_op_log(first_started_at, started_at, 0, :get, 'cf_name', [1,2,3,4,5])
    end

    it "should display size for the key equal 1 if not array" do
      first_started_at = 100.0
      started_at = 100.0
      @logger.should_receive(:debug).with("CassandraModel get, cf=cf_name, keys=1, time=10.0ms")
      RightSupport::DB::CassandraModel.do_op_log(first_started_at, started_at, 0, :get, 'cf_name', "10")
    end

  	it "should display attemps time in milliseconds (ms)" do
      first_started_at = 100.0
      started_at = 100.0
      @logger.should_receive(:debug).with("CassandraModel get, cf=cf_name, keys=1, time=10.0ms")
      RightSupport::DB::CassandraModel.do_op_log(first_started_at, started_at, 0, :get, 'cf_name', [11])
    end

    it "should display total time milliseconds (s)" do
      first_started_at = 99.0
      started_at = 100.0
      @logger.should_receive(:debug).with("CassandraModel get, cf=cf_name, keys=1, time=10.0ms, retries=1, total_time=1010.0ms")
      RightSupport::DB::CassandraModel.do_op_log(first_started_at, started_at, 1, :get, 'cf_name', [11])
    end

  end
end