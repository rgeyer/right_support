#--
# Copyright: Copyright (c) 2010 RightScale, Inc.
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# 'Software'), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
# IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
# CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
# TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
# SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#++

require 'rubygems'
require 'bundler/setup'

$basedir = File.expand_path('../../..', __FILE__)
$libdir  = File.join($basedir, 'lib')
require File.join($libdir, 'right_support')

module RandomValueHelper
  RANDOM_KEY_CLASSES   = [String, Integer, Float, TrueClass, FalseClass]
  RANDOM_VALUE_CLASSES = RANDOM_KEY_CLASSES + [Array, Hash]

  def random_value(klass=nil, key_classes=RANDOM_KEY_CLASSES, depth=0)
    if klass.nil?
      if depth < 3 && key_classes.nil?
        klasses = RANDOM_VALUE_CLASSES
      else
        klasses = key_classes
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
      rand(10).times { result << random_value(nil, key_classes,depth+1) }
    elsif klass == Hash
      result = {}
      if string_keys
        key_type = String
      else
        key_type = RANDOM_KEY_CLASSES[rand(RANDOM_KEY_CLASSES.size)]
      end
      rand(10).times { result[random_value(key_type, key_classes, depth+1)] = random_value(nil, key_classes, depth+1) }
    else
      raise ArgumentError, "Unknown random value type #{klass}"
    end

    result
  end
end

World(RandomValueHelper)
class Object
  include RandomValueHelper
end
