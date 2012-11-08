Feature: continuous integration disabled
  In order to let minimize runtime dependencies
  RightSupport's Rake CI harness should gracefully handle missing gems
  So it runs predictably and reliably in production

  Background:
    Given a Ruby application
    And a Gemfile
    And a gem dependency on 'rake ~> 0.9'

  Scenario: all gems unavailable
    Given the Rakefile contains a RightSupport::CI::RakeTask
    When I install the bundle
    And I rake '-T'
    Then the output should not contain 'ci:cucumber'
    And the output should not contain 'ci:spec'

  Scenario: conditional availability of ci:cucumber
    Given a gem dependency on 'rspec ~> 1.0'
    And a gem dependency on 'builder ~> 3.0'
    And the Rakefile contains a RightSupport::CI::RakeTask
    When I install the bundle
    And I rake '-T'
    Then the output should contain 'ci:spec'
    And the output should not contain 'ci:cucumber'

  Scenario: conditional availability of ci:rspec
    Given a gem dependency on 'cucumber ~> 1.0'
    And the Rakefile contains a RightSupport::CI::RakeTask
    When I install the bundle
    And I rake '-T'
    Then the output should contain 'ci:cucumber'
    And the output should not contain 'ci:spec'

  Scenario: list Rake tasks
    Given a gem dependency on 'rspec ~> 2.0'
    And a gem dependency on 'cucumber ~> 1.0'
    And the Rakefile contains a RightSupport::CI::RakeTask
    When I install the bundle
    And I rake '-T'
    And the output should contain 'ci:cucumber'
    And the output should contain 'ci:spec'

  Scenario: override namespace
    Given a gem dependency on 'rspec ~> 2.0'
    And a gem dependency on 'cucumber ~> 1.0'
    And the Rakefile contains a RightSupport::CI::RakeTask with parameter ':funkalicious'
    When I install the bundle
    And I rake '-T'
    Then the output should contain 'funkalicious:cucumber'
    Then the output should contain 'funkalicious:spec'
