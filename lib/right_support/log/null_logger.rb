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

require 'logger'

module RightSupport::Log
  # A logger than does not perform any logging. This is useful to send log entries
  # to "the bit bucket" or "to /dev/null" -- hence the name.
  class NullLogger < Logger
    # Initialize a new instance of this class.
    #
    def initialize
      super(nil)
    end

    # Do nothing. This method exists for interface compatibility with Logger.
    #
    # === Parameters
    # severity(Integer):: one of the Logger severity constants
    # message(String):: the message to log, or nil
    # progname(String):: the program name, or nil
    #
    # === Block
    # If message == nil and a block is given, yields to the block. The block's
    # output value is ignored.
    #
    # === Return
    # always returns true
    def add(severity, message = nil, progname = nil, &block)
      #act like a real Logger w/r/t the block
      yield if message.nil? && block_given?
      true
    end

    # Do nothing. This method exists for interface compatibility with Logger.
    #
    # === Parameters
    # msg(String):: the message to log, or nil
    #
    # === Block
    # If message == nil and a block is given, yields to the block. The block's
    # output value is ignored.
    #
    # === Return
    def <<(msg)
      msg.to_s.size
    end

    # Do nothing. This method exists for interface compatibility with Logger.
    #
    # === Return
    # always returns true
    def close
      nil
    end
  end
end