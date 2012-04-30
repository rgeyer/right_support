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

describe RightSupport::Stats do

  include FlexMock::ArgumentTypes

  before(:all) do
    @helpers = RightSupport::Stats
    @original_recent_size = RightSupport::Stats::Activity::RECENT_SIZE
    RightSupport::Stats::Activity.const_set(:RECENT_SIZE, 10)
  end

  after(:all) do
    RightSupport::Stats::Activity.const_set(:RECENT_SIZE, @original_recent_size)
  end

  before(:each) do
    @now = 1000000
    flexmock(Time).should_receive(:now).and_return(@now).by_default
    @exceptions = RightSupport::Stats::Exceptions.new
    @brokers = {"brokers"=> [{"alias" => "b0", "identity" => "rs-broker-localhost-5672", "status" => "connected",
                              "disconnect last" => nil,"disconnects" => nil, "failure last" => nil, "failures" => nil,
                              "retries" => nil},
                             {"alias" => "b1", "identity" => "rs-broker-localhost-5673", "status" => "disconnected",
                              "disconnect last" => {"elapsed" => 1000}, "disconnects" => 2,
                              "failure last" => nil, "failures" => nil, "retries" => nil},
                             {"alias" => "b2", "identity" => "rs-broker-localhost-5674", "status" => "failed",
                              "disconnect last" => nil, "disconnects" => nil,
                              "failure last" => {"elapsed" => 1000}, "failures" => 3, "retries" => 2}],
                "heartbeat" => nil,
                "exceptions" => {}}
  end

  context "percentage" do
    it "converts values to percentages" do
      stats = {"first" => 1, "second" => 4, "third" => 3}
      result = @helpers.percentage(stats)
      result.should == {"total" => 8, "percent" => {"first" => 12.5, "second" => 50.0, "third" => 37.5}}
    end
  end

  context "nil_if_zero" do
    it "converts 0 to nil" do
      @helpers.nil_if_zero(0).should be_nil
      @helpers.nil_if_zero(0.0).should be_nil
      @helpers.nil_if_zero(1).should == 1
      @helpers.nil_if_zero(1.0).should == 1.0
    end
  end

  context "elapsed" do
    it "converts elapsed time to displayable format" do
      @helpers.elapsed(0).should == "0 sec"
      @helpers.elapsed(1).should == "1 sec"
      @helpers.elapsed(60).should == "60 sec"
      @helpers.elapsed(61).should == "1 min 1 sec"
      @helpers.elapsed(62).should == "1 min 2 sec"
      @helpers.elapsed(120).should == "2 min 0 sec"
      @helpers.elapsed(3600).should == "60 min 0 sec"
      @helpers.elapsed(3601).should == "1 hr 0 min"
      @helpers.elapsed(3659).should == "1 hr 0 min"
      @helpers.elapsed(3660).should == "1 hr 1 min"
      @helpers.elapsed(3720).should == "1 hr 2 min"
      @helpers.elapsed(7200).should == "2 hr 0 min"
      @helpers.elapsed(7260).should == "2 hr 1 min"
      @helpers.elapsed(86400).should == "24 hr 0 min"
      @helpers.elapsed(86401).should == "1 day 0 hr 0 min"
      @helpers.elapsed(86459).should == "1 day 0 hr 0 min"
      @helpers.elapsed(86460).should == "1 day 0 hr 1 min"
      @helpers.elapsed(90000).should == "1 day 1 hr 0 min"
      @helpers.elapsed(183546).should == "2 days 2 hr 59 min"
      @helpers.elapsed(125.5).should == "2 min 5 sec"
    end
  end

  context "enough_precision" do
    it "converts floating point values to decimal digit string with at least two digit precision" do
      @helpers.enough_precision(100.5).should == "101"
      @helpers.enough_precision(100.4).should == "100"
      @helpers.enough_precision(99.0).should == "99"
      @helpers.enough_precision(10.5).should == "11"
      @helpers.enough_precision(10.4).should == "10"
      @helpers.enough_precision(9.15).should == "9.2"
      @helpers.enough_precision(9.1).should == "9.1"
      @helpers.enough_precision(1.05).should == "1.1"
      @helpers.enough_precision(1.01).should == "1.0"
      @helpers.enough_precision(1.0).should == "1.0"
      @helpers.enough_precision(0.995).should == "1.00"
      @helpers.enough_precision(0.991).should == "0.99"
      @helpers.enough_precision(0.0995).should == "0.100"
      @helpers.enough_precision(0.0991).should == "0.099"
      @helpers.enough_precision(0.00995).should == "0.0100"
      @helpers.enough_precision(0.00991).should == "0.0099"
      @helpers.enough_precision(0.000995).should == "0.00100"
      @helpers.enough_precision(0.000991).should == "0.00099"
      @helpers.enough_precision(0.000005).should == "0.00001"
      @helpers.enough_precision(0.000001).should == "0.00000"
      @helpers.enough_precision(0.0).should == "0"
      @helpers.enough_precision(55).should == "55"
      @helpers.enough_precision({"a" => 65.0, "b" => 23.0, "c" => 12.0}).should == {"a" => "65", "b" => "23", "c" => "12"}
      @helpers.enough_precision({"a" => 65.0, "b" => 33.0, "c" => 2.0}).should == {"a" => "65.0", "b" => "33.0", "c" => "2.0"}
      @helpers.enough_precision({"a" => 10.45, "b" => 1.0, "c" => 0.011}).should == {"a" => "10.5", "b" => "1.0", "c" => "0.011"}
      @helpers.enough_precision({"a" => 1000.0, "b" => 0.1, "c" => 0.0, "d" => 0.0001, "e" => 0.00001, "f" => 0.000001}).should ==
                                  {"a" => "1000.0", "b" => "0.10", "c" => "0.0", "d" => "0.00010", "e" => "0.00001", "f" => "0.00000"}
      @helpers.enough_precision([["a", 65.0], ["b", 23.0], ["c", 12.0]]).should == [["a", "65"], ["b", "23"], ["c", "12"]]
      @helpers.enough_precision([["a", 65.0], ["b", 33.0], ["c", 2.0]]).should == [["a", "65.0"], ["b", "33.0"], ["c", "2.0"]]
      @helpers.enough_precision([["a", 10.45], ["b", 1.0], ["c", 0.011]]).should == [["a", "10.5"], ["b", "1.0"], ["c", "0.011"]]
      @helpers.enough_precision([["a", 1000.0], ["b", 0.1], ["c", 0.0], ["d", 0.0001], ["e", 0.00001], ["f", 0.000001]]).should ==
                                [["a", "1000.0"], ["b", "0.10"], ["c", "0.0"], ["d", "0.00010"], ["e", "0.00001"], ["f", "0.00000"]]
    end
  end

  context "wrap" do
    it "wraps string by breaking it into lines at the specified separator" do
      string = "Now is the time for all good men to come to the aid of their people."
      indent = " " * 4
      result = @helpers.wrap(string, 20, indent, / /)
      result.should == "Now is the time for \n" +
                       "    all good men to \n" +
                       "    come to the aid \n" +
                       "    of their people."
      result.split("\n").select { |l| (l.chomp.size - indent.size) > 20 }.should be_empty

      string = "dogs: 2, cats: 10, hippopotami: 99, bears: 1, ants: 100000"
      indent = "--"
      result = @helpers.wrap(string, 22, indent, /, /)
      result.should == "dogs: 2, cats: 10, \n" +
                       "--hippopotami: 99, \n" +
                       "--bears: 1, \n" +
                       "--ants: 100000"
      result.split("\n").select { |l| (l.chomp.size - indent.size) > 22 }.should be_empty
    end

    it "wraps string by breaking into lines while ignoring encoding for color when measuring length" do
      string = "Now is the time for all good men to come to the aid of their people."
      colors = [:red, :blue, :green]
      c = 0
      string = string.split(" ").map { |s| s.send(colors[c = (c + 1) % 3]) }.join(" ")
      result = @helpers.wrap(string, 20, " " * 4, / /)
      result.should == "\e[1m\e[34mNow\e[0m \e[1m\e[32mis\e[0m \e[1m\e[31mthe\e[0m \e[1m\e[34mtime\e[0m \e[1m\e[32mfor\e[0m \n" +
                       "    \e[1m\e[31mall\e[0m \e[1m\e[34mgood\e[0m \e[1m\e[32mmen\e[0m \e[1m\e[31mto\e[0m \n" +
                       "    \e[1m\e[34mcome\e[0m \e[1m\e[32mto\e[0m \e[1m\e[31mthe\e[0m \e[1m\e[34maid\e[0m \n" +
                       "    \e[1m\e[32mof\e[0m \e[1m\e[31mtheir\e[0m \e[1m\e[34mpeople.\e[0m"
    end

    it "wraps string by breaking into lines with multiple separators" do
      string = "Failed receiving from queue request on b0 (RightScale::Serializer::SerializationError: Could not load " +
               "packet using [RightScale::SecureSerializer] (Failed to load with RightScale::SecureSerializer " +
               "(RightScale::SecureSerializer::InvalidSignature: Failed signature check for signer " +
               "rs-instance-1368fe0b6d4663dc1c92c54e05a8c37b3bd66be7-207607183 in " +
               "/home/rails/right_net/shared/bundle/ruby/1.9.1/bundler/gems/right_agent-aab761e02a9e/" +
               "lib/right_agent/serialize/secure_serializer.rb:136:in `load')) IN /Users/leekirchhoff/" +
               ".rightscale/right_net/ruby/1.8/bundler/gems/right_agent-4459d22fc542/lib/right_agent/" +
               "serialize/serializer.rb:133:in `cascade_serializers')"
      result = @helpers.wrap(string, 80, "", / |\/\/|\/|::|\.|-/)
      result.should == "Failed receiving from queue request on b0 (RightScale::Serializer::\n" +
                       "SerializationError: Could not load packet using [RightScale::SecureSerializer] \n" +
                       "(Failed to load with RightScale::SecureSerializer (RightScale::\n" +
                       "SecureSerializer::InvalidSignature: Failed signature check for signer rs-\n" +
                       "instance-1368fe0b6d4663dc1c92c54e05a8c37b3bd66be7-207607183 in /home/rails/\n" +
                       "right_net/shared/bundle/ruby/1.9.1/bundler/gems/right_agent-aab761e02a9e/lib/\n" +
                       "right_agent/serialize/secure_serializer.rb:136:in `load')) IN /Users/\n" +
                       "leekirchhoff/.rightscale/right_net/ruby/1.8/bundler/gems/right_agent-\n" +
                       "4459d22fc542/lib/right_agent/serialize/serializer.rb:133:in \n" +
                       "`cascade_serializers')"
      result.split("\n").select { |l| l.chomp.size > 80 }.should be_empty
    end
  end

  context "sort_key" do
    it "sorts hash by key into array with integer conversion of keys if possible" do
      @helpers.sort_key({"c" => 3, "a" => 1, "b" => 2}).should == [["a", 1], ["b", 2], ["c", 3]]
      @helpers.sort_key({3 => "c", 1 => "a", 2 => "b"}).should == [[1, "a"], [2, "b"], [3, "c"]]
      @helpers.sort_key({11 => "c", 9 => "a", 10 => "b"}).should == [[9, "a"], [10, "b"], [11, "c"]]
      @helpers.sort_key({"append_info" => 9.6, "create_new_section" => 8.5, "append_output" => 7.3, "record" => 4.7,
                         "update_status" => 4.4,
                         "declare" => 39.2, "list_agents" => 3.7, "update_tags" => 3.2, "append_error" => 3.0,
                         "add_user" => 2.4, "get_boot_bundle" => 1.4, "get_repositories" => 1.4,
                         "update_login_policy" => 1.3, "schedule_decommission" => 0.91, "update_inputs" => 0.75,
                         "delete_queues" => 0.75, "soft_decommission" => 0.75, "remove" => 0.66,
                         "get_login_policy" => 0.58, "ping" => 0.50, "update_entry" => 0.25, "query_tags" => 0.083,
                         "get_decommission_bundle" => 0.083, "list_queues" => 0.083}).should ==
                        [["add_user", 2.4], ["append_error", 3.0], ["append_info", 9.6], ["append_output", 7.3],
                         ["create_new_section", 8.5], ["declare", 39.2], ["delete_queues", 0.75], ["get_boot_bundle", 1.4],
                         ["get_decommission_bundle", 0.083], ["get_login_policy", 0.58], ["get_repositories", 1.4],
                         ["list_agents", 3.7], ["list_queues", 0.083], ["ping", 0.5], ["query_tags", 0.083],
                         ["record", 4.7], ["remove", 0.66], ["schedule_decommission", 0.91], ["soft_decommission", 0.75],
                         ["update_entry", 0.25], ["update_inputs", 0.75],
                         ["update_login_policy", 1.3], ["update_status", 4.4], ["update_tags", 3.2]]
    end
  end

  context "sort_value" do
    it "sorts hash by value into array" do
      @helpers.sort_value({"c" => 3, "a" => 2, "b" => 1}).should == [["b", 1], ["a", 2], ["c", 3]]
      @helpers.sort_value({"c" => 3.0, "a" => 2, "b" => 1.0}).should == [["b", 1.0], ["a", 2], ["c", 3.0]]
      @helpers.sort_value({"append_info" => 9.6, "create_new_section" => 8.5, "append_output" => 7.3, "record" => 4.7,
                           "update_status" => 4.4,
                           "declare" => 39.2, "list_agents" => 3.7, "update_tags" => 3.2, "append_error" => 3.0,
                           "add_user" => 2.4, "get_boot_bundle" => 1.4, "get_repositories" => 1.4,
                           "update_login_policy" => 1.3, "schedule_decommission" => 0.91, "update_inputs" => 0.75,
                           "delete_queues" => 0.75, "soft_decommission" => 0.75, "remove" => 0.66,
                           "get_login_policy" => 0.58, "ping" => 0.50, "update_entry" => 0.25, "query_tags" => 0.083,
                           "get_decommission_bundle" => 0.083, "list_queues" => 0.083}).should ==
                          [["list_queues", 0.083], ["query_tags", 0.083], ["get_decommission_bundle", 0.083],
                           ["update_entry", 0.25], ["ping", 0.5], ["get_login_policy", 0.58], ["remove", 0.66],
                           ["delete_queues", 0.75], ["soft_decommission", 0.75], ["update_inputs", 0.75],
                           ["schedule_decommission", 0.91], ["update_login_policy", 1.3], ["get_repositories", 1.4],
                           ["get_boot_bundle", 1.4], ["add_user", 2.4], ["append_error", 3.0], ["update_tags", 3.2],
                           ["list_agents", 3.7], ["update_status", 4.4],
                           ["record", 4.7], ["append_output", 7.3], ["create_new_section", 8.5], ["append_info", 9.6],
                           ["declare", 39.2]]
    end
  end

  context "brokers_str" do
    it "converts broker status to multi-line display string" do
      result = @helpers.brokers_str(@brokers, :name_width => 10)
      result.should == "brokers    : b0: rs-broker-localhost-5672 connected, disconnects: none, failures: none\n" +
                       "             b1: rs-broker-localhost-5673 disconnected, disconnects: 2 (16 min 40 sec ago), failures: none\n" +
                       "             b2: rs-broker-localhost-5674 failed, disconnects: none, failures: 3 (16 min 40 sec ago w/ 2 retries)\n" +
                       "             exceptions        : none\n" +
                       "             heartbeat         : none\n" +
                       "             returns           : none\n"
    end

    it "displays broker exceptions and returns" do
      @exceptions.track("testing", Exception.new("Test error"))
      @brokers["exceptions"] = @exceptions.stats
      @brokers["heartbeat"] = 60
      activity = RightSupport::Stats::Activity.new
      activity.update("no queue")
      activity.finish(@now - 10)
      activity.update("no queue consumers")
      activity.update("no queue consumers")
      flexmock(Time).should_receive(:now).and_return(1000010)
      @brokers["returns"] = activity.all
      result = @helpers.brokers_str(@brokers, :name_width => 10)
      result.should == "brokers    : b0: rs-broker-localhost-5672 connected, disconnects: none, failures: none\n" +
                       "             b1: rs-broker-localhost-5673 disconnected, disconnects: 2 (16 min 40 sec ago), failures: none\n" +
                       "             b2: rs-broker-localhost-5674 failed, disconnects: none, failures: 3 (16 min 40 sec ago w/ 2 retries)\n" +
                       "             exceptions        : testing total: 1, most recent:\n" +
                       "                                 (1) Mon Jan 12 05:46:40 Exception: Test error\n" +
                       "             heartbeat         : 60 sec\n" +
                       "             returns           : no queue consumers: 67%, no queue: 33%, total: 3, \n" +
                       "                                 last: no queue consumers (10 sec ago), rate: 0/sec\n"
    end
  end

  context "activity_str" do
    it 'converts activity stats to string' do
      activity = RightSupport::Stats::Activity.new
      activity.update("testing")
      activity.finish(@now - 10)
      activity.update("more testing")
      activity.update("more testing")
      activity.update("more testing")
      flexmock(Time).should_receive(:now).and_return(1000010)
      @helpers.activity_str(activity.all).should == "more testing: 75%, testing: 25%, total: 4, last: more testing (10 sec ago), " +
                                                    "rate: 0/sec"
    end

    it 'converts last activity stats to string' do
      activity = RightSupport::Stats::Activity.new
      activity.update("testing")
      activity.finish(@now - 10)
      activity.update("more testing")
      flexmock(Time).should_receive(:now).and_return(1000010)
      @helpers.last_activity_str(activity.last).should == "more testing: 10 sec ago"
      @helpers.last_activity_str(activity.last, single_item = true).should == "more testing (10 sec ago)"
    end
  end

  context "exceptions_str" do
    it "converts exception stats to multi-line string" do
      @exceptions.track("testing", Exception.new("This is a very long exception message that should be wrapped " +
                                                 "so that it stays within the maximum line length"))
      flexmock(Time).should_receive(:now).and_return(1000010)
      category = "another"
      backtrace = ["It happened here", "Over there"]
      4.times do |i|
        begin
          raise ArgumentError, "badarg"
        rescue Exception => e
          flexmock(e).should_receive(:backtrace).and_return(backtrace)
          @exceptions.track(category, e)
          backtrace.shift(1) if i == 1
          category = "testing" if i == 2
        end
      end

      result = @helpers.exceptions_str(@exceptions.stats, "----")
      result.should == "another total: 3, most recent:\n" +
                       "----(1) Mon Jan 12 05:46:50 ArgumentError: badarg IN Over there\n" +
                       "----(2) Mon Jan 12 05:46:50 ArgumentError: badarg IN It happened here\n" +
                       "----testing total: 2, most recent:\n" +
                       "----(1) Mon Jan 12 05:46:50 ArgumentError: badarg IN Over there\n" +
                       "----(1) Mon Jan 12 05:46:40 Exception: This is a very long exception message that \n" +
                       "----    should be wrapped so that it stays within the maximum line length"
    end
  end

  context "hash_str" do
    it "converts nested hash into string with keys sorted numerically if possible, else alphabetically" do
      hash = {"dogs" => 2, "cats" => 3, "hippopotami" => 99, "bears" => 1, "ants" => 100000000, "dragons" => nil,
              "food" => {"apples" => "bushels", "berries" => "lots", "meat" => {"fish" => 10.54, "beef" => nil}},
              "versions" => { "1" => 10, "5" => 50, "10" => 100} }
      result = @helpers.hash_str(hash)
      result.should == "ants: 100000000, bears: 1, cats: 3, dogs: 2, dragons: none, " +
                       "food: [ apples: bushels, berries: lots, meat: [ beef: none, fish: 11 ] ], " +
                       "hippopotami: 99, versions: [ 1: 10, 5: 50, 10: 100 ]"
      result = @helpers.wrap(result, 24, "----", /, /)
      result.should == "ants: 100000000, \n" +
                       "----bears: 1, cats: 3, \n" +
                       "----dogs: 2, \n" +
                       "----dragons: none, \n" +
                       "----food: [ apples: bushels, \n" +
                       "----berries: lots, \n" +
                       "----meat: [ beef: none, \n" +
                       "----fish: 11 ] ], \n" +
                       "----hippopotami: 99, \n" +
                       "----versions: [ 1: 10, \n" +
                       "----5: 50, 10: 100 ]"
    end
  end

  context "sub_stats_str" do
    it "converts sub-stats to a display string" do
      @exceptions.track("testing", Exception.new("Test error"))
      activity1 = RightSupport::Stats::Activity.new
      activity2 = RightSupport::Stats::Activity.new
      activity3 = RightSupport::Stats::Activity.new
      activity2.update("stats")
      activity2.update("testing")
      activity2.update("more testing")
      activity2.update("more testing")
      activity2.update("more testing")
      activity3.update("testing forever", "id")
      flexmock(Time).should_receive(:now).and_return(1002800)

      stats = {"exceptions" => @exceptions.stats,
               "empty_hash" => {},
               "float_value" => 3.15,
               "some % percent" => 3.54,
               "some time" => 0.675,
               "some rate" => 4.72,
               "some age" => 125,
               "activity1 %" => activity1.percentage,
               "activity1 last" => activity1.last,
               "activity2 %" => activity2.percentage,
               "activity2 last" => activity2.last,
               "activity3 last" => activity3.last,
               "some hash" => {"dogs" => 2, "cats" => 3, "hippopotami" => 99, "bears" => 1,
                               "ants" => 100000000, "dragons" => nil, "leopards" => 25}}

      result = @helpers.sub_stats_str("my sub-stats", stats, :name_width => 13, :sub_stat_value_width => 60)
      result.should == "my sub-stats  : activity1 %       : none\n" +
                       "                activity1 last    : none\n" +
                       "                activity2 %       : more testing: 75%, testing: 25%, total: 4\n" +
                       "                activity2 last    : more testing: 46 min 40 sec ago\n" +
                       "                activity3 last    : testing forever: 46 min 40 sec ago and still active\n" +
                       "                empty_hash        : none\n" +
                       "                exceptions        : testing total: 1, most recent:\n" +
                       "                                    (1) Mon Jan 12 05:46:40 Exception: Test error\n" +
                       "                float_value       : 3.2\n" +
                       "                some %            : 3.5%\n" +
                       "                some age          : 2 min 5 sec\n" +
                       "                some hash         : ants: 100000000, bears: 1, cats: 3, dogs: 2, dragons: none, \n" +
                       "                                    hippopotami: 99, leopards: 25\n" +
                       "                some rate         : 4.7/sec\n" +
                       "                some time         : 0.68 sec\n"
    end
  end

  context "stats_str" do
    it "converts stats to a display string with special formatting for generic keys" do
      @exceptions.track("testing", Exception.new("Test error"))
      activity = RightSupport::Stats::Activity.new
      activity.update("testing")
      flexmock(Time).should_receive(:now).and_return(1000010)
      sub_stats = {"exceptions" => @exceptions.stats,
                   "empty_hash" => {},
                   "float_value" => 3.15,
                   "activity %" => activity.percentage,
                   "activity last" => activity.last,
                   "some hash" => {"dogs" => 2, "cats" => 3, "hippopotami" => 99, "bears" => 1,
                                   "ants" => 100000000, "dragons" => nil, "leopards" => 25}}
      stats = {"stat time" => @now,
               "last reset time" => @now,
               "service uptime" => 3720,
               "machine uptime" => 183546,
               "version" => 10,
               "brokers" => @brokers,
               "hostname" => "localhost",
               "identity" => "unit tester",
               "stuff stats" => sub_stats}

      result = @helpers.stats_str(stats)
      result.should == "identity    : unit tester\n" +
                       "hostname    : localhost\n" +
                       "stat time   : Mon Jan 12 05:46:40\n" +
                       "last reset  : Mon Jan 12 05:46:40\n" +
                       "service up  : 1 hr 2 min\n" +
                       "machine up  : 2 days 2 hr 59 min\n" +
                       "version     : 10\n" +
                       "brokers     : b0: rs-broker-localhost-5672 connected, disconnects: none, failures: none\n" +
                       "              b1: rs-broker-localhost-5673 disconnected, disconnects: 2 (16 min 40 sec ago), failures: none\n" +
                       "              b2: rs-broker-localhost-5674 failed, disconnects: none, failures: 3 (16 min 40 sec ago w/ 2 retries)\n" +
                       "              exceptions        : none\n" +
                       "              heartbeat         : none\n" +
                       "              returns           : none\n" +
                       "stuff       : activity %        : testing: 100%, total: 1\n" +
                       "              activity last     : testing: 10 sec ago\n" +
                       "              empty_hash        : none\n" +
                       "              exceptions        : testing total: 1, most recent:\n" +
                       "                                  (1) Mon Jan 12 05:46:40 Exception: Test error\n" +
                       "              float_value       : 3.2\n" +
                       "              some hash         : ants: 100000000, bears: 1, cats: 3, dogs: 2, dragons: none, hippopotami: 99, \n" +
                       "                                  leopards: 25\n"
    end

    it "treats broker status, version, and machine uptime as optional" do
      sub_stats = {"exceptions" => @exceptions.stats,
                   "empty_hash" => {},
                   "float_value" => 3.15}

      stats = {"stat time" => @now,
               "last reset time" => @now,
               "service uptime" => 1000,
               "hostname" => "localhost",
               "identity" => "unit tester",
               "stuff stats" => sub_stats}

      result = @helpers.stats_str(stats)
      result.should == "identity    : unit tester\n" +
                       "hostname    : localhost\n" +
                       "stat time   : Mon Jan 12 05:46:40\n" +
                       "last reset  : Mon Jan 12 05:46:40\n" +
                       "service up  : 16 min 40 sec\n" +
                       "stuff       : empty_hash        : none\n" +
                       "              exceptions        : none\n" +
                       "              float_value       : 3.2\n"
    end

    it "displays name if provided" do
      sub_stats = {"exceptions" => @exceptions.stats,
                   "empty_hash" => {},
                   "float_value" => 3.15}

      stats = {"stat time" => @now,
               "last reset time" => @now,
               "service uptime" => 1000,
               "hostname" => "localhost",
               "identity" => "unit tester",
               "name" => "tester_1",
               "stuff stats" => sub_stats}

      result = @helpers.stats_str(stats)
      result.should == "name        : tester_1\n" +
                       "identity    : unit tester\n" +
                       "hostname    : localhost\n" +
                       "stat time   : Mon Jan 12 05:46:40\n" +
                       "last reset  : Mon Jan 12 05:46:40\n" +
                       "service up  : 16 min 40 sec\n" +
                       "stuff       : empty_hash        : none\n" +
                       "              exceptions        : none\n" +
                       "              float_value       : 3.2\n"
    end

    it "sorts stats using optional prefix" do
      sub_stats = {"empty_hash" => {},
                   "float_value" => 3.15}

      stats = {"stat time" => @now,
               "last reset time" => @now,
               "service uptime" => 1000,
               "hostname" => "localhost",
               "identity" => "unit tester",
               "stuff stats" => sub_stats,
               "other stuff stats" => sub_stats,
               "/data stats" => sub_stats}

      result = @helpers.stats_str(stats, :sub_name_width => 11)
      result.should == "identity    : unit tester\n" +
                       "hostname    : localhost\n" +
                       "stat time   : Mon Jan 12 05:46:40\n" +
                       "last reset  : Mon Jan 12 05:46:40\n" +
                       "service up  : 16 min 40 sec\n" +
                       "/data       : empty_hash  : none\n" +
                       "              float_value : 3.2\n" +
                       "other stuff : empty_hash  : none\n" +
                       "              float_value : 3.2\n" +
                       "stuff       : empty_hash  : none\n" +
                       "              float_value : 3.2\n"

      stats = {"stat time" => @now,
               "last reset time" => @now,
               "service uptime" => 1000,
               "hostname" => "localhost",
               "identity" => "unit tester",
               "stuff 0stats" => sub_stats,
               "other stuff 1stats" => sub_stats,
               "/data stats" => sub_stats}

      result = @helpers.stats_str(stats, :name_width => 15)
      result.should == "identity        : unit tester\n" +
                       "hostname        : localhost\n" +
                       "stat time       : Mon Jan 12 05:46:40\n" +
                       "last reset      : Mon Jan 12 05:46:40\n" +
                       "service up      : 16 min 40 sec\n" +
                       "stuff           : empty_hash        : none\n" +
                       "                  float_value       : 3.2\n" +
                       "other stuff     : empty_hash        : none\n" +
                       "                  float_value       : 3.2\n" +
                       "/data           : empty_hash        : none\n" +
                       "                  float_value       : 3.2\n"
    end
  end

end # RightSupport::Stats
