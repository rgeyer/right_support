#
# Copyright (c) 2011 RightScale Inc
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


# If cassandra gem is installed and 0.8 bindings are available, apply some
# monkey patches.
if require_succeeds?('cassandra/0.8')
  class Cassandra
    module Protocol
      # Monkey patch _get_indexed_slices so that it accepts list of columns when doing indexed
      # slice, otherwise not able to get specific columns using secondary index lookup
      def _get_indexed_slices(column_family, index_clause, columns, count, start, finish, reversed, consistency)
        column_parent = CassandraThrift::ColumnParent.new(:column_family => column_family)
        if columns
          predicate = CassandraThrift::SlicePredicate.new(:column_names => [columns].flatten)
        else
          predicate = CassandraThrift::SlicePredicate.new(:slice_range =>
            CassandraThrift::SliceRange.new(
              :reversed => reversed,
              :count => count,
              :start => start,
              :finish => finish))
        end
        client.get_indexed_slices(column_parent, index_clause, predicate, consistency)
      end
    end

    # Monkey patch get_indexed_slices so that it returns OrderedHash, otherwise cannot determine
    # next start key when getting in chunks
    def get_indexed_slices(column_family, index_clause, *columns_and_options)
      return false if Cassandra.VERSION.to_f < 0.7

      column_family, columns, _, options =
        extract_and_validate_params(column_family, [], columns_and_options, READ_DEFAULTS.merge(:key_count => 100, :key_start => ""))

      if index_clause.class != CassandraThrift::IndexClause
        index_expressions = index_clause.collect do |expression|
          create_index_expression(expression[:column_name], expression[:value], expression[:comparison])
        end

        index_clause = create_index_clause(index_expressions, options[:key_start], options[:key_count])
      end

      key_slices = _get_indexed_slices(column_family, index_clause, columns, options[:count], options[:start],
        options[:finish], options[:reversed], options[:consistency])

      key_slices.inject(OrderedHash.new){|h, key_slice| h[key_slice.key] = key_slice.columns; h}
    end
  end
end

# If thrift gem is available and we are running JRuby, monkey patch it so it
# works!
if (RUBY_PLATFORM =~ /java/) && require_succeeds?('thrift')
  module Thrift
    class Socket
      def open
        begin
          addrinfo = ::Socket::getaddrinfo(@host, @port).first
          @handle = ::Socket.new(addrinfo[4], ::Socket::SOCK_STREAM, 0)
          sockaddr = ::Socket.sockaddr_in(addrinfo[1], addrinfo[3])
          begin
            @handle.connect_nonblock(sockaddr)
          rescue Errno::EINPROGRESS
            resp = IO.select(nil, [ @handle ], nil, @timeout) # 3 lines removed here, 1 line added
            begin
              @handle.connect_nonblock(sockaddr)
            rescue Errno::EISCONN
            end
          end
          @handle
        rescue StandardError => e
          raise TransportException.new(TransportException::NOT_OPEN, "Could not connect to #{@desc}: #{e}")
        end
      end
    end
  end
end

