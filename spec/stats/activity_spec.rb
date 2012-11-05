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

describe RightSupport::Stats::Activity do

  include FlexMock::ArgumentTypes

  before(:all) do
    @original_recent_size = RightSupport::Stats::Activity::RECENT_SIZE
    RightSupport::Stats::Activity.instance_eval { remove_const(:RECENT_SIZE) }
    RightSupport::Stats::Activity.const_set(:RECENT_SIZE, 10)
  end

  after(:all) do
    RightSupport::Stats::Activity.instance_eval { remove_const(:RECENT_SIZE) }
    RightSupport::Stats::Activity.const_set(:RECENT_SIZE, @original_recent_size)
  end

  before(:each) do
    @now = 1000000
    flexmock(Time).should_receive(:now).and_return(@now).by_default
    @stats = RightSupport::Stats::Activity.new
  end

  it "initializes stats data" do
    @stats.instance_variable_get(:@interval).should == 0.0
    @stats.instance_variable_get(:@last_start_time).should == @now
    @stats.instance_variable_get(:@avg_duration).should be_nil
    @stats.instance_variable_get(:@total).should == 0
    @stats.instance_variable_get(:@count_per_type).should == {}
  end

  it "updates count and interval information" do
    flexmock(Time).should_receive(:now).and_return(1000010)
    @stats.update
    @stats.instance_variable_get(:@interval).should == 1.0
    @stats.instance_variable_get(:@last_start_time).should == @now + 10
    @stats.instance_variable_get(:@avg_duration).should be_nil
    @stats.instance_variable_get(:@total).should == 1
    @stats.instance_variable_get(:@count_per_type).should == {}
  end

  it "updates weight the average interval toward recent activity" do
  end

  it "updates counts per type when type provided" do
    flexmock(Time).should_receive(:now).and_return(1000010)
    @stats.update("test")
    @stats.instance_variable_get(:@interval).should == 1.0
    @stats.instance_variable_get(:@last_start_time).should == @now + 10
    @stats.instance_variable_get(:@avg_duration).should be_nil
    @stats.instance_variable_get(:@total).should == 1
    @stats.instance_variable_get(:@count_per_type).should == {"test" => 1}
  end

  it "doesn't update counts when type contains 'stats'" do
    flexmock(Time).should_receive(:now).and_return(1000010)
    @stats.update("my stats")
    @stats.instance_variable_get(:@interval).should == 0.0
    @stats.instance_variable_get(:@last_start_time).should == @now
    @stats.instance_variable_get(:@avg_duration).should be_nil
    @stats.instance_variable_get(:@total).should == 0
    @stats.instance_variable_get(:@count_per_type).should == {}
  end

  it "limits length of type string when submitting update" do
    flexmock(Time).should_receive(:now).and_return(1000010)
    @stats.update("test 12345678901234567890123456789012345678901234567890123456789")
    @stats.instance_variable_get(:@total).should == 1
    @stats.instance_variable_get(:@count_per_type).should ==
            {"test 1234567890123456789012345678901234567890123456789012..." => 1}
  end

  it "doesn't convert symbol or boolean to string when submitting update" do
    flexmock(Time).should_receive(:now).and_return(1000010)
    @stats.update(:test)
    @stats.update(true)
    @stats.update(false)
    @stats.instance_variable_get(:@total).should == 3
    @stats.instance_variable_get(:@count_per_type).should == {:test => 1, true => 1, false => 1}
  end

  it "converts arbitrary type value to limited-length string when submitting update" do
    flexmock(Time).should_receive(:now).and_return(1000010)
    @stats.update({1 => 11, 2 => 22})
    @stats.update({1 => 11, 2 => 22, 3 => 12345678901234567890123456789012345678901234567890123456789})
    @stats.instance_variable_get(:@total).should == 2
    @stats.instance_variable_get(:@count_per_type).should == {"{1=>11, 2=>22}" => 1,
                                                              "{1=>11, 2=>22, 3=>123456789012345678901234567890123456789..." => 1}
  end

  it "doesn't measure rate if disabled" do
    @stats = RightSupport::Stats::Activity.new(false)
    flexmock(Time).should_receive(:now).and_return(1000010)
    @stats.update
    @stats.instance_variable_get(:@interval).should == 0.0
    @stats.instance_variable_get(:@last_start_time).should == @now + 10
    @stats.instance_variable_get(:@avg_duration).should be_nil
    @stats.instance_variable_get(:@total).should == 1
    @stats.instance_variable_get(:@count_per_type).should == {}
    @stats.all.should == {"last" => {"elapsed"=>0}, "total" => 1}
  end

  it "updates duration when finish using internal start time by default" do
    flexmock(Time).should_receive(:now).and_return(1000010)
    @stats.finish
    @stats.instance_variable_get(:@interval).should == 0.0
    @stats.instance_variable_get(:@last_start_time).should == @now
    @stats.instance_variable_get(:@avg_duration).should == 1.0
    @stats.instance_variable_get(:@total).should == 0
    @stats.instance_variable_get(:@count_per_type).should == {}
  end

  it "updates duration when finish using specified start time" do
    flexmock(Time).should_receive(:now).and_return(1000030)
    @stats.avg_duration.should be_nil
    @stats.finish(1000010)
    @stats.instance_variable_get(:@interval).should == 0.0
    @stats.instance_variable_get(:@last_start_time).should == @now
    @stats.instance_variable_get(:@avg_duration).should == 2.0
    @stats.instance_variable_get(:@total).should == 0
    @stats.instance_variable_get(:@count_per_type).should == {}
  end

  it "converts interval to rate" do
    flexmock(Time).should_receive(:now).and_return(1000020)
    @stats.avg_rate.should be_nil
    @stats.update
    @stats.instance_variable_get(:@interval).should == 2.0
    @stats.avg_rate.should == 0.5
  end

  it "reports number of seconds since last update or nil if no updates" do
    flexmock(Time).should_receive(:now).and_return(1000010)
    @stats.last.should be_nil
    @stats.update
    @stats.last.should == {"elapsed" => 0}
  end

  it "reports number of seconds since last update and last type" do
    @stats.update("test")
    flexmock(Time).should_receive(:now).and_return(1000010)
    @stats.last.should == {"elapsed" => 10, "type" => "test"}
  end

  it "reports whether last activity is still active" do
    @stats.update("test", "token")
    flexmock(Time).should_receive(:now).and_return(1000010)
    @stats.last.should == {"elapsed" => 10, "type" => "test", "active" => true}
    @stats.finish(@now - 10, "token")
    @stats.last.should == {"elapsed" => 10, "type" => "test", "active" => false}
    @stats.instance_variable_get(:@avg_duration).should == 2.0
  end

  it "converts count per type to percentages" do
    flexmock(Time).should_receive(:now).and_return(1000010)
    @stats.update("foo")
    @stats.instance_variable_get(:@total).should == 1
    @stats.instance_variable_get(:@count_per_type).should == {"foo" => 1}
    @stats.percentage.should == {"total" => 1, "percent" => {"foo" => 100.0}}
    @stats.update("bar")
    @stats.instance_variable_get(:@total).should == 2
    @stats.instance_variable_get(:@count_per_type).should == {"foo" => 1, "bar" => 1}
    @stats.percentage.should == {"total" => 2, "percent" => {"foo" => 50.0, "bar" => 50.0}}
    @stats.update("foo")
    @stats.update("foo")
    @stats.instance_variable_get(:@total).should == 4
    @stats.instance_variable_get(:@count_per_type).should == {"foo" => 3, "bar" => 1}
    @stats.percentage.should == {"total" => 4, "percent" => {"foo" => 75.0, "bar" => 25.0}}
  end

end # RightSupport::Stats::Activity
