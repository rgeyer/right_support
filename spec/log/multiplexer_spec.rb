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

require 'spec_helper'

describe RightSupport::Log::Multiplexer do

  before(:all) do
    @target1 = RightSupport::Log::NullLogger.new
    @target2 = RightSupport::Log::NullLogger.new
    @target3 = RightSupport::Log::NullLogger.new
    @multiplexer = RightSupport::Log::Multiplexer.new(@target1, @target2, @target3)
  end

  it 'multiplexes method calls to all callers' do
    flexmock(@target1).should_receive(:some_method).with('arg', 'arg2').once
    flexmock(@target2).should_receive(:some_method).with('arg', 'arg2').once
    flexmock(@target3).should_receive(:some_method).with('arg', 'arg2').once
    @multiplexer.some_method('arg', 'arg2')
  end

  it 'returns the result returned by the first target' do
    flexmock(@target1).should_receive(:some_method).with('arg', 'arg2').and_return('res1').once
    flexmock(@target2).should_receive(:some_method).with('arg', 'arg2').and_return('res2').once
    flexmock(@target3).should_receive(:some_method).with('arg', 'arg2').and_return('res3').once
    @multiplexer.some_method('arg', 'arg2').should == 'res1'
  end

  it 'multiplexes #warn by undefining Object#warn' do
    flexmock(@target1).should_receive(:warn).with('arg').and_return('res1')
    flexmock(@target2).should_receive(:warn).with('arg').and_return('res2')
    flexmock(@target3).should_receive(:warn).with('arg').and_return('res3')
    @multiplexer.warn('arg').should == 'res1'
  end
end
