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

require 'rake/tasklib'

# Make sure the rest of RightSupport is required, since this file can be
# required directly.
require 'right_support'

module RightSupport::CI
  # A Rake task definition that creates a CI namespace with appropriate
  # tests.
  #
  # @deprecated Please do not use this class
  # @see RightDevelop::CI::RakeTask
  class RakeTask < ::Rake::TaskLib
    include ::Rake::DSL if defined?(::Rake::DSL)

    # The namespace in which to define the continuous integration tasks.
    #
    # Default :ci
    attr_accessor :ci_namespace

    # The base directory for output files.
    #
    # Default 'measurement'
    attr_accessor :output_path

    def initialize(*args)
      @ci_namespace = args.shift || :ci

      yield self if block_given?

      @output_path ||= 'measurement'

      namespace @ci_namespace do
        task :prep do
          FileUtils.mkdir_p(@output_path)
          FileUtils.mkdir_p(File.join(@output_path, 'rspec'))
          FileUtils.mkdir_p(File.join(@output_path, 'cucumber'))
        end

        if require_succeeds?('rspec/core/rake_task')
          # RSpec 2
          desc "Run RSpec examples"
          RSpec::Core::RakeTask.new(:spec => :prep) do |t|
            t.rspec_opts = ['-r', 'right_support/ci',
                            '-f', JavaSpecFormatter.name,
                            '-o', File.join(@output_path, 'rspec', 'rspec.xml')]
          end
        elsif require_succeeds?('spec/rake/spectask')
          # RSpec 1
          Spec::Rake::SpecTask.new(:spec => :prep) do |t|
            desc "Run RSpec Examples"
            t.spec_opts = ['-r', 'right_support/ci',
                           '-f', JavaSpecFormatter.name + ":" + File.join(@output_path, 'rspec', 'rspec.xml')]
          end
        end

        if require_succeeds?('cucumber/rake/task')
          desc "Run Cucumber features"
          Cucumber::Rake::Task.new do |t|
            t.cucumber_opts = ['--no-color',
                               '--format', JavaCucumberFormatter.name,
                               '--out', File.join(@output_path, 'cucumber')]
          end
          task :cucumber => [:prep]
        end
      end
    end
  end
end
