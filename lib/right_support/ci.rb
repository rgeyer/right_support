module RightSupport
  module CI
  end
end

require 'right_support/ci/junit_cucumber_formatter'
require 'right_support/ci/junit_rspec_formatter'

# Don't auto-require the Rake task; it mixes the Rake DSL into everything!
# Must defer loading of the Rake task to the Rakefiles
#require 'right_support/ci/rake_task'
