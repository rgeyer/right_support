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

require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))

describe RightSupport::Stats::Exceptions do

  include FlexMock::ArgumentTypes

  before(:each) do
    @now = 1000000
    flexmock(Time).should_receive(:now).and_return(@now).by_default
    @stats = RightSupport::Stats::Exceptions.new
    @exception = Exception.new("Test error")
  end

  it "should initialize stats data" do
    @stats.stats.should be_nil
    @stats.instance_variable_get(:@callback).should be_nil
  end

  it "should track submitted exception information by category" do
    @stats.track("testing", @exception)
    @stats.stats.should == {"testing" => {"total" => 1,
                                          "recent" => [{"count" => 1, "type" => "Exception", "message" => "Test error",
                                                        "when" => @now, "where" => nil}]}}
  end

  it "should recognize and count repeated exceptions" do
    @stats.track("testing", @exception)
    @stats.stats.should == {"testing" => {"total" => 1,
                                          "recent" => [{"count" => 1, "type" => "Exception", "message" => "Test error",
                                                        "when" => @now, "where" => nil}]}}
    flexmock(Time).should_receive(:now).and_return(1000010)
    category = "another"
    backtrace = ["here", "and", "there"]
    4.times do |i|
      begin
        raise ArgumentError, "badarg"
      rescue Exception => e
        flexmock(e).should_receive(:backtrace).and_return(backtrace)
        @stats.track(category, e)
        backtrace.shift(2) if i == 1
        category = "testing" if i == 2
      end
    end
    @stats.stats.should == {"testing" => {"total" => 2,
                                          "recent" => [{"count" => 1, "type" => "Exception", "message" => "Test error",
                                                        "when" => @now, "where" => nil},
                                                       {"count" => 1, "type" => "ArgumentError", "message" => "badarg",
                                                        "when" => @now + 10, "where" => "there"}]},
                            "another" => {"total" => 3,
                                          "recent" => [{"count" => 2, "type" => "ArgumentError", "message" => "badarg",
                                                        "when" => @now + 10, "where" => "here"},
                                                       {"count" => 1, "type" => "ArgumentError", "message" => "badarg",
                                                        "when" => @now + 10, "where" => "there"}]}}
  end

  it "should limit the number of exceptions stored by eliminating older exceptions" do
    (RightSupport::Stats::Exceptions::MAX_RECENT_EXCEPTIONS + 1).times do |i|
      begin
        raise ArgumentError, "badarg"
      rescue Exception => e
        flexmock(e).should_receive(:backtrace).and_return([i.to_s])
        @stats.track("testing", e)
      end
    end
    stats = @stats.stats
    stats["testing"]["total"].should == RightSupport::Stats::Exceptions::MAX_RECENT_EXCEPTIONS + 1
    stats["testing"]["recent"].size.should == RightSupport::Stats::Exceptions::MAX_RECENT_EXCEPTIONS
    stats["testing"]["recent"][0]["where"].should == "1"
  end

  it "should make callback if callback and message defined" do
    called = 0
    callback = lambda do |exception, message, server|
      called += 1
      exception.should == @exception
      message.should == "message"
      server.should == "server"
    end
    @stats = RightSupport::Stats::Exceptions.new("server", callback)
    @stats.track("testing", @exception, "message")
    @stats.stats.should == {"testing" => {"total" => 1,
                                          "recent" => [{"count" => 1, "type" => "Exception", "message" => "Test error",
                                                        "when" => @now, "where" => nil}]}}
    called.should == 1
  end

  it "should catch any exceptions raised internally and log them" do
    begin
      logger = flexmock("logger")
      logger.should_receive(:error).with(/Failed to track exception 'Test error' \(Exception: bad IN/).once
      RightSupport::Log::Mixin.default_logger = logger
      flexmock(@exception).should_receive(:backtrace).and_raise(Exception.new("bad"))
      @stats = RightSupport::Stats::Exceptions.new
      @stats.track("testing", @exception, "message")
      @stats.stats["testing"]["total"].should == 1
    ensure
      RightSupport::Log::Mixin.default_logger = nil
    end
  end

end # RightSupport::Stats::Exceptions
