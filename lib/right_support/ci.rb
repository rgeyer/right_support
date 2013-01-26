module RightSupport
  # @deprecated Please do not use the contents of this module
  # @see RightDevelop::CI
  module CI
  end
end

require 'right_support/ci/java_cucumber_formatter'
require 'right_support/ci/java_spec_formatter'

# Don't auto-require the Rake task; it mixes the Rake DSL into everything!
# Must defer loading of the Rake task to the Rakefiles themselves.
#require 'right_support/ci/rake_task'
