# Monkey patch Cassandra gem so that it accepts list of columns when doing indexed slice
# otherwise not able to get specific columns using secondary index lookup
require 'cassandra/0.8'
class Cassandra
  module Protocol
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
end

module RightSupport::DB

  # Base class for a column family in a keyspace
  # Used to access data persisted in Cassandra
  # Provides wrappers for Cassandra client methods
  class CassandraModel

    # Default timeout for client connection to Cassandra server
    DEFAULT_TIMEOUT = 10

    # Wrappers for Cassandra client
    class << self

      @@logger = nil
      @@conn = nil
      
      attr_accessor :column_family
      attr_writer :keyspace

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
        @keyspace + "_" + (ENV['RACK_ENV'] || 'development')
      end

      # Client connected to Cassandra server
      # Create connection if does not already exist
      #
      # === Return
      # (Cassandra):: Client connected to server
      def conn
        return @@conn if @@conn

        config = @@config[ENV["RACK_ENV"]]
        @@conn = Cassandra.new(keyspace, config["server"],{:timeout => RightSupport::DB::CassandraModel::DEFAULT_TIMEOUT})
        @@conn.disable_node_auto_discovery!
        @@conn
      end

      # Get row(s) for specified key(s)
      #
      # === Parameters
      # k(String|Array):: Individual primary key or list of keys on which to match
      # opt(Hash):: Request options such as :consistency, and when getting
      #   multiple rows also :count, :start, :finish, :reversed
      #
      # === Return
      # (Object|nil):: Individual row, or nil if not found, or ordered hash of rows
      def all(k, opt = {})
        real_get(k, opt)
      end
      
      # Get row for specified primary key and convert into object of given class
      #
      # === Parameters
      # key(String):: Primary key on which to match
      # opt(Hash):: Request options such as :consistency
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
      #
      # === Parameters
      # k(String|Array):: Individual primary key or list of keys on which to match
      # opt(Hash):: Request options such as :consistency, and when getting
      #   multiple rows also :count, :start, :finish, :reversed
      #
      # === Return
      # (Object|nil):: Individual row, or nil if not found, or ordered hash of rows
      def real_get(k, opt = {})
        if k.is_a?(Array)
          do_op(:multi_get, column_family, k, opt)
        else      
          do_op(:get, column_family, k, opt)
        end
      end

      # Get rows for specified secondary key
      #
      # === Parameters
      # index(String):: Name of secondary index
      # key(String):: Index value that each selected row is required to match
      # columns(Array|nil):: Names of columns to be retrieved, defaults to all
      # opt(Hash):: Request options such as :consistency
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

      # Get raw rows for specified secondary key
      #
      # === Parameters
      # index(String):: Name of secondary index
      # key(String):: Index value that each selected row is required to match
      # columns(Array|nil):: Names of columns to be retrieved, defaults to all
      # opt(Hash):: Request options such as :consistency
      #
      # === Return
      # (Array):: List of rows retrieved with each member being a CassandraThrift::KeySlice
      #   and with attributes keys :key and :columns and with the :columns attribute being
      #   an array of CassandraThrift::ColumnOrSuperColumn with attributes :name, :timestamp,
      #   and :value
      def real_get_indexed(index, key, columns = nil, opt = {})
        expr = do_op(:create_idx_expr, index, key, "EQ")
        clause = do_op(:create_idx_clause, [expr])
        do_op(:get_indexed_slices, column_family, clause, columns, opt)
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
      # true:: Always return true
      def insert(key, values, opt={})
        do_op(:insert, column_family, key, values, opt)
        true
      end

      # Delete row or columns of row
      #
      # === Parameters
      # args(Array):: Key, columns, options
      #
      # === Return
      # true:: Always return true
      def remove(*args)
        do_op(:remove, column_family, *args)
        true
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
      # true:: Always return true
      #
      # === Raise
      # Exception:: If block not specified
      def batch(*args, &block)
        raise "Block required!" unless block_given?
        do_op(:batch, *args, &block)
        true
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
        conn.send(meth, *args, &block)
      rescue IOError
        reconnect
        retry
      end

      # Reconnect to Cassandra server
      #
      # === Return
      # true:: Always return true
      def reconnect
        config = @@config[ENV["RACK_ENV"]]
        @@conn = Cassandra.new(keyspace, config["server"], {:timeout => RightSupport::DB::CassandraModel::DEFAULT_TIMEOUT})
        @@conn.disable_node_auto_discovery!
        true
      end

      # Cassandra ring for given keyspace
      #
      # === Return
      # (Array):: Members of ring
      def ring
        conn.ring
      end
    end

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
