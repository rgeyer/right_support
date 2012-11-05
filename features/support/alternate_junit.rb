require 'cucumber/formatter/junit'

class AlternateJunit < Cucumber::Formatter::Junit
  private

  def build_testcase(duration, status, exception = nil, suffix = "")
    @time += duration
    # Use "cucumber" as a pseudo-package, and the feature name as a pseudo-class
    classname = "cucumber.#{@feature_name}"
    name = "#{@scenario}#{suffix}"
    pending = [:pending, :undefined].include?(status)
    passed = (status == :passed || (pending && !@options[:strict]))

    @builder.testcase(:classname => classname, :name => name, :time => "%.6f" % duration) do
      unless passed
        @builder.failure(:message => "#{status.to_s} #{name}", :type => status.to_s) do
          @builder.cdata! @output
          @builder.cdata!(format_exception(exception)) if exception
        end
        @failures += 1
      end
      if passed and (status == :skipped || pending)
        @builder.skipped
        @skipped += 1
      end
    end
    @tests += 1
  end
end
