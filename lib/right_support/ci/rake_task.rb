require 'rake/tasklib'

# Make sure the rest of RightSupport is required, since this file can be
# required directly.
require 'right_support'

module RightSupport::CI
  # A Rake task definition that creates a CI namespace with appropriate
  # tests.
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
          FileUtils.mkdir_p('measurement')

          # Tweak RUBYOPT so RubyGems and RightSupport are automatically required.
          # This is necessary because Cucumber doesn't have a -r equivalent we can
          # use to inject ourselves into its process. (There is an -r, but it disables
          # auto-loading.)
          rubyopt = '-rright_support'
          if ENV.key?('RUBYOPT')
            rubyopt = ENV['RUBYOPT'] + ' ' + rubyopt
            rubyopt = '-rrubygems ' + rubyopt unless (rubyopt =~ /ubygems/)
          end
          ENV['RUBYOPT'] = rubyopt
        end

        if require_succeeds?('rspec/core/rake_task')
          # RSpec 2
          desc "Run RSpec examples"
          RSpec::Core::RakeTask.new(:spec => :prep) do |t|
            t.rspec_opts = ['-f', JUnitRSpecFormatter.name,
                            '-o', File.join(@output_path, 'rspec', 'rspec.xml')]
          end
        elsif require_succeeds?('spec/rake/spectask')
          # RSpec 1
          Spec::Rake::SpecTask.new(:spec => :prep) do |t|
            desc "Run RSpec Examples"
            t.spec_opts = ['-f', JUnitRSpecFormatter.name + ":" + File.join(@output_path, 'rspec', 'rspec.xml')]
          end
        end

        if require_succeeds?('cucumber/rake/task')
          desc "Run Cucumber features"
          Cucumber::Rake::Task.new do |t|
            t.cucumber_opts = ['--no-color',
                               '--format', JUnitCucumberFormatter.name,
                               '--out', File.join(@output_path, 'cucumber')]
          end
          task :cucumber => [:prep]
        end
      end
    end
  end
end
