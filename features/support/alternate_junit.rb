require 'cucumber/formatter/junit'

class AlternateJunit < Cucumber::Formatter::Junit
  def feature_name(keyword, name)
    super
    @feature_name = "cucumber.#{@feature_name}"
  end
end
