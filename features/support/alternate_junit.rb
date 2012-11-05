require 'cucumber/formatter/junit'

class AlternateJunit < Cucumber::Formatter::Junit
  def feature_name(keyword, name)
    super
    # We are disguising our feature name as a Java package; make sure it's valid according
    # to Java syntax rules, to prevent any parsing issues in the tools that parse these
    # JUnit XML test results.
    @feature_name.gsub!(/[^A-Za-z0-9_]+/, '_')
    # Prefix feature name with a "Cucumber" pseudo-package for grouping purposes.
    @feature_name = "cucumber.#{@feature_name}"
  end
end
