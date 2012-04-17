require 'spec_helper'

describe RightSupport::DB::CassandraModel do

  class Cassandra
    class OrderedHash < Hash
      def keys
        super.sort
      end
    end
  end

  def init_app_state(column_family,keyspace,server,env)
    ENV["RACK_ENV"] = env
    RightSupport::DB::CassandraModel.column_family = column_family
    RightSupport::DB::CassandraModel.keyspace = keyspace
    RightSupport::DB::CassandraModel.config = {"test" => {"server" => server}}
  end

  describe "initialization with unique keyspace" do

    before(:each) do
      RightSupport::DB::CassandraModel.keyspace   = "TestAppService"
      @server         = "localhost:9160"
      @env            = "test"
      @timeout        = {:timeout => RightSupport::DB::CassandraModel::DEFAULT_TIMEOUT}

      @conn = flexmock(:conn)
      flexmock(Cassandra).should_receive(:new).with(RightSupport::DB::CassandraModel.keyspace + "_" + @env, @server, @timeout).and_return(@conn)
      @conn.should_receive(:disable_node_auto_discovery!).and_return(true)
    end

    context :conn do
      it 'raises a meaningful exception when a config stanza is missing' do
        old_rack_env = ENV['RACK_ENV']

        begin
          ENV['RACK_ENV'] = 'foobar_12345'
          bad_proc = lambda { RightSupport::DB::CassandraModel.reconnect }
          bad_proc.should raise_error(RightSupport::DB::MissingConfiguration)
          # This must be the very first attempt to call #conn during the execution of this spec
          bad_proc = lambda { RightSupport::DB::CassandraModel.conn }
          bad_proc.should raise_error(RightSupport::DB::MissingConfiguration)
        ensure
          ENV['RACK_ENV'] = old_rack_env
        end
      end

      it 'creates connection and reuses it' do
        RightSupport::DB::CassandraModel.conn.should == @conn
        RightSupport::DB::CassandraModel.conn.should == @conn
      end
    end
  end

  describe "initialization with multiple keyspace" do

    before(:each) do
      RightSupport::DB::CassandraModel.keyspace      = ["TestAppService1", "TestAppService2", "TestAppService3"]
      @server         = "localhost:9160"
      @env            = "test"
      @timeout        = {:timeout => RightSupport::DB::CassandraModel::DEFAULT_TIMEOUT}

      @conn = flexmock(:conn)
      flexmock(Cassandra).should_receive(:new).with(RightSupport::DB::CassandraModel.keyspace + "_" + @env, @server, @timeout).and_return(@conn)
      @conn.should_receive(:disable_node_auto_discovery!).and_return(true)
    end

    context :conn do
      it 'creates connection and reuses it' do
        RightSupport::DB::CassandraModel.conn.should == @conn
        RightSupport::DB::CassandraModel.conn.should == @conn
      end
    end
  end


  describe "use" do

    before(:each) do
      @column_family  = "TestApp"
      RightSupport::DB::CassandraModel.keyspace       = ["TestAppService1", "TestAppService2", "TestAppService3"]
      RightSupport::DB::CassandraModel.default_keyspace = "TestAppService1"
      @server         = "localhost:9160"
      @env            = "test"
      @timeout        = {:timeout => RightSupport::DB::CassandraModel::DEFAULT_TIMEOUT}

      init_app_state(@column_family, RightSupport::DB::CassandraModel.keyspace, @server, @env)

      @key            = 'key'
      @value          = 'foo'
      @offset         = 'bar'
      @attrs          = {@offset => @value}
      @opt            = {}
      @get_opt        = {:count => RightSupport::DB::CassandraModel::DEFAULT_COUNT}

      @instance = RightSupport::DB::CassandraModel.new(@key, @attrs)

      @conn = flexmock(:conn)
      flexmock(RightSupport::DB::CassandraModel).should_receive(:conn).and_return(@conn)
      @conn.should_receive(:insert).with(@column_family, @key, @attrs,@opt).and_return(true)
      @conn.should_receive(:remove).with(@column_family, @key).and_return(true)
      @conn.should_receive(:get).with(@column_family, @key, @get_opt).and_return(@attrs).by_default
      @conn.should_receive(:multi_get).with(@column_family, [1,2], @opt).and_return(Hash.new)
    end
    
    describe 'multiple keyspaces' do
      context :default_keyspace do
        it 'change default keyspace properly' do
          RightSupport::DB::CassandraModel.default_keyspace.should == 'TestAppService1_test'
          RightSupport::DB::CassandraModel.default_keyspace = 'TestAppService2'
          RightSupport::DB::CassandraModel.default_keyspace = 'CHACHACHA'
          RightSupport::DB::CassandraModel.default_keyspace.should == 'TestAppService2_test'
        end
      end
      
      context :keyspace do
        it 'add new keyspace dynamically' do
          RightSupport::DB::CassandraModel.keyspace = 'TestAppService4'
          RightSupport::DB::CassandraModel.keyspaces.keys.size.should == 4
        end
      end
    end

    describe "instance methods" do
       context :save do
        it 'saves the row' do
          @instance.save.should be_true
        end
      end

      context :destroy do
        it 'destroys the row' do
          @instance.destroy.should be_true
        end
      end

      context :reload do
        it 'returns a new object for the row' do
          @instance.reload.should be_a_kind_of(RightSupport::DB::CassandraModel)
          @instance.reload!.should be_a_kind_of(RightSupport::DB::CassandraModel)
        end
      end
    end

    describe "class methods" do
      context :insert do
        it 'inserts a row by using the class method' do
          RightSupport::DB::CassandraModel.insert(@key, @attrs, @opt).should be_true
        end
      end

      context :remove do
        it 'removes a row by using the class method' do
          RightSupport::DB::CassandraModel.remove(@key).should be_true
        end
      end

      context :all do
        it 'returns all existing rows for the specified array of keys' do
          RightSupport::DB::CassandraModel.all([1, 2]).should be_a_kind_of(Hash)
        end
      end

      context :get do
        it 'returns row for the specified key' do
          RightSupport::DB::CassandraModel.get(@key).should be_a_kind_of(RightSupport::DB::CassandraModel)
        end

        it 'returns only number of columns requested' do
          attrs = {@offset + '1' => @value, @offset + '2' => @value}
          get_opt = {:count => 2}
          @conn.should_receive(:get).with(@column_family, @key, get_opt).and_return(attrs).once
          RightSupport::DB::CassandraModel.get(@key, get_opt).attributes.should == attrs
        end

        it 'returns all columns for the specified key if no count specified' do
          default_count = RightSupport::DB::CassandraModel::DEFAULT_COUNT

          begin
            RightSupport::DB::CassandraModel.const_set(:DEFAULT_COUNT, 2)
            attrs1 = {@offset + '1' => @value, @offset + '2' => @value}
            attrs2 = {@offset + '3' => @value}
            attrs = attrs1.merge(attrs2)
            get_opt1 = {:count => 2}
            get_opt2 = {:count => 2, :start => @offset + '2'}
            @conn.should_receive(:get).with(@column_family, @key, get_opt1).and_return(attrs1).once
            @conn.should_receive(:get).with(@column_family, @key, get_opt2).and_return(attrs2).once
            RightSupport::DB::CassandraModel.get(@key).attributes.should == attrs
          ensure
            RightSupport::DB::CassandraModel.const_set(:DEFAULT_COUNT, default_count)
          end
        end

        it 'returns nil if key not found' do
          @conn.should_receive(:get).with(@column_family, @key, @get_opt).and_return({})
          RightSupport::DB::CassandraModel.get(@key).should be_nil
        end
      end

      def real_get_indexed(index, key, columns = nil, opt = {})
        rows = {}
        start = ""
        count = DEFAULT_COUNT
        expr = do_op(:create_idx_expr, index, key, "EQ")
        opt = opt[:consistency] ? {:consistency => opt[:consistency]} : {}
        while true
          clause = do_op(:create_idx_clause, [expr], start, count)
          chunk = do_op(:get_indexed_slices, column_family, clause, columns, opt)
          rows.merge!(chunk)
          if chunk.size == count
            # Assume there are more chunks, use last key as start of next get
            start = chunk.keys.last
          else
            # This must be the last chunk
            break
          end
        end
        rows
      end

      context :get_indexed do

        before(:each) do
          @column = flexmock(:column, :name => 'foo', :value => 'bar')
          @column_or_super = flexmock(:column_or_super, :column => @column)
          @rows = {@key => [@column_or_super]}
          @index = 'index'
          @index_key = 'index_key'
          @start = ""
          @count = RightSupport::DB::CassandraModel::DEFAULT_COUNT
          @expr = flexmock(:expr)
          @conn.should_receive(:create_idx_expr).and_return(@expr)
          @clause = flexmock(:clause)
          @conn.should_receive(:create_idx_clause).with([@expr], @start, @count).and_return(@clause).by_default
          @conn.should_receive(:get_indexed_slices).with(@column_family, @clause, nil, {}).and_return(@rows).by_default
        end

        it 'returns row for the specified key' do
          rows = RightSupport::DB::CassandraModel.get_indexed(@index, @index_key)
          rows.should be_a_kind_of(Array)
          rows.size.should == 1
          rows.first.should be_a_kind_of(RightSupport::DB::CassandraModel)
        end

        it 'returns all rows for the specified key if no count specified' do
          default_count = RightSupport::DB::CassandraModel::DEFAULT_COUNT

          begin
            RightSupport::DB::CassandraModel.const_set(:DEFAULT_COUNT, 2)
            key1 = @key + '1'
            key2 = @key + '2'
            key3 = @key + '3'
            cols = {'foo' => 'bar'}
            rows1 = {key1 => [@column_or_super], key2 => [@column_or_super]}
            rows2 = {key3 => [@column_or_super]}
            @conn.should_receive(:create_idx_clause).with([@expr], @start, 2).and_return(@clause).once
            @conn.should_receive(:get_indexed_slices).with(@column_family, @clause, nil, {}).and_return(rows1).once
            @conn.should_receive(:create_idx_clause).with([@expr], key2, 2).and_return(@clause).once
            @conn.should_receive(:get_indexed_slices).with(@column_family, @clause, nil, {}).and_return(rows2).once
            rows = RightSupport::DB::CassandraModel.get_indexed(@index, @index_key)
            rows.size.should == 3
            rows.inject({}) { |s, r| s[r.key] = r.attributes; s }.should == {key1 => cols, key2 => cols, key3 => cols}
          ensure
            RightSupport::DB::CassandraModel.const_set(:DEFAULT_COUNT, default_count)
          end
        end

        it 'returns empty array if no rows found for key' do
          @conn.should_receive(:get_indexed_slices).with(@column_family, @clause, nil, {}).and_return({}).once
          RightSupport::DB::CassandraModel.get_indexed(@index, @index_key).should == []
        end
      end
    end
  end
end
