#
# Copyright (c) 2009-2012 RightScale Inc
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

module RightSupport::Log
  # A log multiplexer that uses method_missing to dispatch method calls to zero or more
  # target loggers. Caveat emptor: _you_ are responsible for ensuring that all of the targets
  # respond to all of the messages you care to send; this class will perform no error checking
  # for you!
  class Multiplexer
    # Access to underlying list of multiplexed objects.
    attr_reader :targets

    # Prevent Kernel#warn from being called; #warn should be multiplexed to targets.
    undef warn rescue nil

    # Create a new multiplexer with a default list of targets.
    #
    # === Parameters
    # targets(Object):: Targets that should receive the method calls
    def initialize(*targets)
      @targets = targets || []
    end

    # Add object to list of multiplexed targets.
    #
    # === Parameters
    # target(Object):: Add target to list of multiplexed targets
    #
    # === Return
    # self(RightScale::Multiplexer):: self so operation can be chained
    def add(target)
      @targets << target unless @targets.include?(target)
      self
    end

    # Remove object from list of multiplexed targets.
    #
    # === Parameters
    # target(Object):: Remove target from list of multiplexed targets
    #
    # === Return
    # self(RightScale::Multiplexer):: self so operation can be chained
    def remove(target)
      @targets.delete_if { |t| t == target }
      self
    end

    # Access target at given index.
    #
    # === Parameters
    # index(Integer):: Target index
    #
    # === Return
    # target(Object):: Target at index 'index' or nil if none
    def [](index)
      target = @targets[index]
    end

    # Forward any method invocation to targets.
    #
    # === Parameters
    # m(Symbol):: Method that should be multiplexed
    # args(Array):: Arguments
    #
    # === Return
    # res(Object):: Result of first target in list
    def method_missing(m, *args)
      res = @targets.inject([]) { |res, t| res << t.__send__(m, *args) }
      res[0]
    end

    # Adhere to method_missing/respond_to metacontract: claim we
    # respond to the message if any of our targets does.
    #
    # Dispatch will still fail if not ALL of the targets respond
    # to a given method, hence the caveat that the user of this class
    # needs to ensure his targets are duck-type compatible with the
    # way they'll be used.
    #
    # === Parameters
    # m(Symbol):: Name of method
    #
    # === Return
    # respond_to(true|false):: true if this object or its targets respond to m, false otherwise
    def respond_to?(m)
      super(m) || @targets.any? { |t| t.respond_to?(m) }
    end
  end
end
