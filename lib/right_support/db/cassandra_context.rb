#
# Copyright (c) 2012 RightScale Inc
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


module RightSupport::DB

  # Proxy object, that keeps context
  # keyspace and column family
  # of calling Cassandra
  class CassandraContext
    
    attr_reader :current_keyspace

    def initialize(klass, kyspc)
      raise ArgumentError if (klass.nil?) || (!klass.kind_of?(Class))
      
      @base_klass = klass
      @current_keyspace = kyspc
    end
    
    def conn
      @base_klass.conn(@current_keyspace)
    end

    def all(k, opts = {})
      @base_klass.all(k, opts.merge({:keyspace=>@current_keyspace}))
    end   

    def get(k, opts = {})
      @base_klass.get(k, opts.merge({:keyspace=>@current_keyspace}))
    end

    def get_indexed(index, key, columns = nil, opt = {})
      @base_klass.get_indexed(index, key, columns = nil, opt.merge({:keyspace=>@current_keyspace}))
    end
    
    def get_columns(key, columns, opt = {})
      @base_klass.get_columns(key, columns, opt.merge({:keyspace=>@current_keyspace}))
    end   
    
    def insert(key, values, opt={})
      @base_klass.insert(key, values, opt.merge({:keyspace=>@current_keyspace}))
    end
    
    def remove(*args)
      if args[args.size-1].kind_of?(Hash)
        args[args.size-1].merge({:keyspace=>@current_keyspace})
      else
        args.push({:keyspace=>@current_keyspace})
      end
      @base_klass.remove(args)
    end

    def batch(*args, &block)
      if args[args.size-1].kind_of?(Hash)
        args[args.size-1].merge({:keyspace=>@current_keyspace})
      else
        args.push({:keyspace=>@current_keyspace})
      end
      @base_klass.batch(args, block)      
    end

    def ring
      @base_klass.ring(@current_keyspace)
    end

  end

end
