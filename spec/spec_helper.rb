# Copyright (c) 2012- RightScale Inc
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

require 'rubygems'
require 'bundler/setup'
require 'flexmock'
require 'ruby-debug'
require 'syntax'

require 'right_support'

RSpec.configure do |config|
  config.mock_with :flexmock
end

def read_fixture(fn)
  basedir = File.expand_path('../..', __FILE__)
  fixtures_dir = File.join(basedir, 'spec', 'fixtures')
  File.read(File.join(fixtures_dir, fn))
end

def corrupt(key, factor=4)
  d = key.size / 2

  key[0..(d-factor)] + key[d+factor..-1]
end

RSpec::Matchers.define :have_green_endpoint do |endpoint|
  match do |balancer|
    stack = balancer.instance_variable_get(:@stack)
    state = stack.instance_variable_get(:@endpoints)
    state = state[endpoint] if state.respond_to?(:[])
    unless stack && state && state.key?(:n_level)
      raise ArgumentError, "Custom matcher is incompatible with new HealthCheck implementation!"
    end
    state[:n_level] == 0
  end
end

RSpec::Matchers.define :have_yellow_endpoint do |endpoint, n|
  match do |balancer|
    stack = balancer.instance_variable_get(:@stack)
    max_n = stack.instance_variable_get(:@yellow_states)
    state = stack.instance_variable_get(:@endpoints)
    state = state[endpoint] if state.respond_to?(:[])
    unless max_n && stack && state && state.key?(:n_level)
      raise ArgumentError, "Custom matcher is incompatible with new HealthCheck implementation!"
    end

    if n
      state[:n_level].should == n
    else
      (1...max_n).should include(state[:n_level])
    end
  end
end

RSpec::Matchers.define :have_red_endpoint do |endpoint|
  match do |balancer|
    stack = balancer.instance_variable_get(:@stack)
    max_n = stack.instance_variable_get(:@yellow_states)
    state = stack.instance_variable_get(:@endpoints)
    state = state[endpoint] if state.respond_to?(:[])
    unless max_n && stack && state && state.key?(:n_level)
      raise ArgumentError, "Custom matcher is incompatible with new HealthCheck implementation!"
    end
    min = 1
    state[:n_level].should == max_n
  end
end

def find_empirical_distribution(trials=2500, list=[1,2,3,4,5])
  seen = {}

  trials.times do
    value = yield
    seen[value] ||= 0
    seen[value] += 1
  end

  seen
end

def test_random_distribution(trials=25000, list=[1,2,3,4,5], &block)
  seen = find_empirical_distribution(trials, &block)
  should_be_chosen_fairly(seen,trials,list.size)
end

def should_be_chosen_fairly(seen, trials, size)
  #Load should be evenly distributed
  chance = 1.0 / size
  seen.each_pair do |_, count|
    (Float(count) / Float(trials)).should be_within(0.025).of(chance) #allow 5% margin of error
  end
end

RANDOM_KEY_CLASSES   = [String, Integer, Float, TrueClass, FalseClass]
RANDOM_VALUE_CLASSES = RANDOM_KEY_CLASSES + [Array, Hash]

def random_value(klass=nil, depth=0)
  if klass.nil?
    if depth < 5
      klasses = RANDOM_VALUE_CLASSES
    else
      klasses = RANDOM_KEY_CLASSES
    end

    klass = klasses[rand(klasses.size)]
  end

  if klass == String
    result = ''
    io = StringIO.new(result, 'w')
    rand(40).times { io.write(0x61 + rand(26)) }
    io.close
  elsif klass == Integer
    result = rand(0xffffff)
  elsif klass == Float
    result = rand(0xffffff) * rand
  elsif klass == TrueClass
    result = true
  elsif klass == FalseClass
    result = false
  elsif klass == Array
    result = []
    rand(10).times { result << random_value(nil, depth+1) }
  elsif klass == Hash
    result = {}
    key_type = RANDOM_KEY_CLASSES[rand(RANDOM_KEY_CLASSES.size)]
    rand(10).times { result[random_value(key_type, depth+1)] = random_value(nil, depth+1) }
  else
    raise ArgumentError, "Unknown random value type #{klass}"
  end

  result
end

def mock_logger
  logger = flexmock(Logger.new(StringIO.new))
end

module SpecHelper
  module SocketMocking
    def mock_getaddrinfo(hostname, addresses)
      boring_args = [nil, Socket::AF_INET, Socket::SOCK_STREAM, Socket::IPPROTO_TCP]

      infos = []

      addresses.each do |addr|
        infos << [0,0,0,addr]
      end

      flexmock(Socket).should_receive(:getaddrinfo).with(hostname, *boring_args).once.and_return(infos)
    end
  end
end
