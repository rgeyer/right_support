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

begin
  require 'cassandra/0.8'

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

rescue LoadError => e
  # Make sure we're dealing with a legitimate missing-file LoadError
  raise e unless e.message =~ /^no such file to load/
  # Missing 'cassandra/0.8' indicates that the cassandra gem is not installed; we can ignore this
end

# monkey patch thrift to work with jruby
if (RUBY_PLATFORM =~ /java/)
  begin
    require 'thrift'
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
  rescue LoadError => e
    # Make sure we're dealing with a legitimate missing-file LoadError
    raise e unless e.message =~ /^no such file to load/
  end
end


module RightSupport::DB
  # Exception that indicates database configuration info is missing.
  class MissingConfiguration < Exception; end

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
      #@@conn = nil
      
      attr_accessor :column_family

      # attr_writer :keyspace
      @@keyspaces = {}      
      
      def keyspaces
        @@keyspaces
      end

      @@default_keyspace = nil
      
      def default_keyspace
        if @@default_keyspace.nil? && @@keyspaces.size>0
          first_no_nil_keyspaces = @@keyspaces.detect{|kyspc, connection| !connection.nil?}
          if first_no_nil_keyspaces.nil?
            @@default_keyspace = @@keyspaces.clone.shift[0]
          else
            @@default_keyspace = first_no_nil_keyspaces[0]
          end
        end

        @@default_keyspace
      end

      def default_keyspace=(new_default_kyspc)
        @@default_keyspace = new_default_kyspc if @@keyspaces.has_key?(new_default_kyspc)
        # if not - probably raise exception
      end

      def config
        @@config
      end
      
      def config=(value)
        @@config = value
      end
 
      def logger=(l)
        @@logger = l
      end
      
      def logger
        @@logger 
      end

      def keyspace
        return_value = nil
        if self.default_keyspace
          return_value = self.default_keyspace
        end
        return_value
      end

      def keyspace=(new_keyspace)
        filtered_keyspaces = []
        if new_keyspace.kind_of?(String)
          filtered_keyspaces.push(new_keyspace)
        elsif new_keyspace.kind_of?(Array)
          filtered_keyspaces = new_keyspace.select{|kyspc| !@@keyspaces.has_key?(kyspc) }
        else
          raise ArgumentError, "You can specify String or Array as keyspaces."
        end
        filtered_keyspaces.each{|kyspc| @@keyspaces[kyspc + "_" + (ENV['RACK_ENV'] || 'development')] = nil}
        @@default_keyspace = (filtered_keyspaces[0] + "_" + (ENV['RACK_ENV'] || 'development'))\
                          if filtered_keyspaces.size > 0
        #elsif @@default_keyspace.nil? && @@keyspaces.size>0
        #  first_no_nil_keyspace = @@keyspaces.detect{|kyspc, connection| !connection.nil?}
        #  @@default_keyspace = first_no_nil_keyspace[0] unless first_no_nil_keyspace.nil?
        #end
      end
      
      # Client connected to Cassandra server
      # Create connection if does not already exist
      # Use BinaryProtocolAccelerated if it available
      #
      # === Return
      # (Cassandra):: Client connected to server
      def conn(kyspc=nil)
        connection  = nil

        if kyspc.nil?
          if !@@default_keyspace.nil?
            kyspc = @@default_keyspace
          else
            if @@keyspaces.size>0
              kyspc = @@keyspaces.shift[0]
            else
              #probably raise exception
              return nil
            end
          end
        end

        if !@@keyspaces[kyspc].nil?
          return_value = @@keyspaces[kyspc]
        elsif @@keyspaces.has_key?(kyspc)
          # TODO remove hidden dependency on ENV['RACK_ENV'] (maybe require config= to accept a sub hash?)
          config = @@config[ENV["RACK_ENV"]]
          raise MissingConfiguration, "CassandraModel config is missing a '#{ENV['RACK_ENV']}' section" unless config

          thrift_client_options = {:timeout => RightSupport::DB::CassandraModel::DEFAULT_TIMEOUT}
          thrift_client_options.merge!({:protocol => Thrift::BinaryProtocolAccelerated})\
            if defined? Thrift::BinaryProtocolAccelerated

          connection = Cassandra.new(kyspc, config["server"], thrift_client_options)
          connection.disable_node_auto_discovery!
          @@keyspaces[kyspc] = connection
        end
        connection        
      end
      
      # Disconnect given keyspace from Cassandra server
      #
      # === Parameters
      # disconnect_keyspace(String):: keyspace name to be disconnected
      #
      # === Return
      # (Cassandra):: Client connected to server
      def disconnect!(disconnect_keyspace)
        if @@keyspaces.has_key?(disconnect_keyspace)                    
          connection = @@keyspaces[disconnect_keyspace]
          if !connection.nil?
            connection.disconnect!
            connection = nil
          end
          @@keyspaces.delete(disconnect_keyspace)
          if disconnect_keyspace == @@default_keyspace
            shifted_keyspace = @@keyspaces.keys           
            @@default_keyspace = (shifted_keyspace.empty? ? nil : shifted_keyspace[0])
          end
          return_value = true
        end
        return_value
      end
      
      # Disconnect all keyspaces from Cassandra server
      #
      # === Return
      # (Cassandra):: Client connected to server
      def disconnect_all!
        @@keyspaces.each do |kyspc, conn|
          disconnect(kyspc)
        end
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
          while true
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
      # === Return
      # (Array):: Rows retrieved with each member being an instantiated object of the
      #   given class as value, but object only contains values for the columns retrieved
      def get_indexed(index, key, columns = nil, opt = {})
        if rows = real_get_indexed(index, key, columns, opt)
          rows.map do |key, columns|
            attrs = columns.inject({}) { |a, c| a[c.column.name] = c.column.value; a }
            new(key, attrs)
          end
        else
          []
        end
      end

      # Get all raw rows for specified secondary key
      #
      # === Parameters
      # index(String):: Name of secondary index
      # key(String):: Index value that each selected row is required to match
      # columns(Array|nil):: Names of columns to be retrieved, defaults to all
      # opt(Hash):: Request options with only :consistency used
      #
      # === Return
      # (Hash):: Rows retrieved with primary key as key and value being an array
      #   of CassandraThrift::ColumnOrSuperColumn with attributes :name, :timestamp,
      #   and :value
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
        if args.size>0 && args[args.size-1].kind_of?(Hash)         
          conn(args[args.size-1][:keyspace]).send(meth, *args, &block)
        else
          conn.send(meth, *args, &block)  
        end
      rescue IOError
        reconnect
        retry
      end

      # Reconnect to Cassandra server
      # Use BinaryProtocolAccelerated if it available
      #
      # === Return
      # true:: Always return true
      def reconnect
        config = @@config[ENV["RACK_ENV"]]
        raise MissingConfiguration, "CassandraModel config is missing a '#{ENV['RACK_ENV']}' section" unless config
        
        return false if @@default_keyspace.nil?
    
        thrift_client_options = {:timeout => RightSupport::DB::CassandraModel::DEFAULT_TIMEOUT}
        thrift_client_options.merge!({:protocol => Thrift::BinaryProtocolAccelerated})\
          if defined? Thrift::BinaryProtocolAccelerated

        connection = Cassandra.new(@@default_keyspace, config["server"], thrift_client_options)
        connection.disable_node_auto_discovery!
        @@keyspaces[@@default_keyspace] = connecton
        true
      end

      # Cassandra ring for given keyspace
      #
      # === Parameters
      # String:: keyspace
      #
      # === Return
      # (Array):: Members of ring
      def ring(kyspc=nil)
        conn(kyspc).ring
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
