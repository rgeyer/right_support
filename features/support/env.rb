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

require 'tmpdir'

require 'rubygems'
require 'bundler/setup'

require 'right_support'
require 'right_support/ci'

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

module RubyAppHelper
  def ruby_app_root
    @ruby_app_root ||= Dir.mktmpdir('right_support_cucumber_ruby')
  end

  def ruby_app_path(*args)
    path = ruby_app_root
    until args.empty?
      item = args.shift
      path = File.join(path, item)
    end
    path
  end

  # Run a shell command in app_dir, e.g. a rake task
  def ruby_app_shell(cmd, options={})
    ignore_errors = options[:ignore_errors] || false
    log = !!(Cucumber.logger)

    all_output = ''
    Dir.chdir(ruby_app_root) do
      Cucumber.logger.debug("bash> #{cmd}\n") if log
      IO.popen("#{cmd} 2>&1", 'r') do |output|
        output.sync = true
        done = false
        until done
          begin
            line = output.readline + "\n"
            all_output << line
            Cucumber.logger.debug(line) if log
          rescue EOFError
            done = true
          end
        end
      end
    end

    $?.success?.should(be_true) unless ignore_errors
    all_output
  end
end

module RightSupportWorld
  include RandomValueHelper
  include RubyAppHelper
end

# The Cucumber world
World(RightSupportWorld)

After do
  FileUtils.rm_rf(ruby_app_root) if File.directory?(ruby_app_root)
end

class Object
  include RandomValueHelper
end
