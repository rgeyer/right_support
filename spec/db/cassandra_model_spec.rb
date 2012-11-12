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
    RightSupport::DB::CassandraModel.config = {"#{env}" => {"server" => server}}
  end

  describe "initialization" do
    # This method determines the current keyspace based on the return value of the CassandraModel.keyspace method
    # which looks at the value of @@current_keyspace or @@default_keyspace to determine the keyspace it is operating
    # under. If a connection already exists for the keyspace it will re-use it.  If a connection does not exist,
    # it will create a new persistent connection for that keyspace that can be re-used with future requests
    context :conn do
      let(:column_family) { 'column_family' }
      let(:env) { 'test' }
      let(:server) { 'localhost:9160' }
      let(:keyspace) { 'SatelliteService_1' }
      let(:default_keyspace) { 'SatelliteService' }
      let(:current_keyspace_connection) { flexmock('cassandra') }
      let(:default_keyspace_connection) { flexmock('cassandra') }

      before(:each) do
        ENV["RACK_ENV"] = env
        RightSupport::DB::CassandraModel.column_family = column_family
        RightSupport::DB::CassandraModel.keyspace = default_keyspace
        RightSupport::DB::CassandraModel.config = {env => {"server" => server}}

        current_keyspace_connection.should_receive(:disable_node_auto_discovery!).and_return(true)
        current_keyspace_connection.should_receive(:name).and_return('connection1')

        default_keyspace_connection.should_receive(:disable_node_auto_discovery!).and_return(true)
        default_keyspace_connection.should_receive(:name).and_return('connection2')

        flexmock(Cassandra).should_receive(:new).with(keyspace + '_' + (ENV['RACK_ENV'] || 'development'), "localhost:9160", {:timeout=>10}).and_return(current_keyspace_connection)
        flexmock(Cassandra).should_receive(:new).with(default_keyspace + '_' + (ENV['RACK_ENV'] || 'development'), "localhost:9160", {:timeout=>10}).and_return(default_keyspace_connection)
      end

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

      # This method assumes that keyspaces being requested to connect to already exist.
      # If they do not exist, it should NOT create them.  If the connection is able
      # to be successfully established then it should be stored in a pool of connections
      it 'creates a new connection if no connection exists for provided keyspace' do
        RightSupport::DB::CassandraModel.conn.name.should == default_keyspace_connection.name
      end

      # If a connection has already been opened for a keyspace it should be re-used
      it 're-uses an existing connection if it exists for provided keyspace' do
        RightSupport::DB::CassandraModel.conn.name.should == RightSupport::DB::CassandraModel.conn.name
      end

      # The keyspace being used for the connection should be either the current keyspace or the default keyspace
      it 'uses the connection that corresponds to the provided keyspace' do
        RightSupport::DB::CassandraModel.with_keyspace(keyspace) do
          RightSupport::DB::CassandraModel.conn.name.should == current_keyspace_connection.name
        end
      end
    end
  end

  describe "use" do

    before(:each) do
      @column_family  = "TestApp"
      @keyspace       = "TestAppService"
      @server         = "localhost:9160"
      @env            = "test"
      @timeout        = {:timeout => RightSupport::DB::CassandraModel::DEFAULT_TIMEOUT}

      init_app_state(@column_family, @keyspace, @server, @env)

      @key            = 'key'
      @value          = 'foo'
      @offset         = 'bar'
      @attrs          = {@offset => @value}
      @opt            = {}
      @get_opt        = {:count => RightSupport::DB::CassandraModel::DEFAULT_COUNT}

      @instance = RightSupport::DB::CassandraModel.new(@key, @attrs)

      @conn = flexmock(:connection)
      flexmock(RightSupport::DB::CassandraModel).should_receive(:conn).and_return(@conn)
      @conn.should_receive(:insert).with(@column_family, @key, @attrs,@opt).and_return(true)
      @conn.should_receive(:remove).with(@column_family, @key).and_return(true)
      @conn.should_receive(:get).with(@column_family, @key, @get_opt).and_return(@attrs).by_default
      @conn.should_receive(:multi_get).with(@column_family, [1,2], @opt).and_return(Hash.new)
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
      # We want to remain backward-compatible for existing services so we expect this call to be made
      # as such: RightSupport::DB::CassandraModel.keyspace = "SatelliteService" and CassandraModel
      # will append the RACK_ENV to the end of it.  Ex: "SatelliteService_development"
      context :keyspace= do
        let(:keyspace) { 'SatelliteService' }

        it 'appends the environment to the keyspace provided' do
          RightSupport::DB::CassandraModel.keyspace = keyspace
          RightSupport::DB::CassandraModel.send(:class_variable_get, :@@default_keyspace).should == (keyspace + "_" + (ENV['RACK_ENV'] || 'development'))
        end
      end

      # If a current keyspace is provided it takes precedence over the default keyspace.  If none is
      # provided, the default keyspace should be returned.
      context :keyspace do
        let(:keyspace) { 'SatelliteService_' + ENV['RACK_ENV'] }

        it 'returns the default keyspace if no current keyspace is set' do
          RightSupport::DB::CassandraModel.send(:class_variable_set, :@@current_keyspace, nil)
          RightSupport::DB::CassandraModel.send(:class_variable_set, :@@default_keyspace, keyspace)
          RightSupport::DB::CassandraModel.keyspace.should == keyspace
        end

        it 'returns the current keyspace if a current keyspace is set' do
          RightSupport::DB::CassandraModel.send(:class_variable_set, :@@current_keyspace, keyspace)
          RightSupport::DB::CassandraModel.send(:class_variable_set, :@@default_keyspace, nil)
          RightSupport::DB::CassandraModel.keyspace.should == keyspace
        end
      end

      # This method assumes that a valid keyspace is passed in.  If the keyspace does not exist we do NOT
      # want to create it.  CassandraModel should use the keyspace provided for the duration of the code
      # executed within the block.  Any requests processed outside of the block should execute using the
      # default keyspace.
      context :with_keyspace do
        let(:keyspace) { 'SatelliteService_1' }
        let(:default_keyspace) { 'SatelliteService' }

        before(:each) do
          RightSupport::DB::CassandraModel.keyspace = default_keyspace
        end

        it 'sets the current keyspace to the keyspace provided for execution within the block' do
          RightSupport::DB::CassandraModel.with_keyspace(keyspace) do
            RightSupport::DB::CassandraModel.keyspace.should == keyspace + "_" + 'test'
          end
        end

        it 'resets back to the default keyspace for execution outside of the block' do
          RightSupport::DB::CassandraModel.with_keyspace(keyspace) {}
          RightSupport::DB::CassandraModel.keyspace.should == default_keyspace + "_" + 'test'
        end
        context 'append_env parameter' do
          it 'appends the environment by default' do
            RightSupport::DB::CassandraModel.with_keyspace('Monkey') do
              RightSupport::DB::CassandraModel.keyspace.should == 'Monkey_test'
            end
          end

          it 'appends the environment when append_env == true' do
            RightSupport::DB::CassandraModel.with_keyspace('Monkey', true) do
              RightSupport::DB::CassandraModel.keyspace.should == 'Monkey_test'
            end
          end

          it 'does NOT append the environment when append_env == false' do
            RightSupport::DB::CassandraModel.with_keyspace('Monkey_notatest', false) do
              RightSupport::DB::CassandraModel.keyspace.should == 'Monkey_notatest'
            end
          end

          it 'avoids double-appending the environment' do
            RightSupport::DB::CassandraModel.with_keyspace('Monkey_test') do
              RightSupport::DB::CassandraModel.keyspace.should == 'Monkey_test'
            end
          end
        end
      end

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
          pending "Unpredictable behavior on ruby < 1.9" unless RUBY_VERSION >= "1.9"
          default_count = RightSupport::DB::CassandraModel::DEFAULT_COUNT

          RightSupport::DB::CassandraModel.instance_eval { remove_const :DEFAULT_COUNT }
          RightSupport::DB::CassandraModel.const_set(:DEFAULT_COUNT, 2)
          begin

            attrs1 = {@offset + '1' => @value, @offset + '2' => @value}
            attrs2 = {@offset + '3' => @value}
            attrs = attrs1.merge(attrs2)
            get_opt1 = {:count => 2}
            get_opt2 = {:count => 2, :start => @offset + '2'}
            @conn.should_receive(:get).with(@column_family, @key, get_opt1).and_return(attrs1).once
            @conn.should_receive(:get).with(@column_family, @key, get_opt2).and_return(attrs2).once
            RightSupport::DB::CassandraModel.get(@key).attributes.should == attrs
          ensure
            RightSupport::DB::CassandraModel.instance_eval { remove_const :DEFAULT_COUNT }
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
          pending "Unpredictable behavior on ruby < 1.9" unless RUBY_VERSION >= "1.9"

          default_count = RightSupport::DB::CassandraModel::DEFAULT_COUNT

          RightSupport::DB::CassandraModel.instance_eval { remove_const :DEFAULT_COUNT }
          RightSupport::DB::CassandraModel.const_set(:DEFAULT_COUNT, 2)
          begin
            key1 = @key + '8'
            key2 = @key + '12'
            key3 = @key + '13'
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
            RightSupport::DB::CassandraModel.instance_eval { remove_const :DEFAULT_COUNT }
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

end