module RightSupport::DB
  # Exception that indicates database configuration info is missing.
  class MissingConfiguration < Exception; end
  class UnsupportedRubyVersion < Exception; end
  # Base class for a column family in a keyspace
  # Used to access data persisted in Cassandra
  # Provides wrappers for Cassandra client methods
  class CassandraModel

    # Default timeout for client connection to Cassandra server
    DEFAULT_TIMEOUT = 10

    # Default maximum number of rows to retrieve in one chunk
    DEFAULT_COUNT = 100

    # Wrappers for Cassandra client
    class << self

      @@logger = nil

      attr_reader   :default_keyspace
      attr_accessor :column_family

      @@current_keyspace = nil

      @@connections = {}

      METHODS_TO_LOG = [:multi_get, :get, :get_indexed_slices, :get_columns, :insert, :remove, 'multi_get', 'get', 'get_indexed_slices', 'get_columns', 'insert', 'remove']

      # Depricate usage of CassandraModel under Ruby < 1.9
      def inherited(base)
        raise UnsupportedRubyVersion, "Support only Ruby >= 1.9" unless RUBY_VERSION >= "1.9"
      end

      def config
        @@config
      end

      def env_config
        env = ENV['RACK_ENV']
        raise MissingConfiguration, "CassandraModel config is missing a '#{ENV['RACK_ENV']}' section" \
            unless !@@config.nil? && @@config.keys.include?(env) && @@config[env]
        @@config[env]
      end

      def config=(value)
        @@config = normalize_config(value) unless value.nil?
      end

      def logger=(l)
        @@logger = l
      end

      def logger
        @@logger
      end

      # Return current keyspaces name as Array of String
      #
      # === Return
      # (Array):: keyspaces names

      def keyspaces
        @@connections.keys
      end

      # Returns current active keyspace.
      #
      # === Return
      # keyspace(String):: current_keyspace or default_keyspace

      def keyspace
        @@current_keyspace || @@default_keyspace
      end

      # Sets the default keyspace
      #
      # === Parameters
      # keyspace(String):: Set the default keyspace

      def keyspace=(kyspc)
        @@default_keyspace = (kyspc + "_" + (ENV['RACK_ENV'] || 'development'))
      end

      # Temporarily change the working keyspace for this class for the duration of
      # the block. Resets working keyspace back to default once control has
      # returned to the caller.
      #
      # === Parameters
      # keyspace(String):: Keyspace name
      # append_env(true|false):: optional; default true - whether to append the environment name
      # block(Proc):: Code that will be called in keyspace context
      def with_keyspace(keyspace, append_env=true, &block)
        @@current_keyspace = keyspace
        env = ENV['RACK_ENV'] || 'development'
        if append_env && @@current_keyspace !~ /_#{env}$/
          @@current_keyspace = "#{@@current_keyspace}_#{env}"
        end
        block.call
        ensure
          @@current_keyspace = nil
      end

      # Client connected to Cassandra server
      # Create connection if does not already exist
      # Use BinaryProtocolAccelerated if it available
      #
      # === Return
      # (Cassandra):: Client connected to server
      def conn()
        @@connections ||= {}

        config = env_config

        thrift_client_options = {:timeout => RightSupport::DB::CassandraModel::DEFAULT_TIMEOUT}
        thrift_client_options.merge!({:protocol => Thrift::BinaryProtocolAccelerated})\
          if defined? Thrift::BinaryProtocolAccelerated

        @@connections[self.keyspace] ||= Cassandra.new(self.keyspace, config["server"], thrift_client_options)
        @@connections[self.keyspace].disable_node_auto_discovery!
        @@connections[self.keyspace]
      end

      # Get row(s) for specified key(s)
      # Unless :count is specified, a maximum of 100 columns are retrieved
      #
      # === Parameters
      # k(String|Array):: Individual primary key or list of keys on which to match
      # opt(Hash):: Request options including :consistency and for column level
      #   control :count, :start, :finish, :reversed
      #
      # === Return
      # (Object|nil):: Individual row, or nil if not found, or ordered hash of rows
      def all(k, opt = {})
        real_get(k, opt)
      end

      # Get row for specified primary key and convert into object of given class
      # Unless :count is specified, a maximum of 100 columns are retrieved
      #
      # === Parameters
      # key(String):: Primary key on which to match
      # opt(Hash):: Request options including :consistency and for column level
      #   control :count, :start, :finish, :reversed
      #
      # === Return
      # (CassandraModel|nil):: Instantiated object of given class, or nil if not found
      def get(key, opt = {})
        if (attrs = real_get(key, opt)).empty?
          nil
        else
          new(key, attrs)
        end
      end

      # Get raw row(s) for specified primary key(s)
      # Unless :count is specified, a maximum of 100 columns are retrieved
      # except in the case of an individual primary key request, in which
      # case all columns are retrieved
      #
      # === Parameters
      # k(String|Array):: Individual primary key or list of keys on which to match
      # opt(Hash):: Request options including :consistency and for column level
      #   control :count, :start, :finish, :reversed
      #
      # === Return
      # (Cassandra::OrderedHash):: Individual row or OrderedHash of rows
      def real_get(k, opt = {})
        if k.is_a?(Array)
          do_op(:multi_get, column_family, k, opt)
        elsif opt[:count]
          do_op(:get, column_family, k, opt)
        else
          opt = opt.clone
          opt[:count] = DEFAULT_COUNT
          columns = Cassandra::OrderedHash.new
          loop do
            chunk = do_op(:get, column_family, k, opt)
            columns.merge!(chunk)
            if chunk.size == opt[:count]
              # Assume there are more chunks, use last key as start of next get
              opt[:start] = chunk.keys.last
            else
              # This must be the last chunk
              break
            end
          end
          columns
        end
      end

      # Get all rows for specified secondary key
      #
      # === Parameters
      # index(String):: Name of secondary index
      # key(String):: Index value that each selected row is required to match
      # columns(Array|nil):: Names of columns to be retrieved, defaults to all
      # opt(Hash):: Request options with only :consistency used
      #
      # === Block
      # Optional block that is yielded each chunk as it is retrieved as an array
      # like the normally returned result
      #
      # === Return
      # (OrderedHash):: Rows retrieved with each key, value is columns
      def get_all_indexed_slices(index, key, columns = nil, opt = {})
        rows = Cassandra::OrderedHash.new
        start = ""
        count = opt.delete(:count) || DEFAULT_COUNT
        expr = do_op(:create_idx_expr, index, key, "EQ")
        opt = opt[:consistency] ? {:consistency => opt[:consistency]} : {}
        while true
          clause = do_op(:create_idx_clause, [expr], start, count)
          chunk = self.conn.get_indexed_slices(column_family, clause, columns, opt)
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

      # This method is an attempt to circumvent the Cassandra gem limitation of returning only 100 columns for wide rows
      # This method returns only columns that are within the result set specified by a secondary index equality query
      # This method will iterate through chunks of rows of the resultset and it will yield to the caller all of the
      # columns in chunks of 1,000 until all of the columns have been retrieved
      #
      # == Parameters:
      # @param [String] index column name
      # @param [String] index column value
      #
      # == Yields:
      # @yield [Array<String, Array<CassandraThrift::ColumnOrSuperColumn>>] irray containing ndex column value passed in and an array of columns matching the index query
      def stream_all_indexed_slices(index, key)
        expr = do_op(:create_idx_expr, index, key, "EQ")

        start_row = ''
        row_count = 10
        has_more_rows = true

        while (start_row != nil)
          clause = do_op(:create_idx_clause, [expr], start_row, row_count)

          rows = self.conn.get_indexed_slices(column_family, clause, index,
                                              :key_count => row_count,
                                              :key_start => start_row)

          rows = rows.keys
          rows.shift unless start_row == ''
          start_row = rows.last

          rows.each do |row|
            start_column = ''
            column_count = 1_000
            has_more_columns = true

            while has_more_columns
              clause = do_op(:create_idx_clause, [expr], row, 1)
              chunk = self.conn.get_indexed_slices(column_family, clause, nil,
                                                   :start => start_column,
                                                   :count => column_count)

              # Get first row's columns, because where are getting only one row [see clause, for more details]
              key = chunk.keys.first
              columns = chunk[key]

              columns.shift unless start_column == ''
              yield(key, columns) unless chunk.empty?

              if columns.size >= column_count - 1
                #Assume there are more columns, use last column as start of next slice
                start_column = columns.last.column.name
                column_count = 1_001
              else
                has_more_columns = false
              end
            end
          end
        end
      end

      # Get all rows for specified secondary key
      #
      # === Parameters
      # index(String):: Name of secondary index
      # key(String):: Index value that each selected row is required to match
      # columns(Array|nil):: Names of columns to be retrieved, defaults to all
      # opt(Hash):: Request options with only :consistency used
      #
      # === Return
      # (Array):: Rows retrieved with each member being an instantiated object of the
      #   given class as value, but object only contains values for the columns retrieved;
      #   array is always empty if a block is given
      def get_indexed(index, key, columns = nil, opt = {})
        rows = []
        start = ""
        count = DEFAULT_COUNT
        expr = do_op(:create_idx_expr, index, key, "EQ")
        opt = opt[:consistency] ? {:consistency => opt[:consistency]} : {}
        loop do
          clause = do_op(:create_idx_clause, [expr], start, count)
          chunk = do_op(:get_indexed_slices, column_family, clause, columns, opt)
          chunk_rows = []
          chunk.each do |row_key, row_columns|
            if row_columns && row_key != start
              attrs = row_columns.inject({}) { |a, c| a[c.column.name] = c.column.value; a }
              chunk_rows << new(row_key, attrs)
            end
          end
          if block_given?
            yield chunk_rows
          else
            rows.concat(chunk_rows)
          end
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

      # Get specific columns in row with specified key
      #
      # === Parameters
      # key(String):: Primary key on which to match
      # columns(Array):: Names of columns to be retrieved
      # opt(Hash):: Request options such as :consistency
      #
      # === Return
      # (Array):: Values of selected columns in the order specified
      def get_columns(key, columns, opt = {})
        do_op(:get_columns, column_family, key, columns, sub_columns = nil, opt)
      end

      # Insert a row for a key
      #
      # === Parameters
      # key(String):: Primary key for value
      # values(Hash):: Values to be stored
      # opt(Hash):: Request options such as :consistency
      #
      # === Return
      # (Array):: Mutation map and consistency level
      def insert(key, values, opt={})
        do_op(:insert, column_family, key, values, opt)
      end

      # Delete row or columns of row
      #
      # === Parameters
      # args(Array):: Key, columns, options
      #
      # === Return
      # (Array):: Mutation map and consistency level
      def remove(*args)
        do_op(:remove, column_family, *args)
      end

      # Open a batch operation and yield self
      # Inserts and deletes are queued until the block closes,
      # and then sent atomically to the server
      # Supports :consistency option, which overrides that set
      # in individual commands
      #
      # === Parameters
      # args(Array):: Batch options such as :consistency
      #
      # === Block
      # Required block making Cassandra requests
      #
      # === Returns
      # (Array):: Mutation map and consistency level
      #
      # === Raise
      # Exception:: If block not specified
      def batch(*args, &block)
        raise "Block required!" unless block_given?
        do_op(:batch, *args, &block)
      end

      # Execute Cassandra request
      # Automatically reconnect and retry if IOError encountered
      #
      # === Parameters
      # meth(Symbol):: Method to be executed
      # args(Array):: Method arguments
      #
      # === Block
      # Block if any to be executed by method
      #
      # === Return
      # (Object):: Value returned by executed method
      def do_op(meth, *args, &block)
        # log functionality
        total_time ||= 0
        retries ||= 0
        total_time = Time.now if total_time == 0
        time = Time.now

        # cassandra functionality
        result = conn.send(meth, *args, &block)

        # log functionality
        do_op_log(time, total_time, retries, meth, args[0], args[1])
        return result
      rescue IOError
        reconnect
        retries += 1
        retry
      end

      def do_op_log(time, total_time, retries, meth, cf, key)
        now = Time.now
        time = now - time
        total_time = now - total_time
        if METHODS_TO_LOG.include?(meth)
          log_string = "Cassandra request: method=#{meth}, cf=#{cf}"
          if key.class == Array
            if key.size > 1
              log_string += ", keys amount=#{key.size}"
            else
              log_string += ", key=#{key.inspect}"
            end
          else
            log_string += ", key=#{key.inspect}"
          end
          log_string += ", request time=" + sprintf("%.1f", time * 1000.0) + "ms, retries=#{retries}, total time=" + sprintf("%.1f", total_time * 1000.0) + "ms"
          RightSupport::Log::Mixin.default_logger.debug(log_string)
        end
      end

      # Reconnect to Cassandra server
      # Use BinaryProtocolAccelerated if it available
      #
      # === Return
      # true:: Always return true
      def reconnect
        config = env_config

        return false if keyspace.nil?

        thrift_client_options = {:timeout => RightSupport::DB::CassandraModel::DEFAULT_TIMEOUT}
        thrift_client_options.merge!({:protocol => Thrift::BinaryProtocolAccelerated})\
          if defined? Thrift::BinaryProtocolAccelerated

        connection = Cassandra.new(keyspace, config["server"], thrift_client_options)
        connection.disable_node_auto_discovery!
        @@connections[keyspace] = connection
        true
      end

      # Cassandra ring
      #
      # === Return
      # (Array):: Members of ring
      def ring
        conn.ring
      end

      private

      # Massage configuration hash into a standard form.
      # @return the config hash, with contents normalized
      def normalize_config(untrasted_config)
        untrasted_config.each do |env, config|
          raise MissingConfiguration, "CassandraModel config is broken, a '#{ENV['RACK_ENV']}' missing 'server' option" \
 unless config.keys.include?('server')
          server = config['server']

          if server.is_a?(String)
            # Strip surrounding brackets, in case Ops put a YAML array into an input value
            if server.start_with?('[') && server.end_with?(']')
              server = server[1..-2]
            end

            # Transform comma-separated host lists into an Array
            if server =~ /,/
              server = server.split(/\s*,\s*/)
            end
          end

          config['server'] = server

          config
        end
      end

    end # self

    attr_accessor :key, :attributes

    # Create column family object
    #
    # === Parameters
    # key(String):: Primary key for object
    # attrs(Hash):: Attributes for object which form Cassandra row
    #   with column name as key and column value as value
    def initialize(key, attrs = {})
      self.key = key
      self.attributes = attrs
    end

    # Store object in Cassandra
    #
    # === Return
    # true:: Always return true
    def save
      self.class.insert(key, attributes)
      true
    end

    # Load object from Cassandra without modifying this object
    #
    # === Return
    # (CassandraModel):: Object as stored in Cassandra
    def reload
      self.class.get(key)
    end

    # Reload object value from Cassandra and update this object
    #
    # === Return
    # (CassandraModel):: This object after reload from Cassandra
    def reload!
      self.attributes = self.class.real_get(key)
      self
    end

    # Column value
    #
    # === Parameters
    # key(String|Integer):: Column name or key
    #
    # === Return
    # (Object|nil):: Column value, or nil if not found
    def [](key)
      ret = attributes[key]
      return ret if ret
      if key.kind_of? Integer
        return attributes[Cassandra::Long.new(key)]
      end
    end

    # Store new column value
    #
    # === Parameters
    # key(String|Integer):: Column name or key
    # value(Object):: Value to be stored
    #
    # === Return
    # (Object):: Value stored
    def []=(key, value)
      attributes[key] = value
    end

    # Delete object from Cassandra
    #
    # === Return
    # true:: Always return true
    def destroy
      self.class.remove(key)
    end

  end # CassandraModel

end # RightSupport::DB
