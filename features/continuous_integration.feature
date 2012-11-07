Feature: continuous integration reports
  In order to facilitate TDD and enhance code quality
  RightSupport should provide a Rake CI harness with JUnit XML output
  So any Ruby project can have a beautiful, info-rich Jenkins project

  Background:
    Given a Ruby application
    And a Gemfile
    And the Rakefile contains a RightSupport::CI::RakeTask

  Scenario: list Rake tasks
    Given a gem dependency on 'rspec ~> 2.0'
    And a gem dependency on 'cucumber ~> 1.0'
    When I install the bundle
    And I rake '-T'
    Then the output should contain 'ci:spec'
    And the output should contain 'ci:cucumber'

  Scenario: run RSpec 1.x examples
    Given a gem dependency on 'rspec ~> 1.0'
    And a trivial RSpec spec
    When I install the bundle
    And I rake 'ci:spec'
    Then the output should contain '** Execute ci:spec'
    And the directory 'measurement/rspec' should contain files

  Scenario: run RSpec 2.x examples
    Given a gem dependency on 'rspec ~> 2.0'
    And a trivial RSpec spec
    When I install the bundle
    And I rake 'ci:spec'
    Then the output should contain '** Execute ci:spec'
    And the directory 'measurement/rspec' should contain files

  Scenario: run Cucumber features
    Given a gem dependency on 'cucumber ~> 1.0'
    And a trivial Cucumber feature
    When I install the bundle
    And I rake 'ci:cucumber'
    Then the output should contain '** Execute ci:cucumber'
    And the directory 'measurement/cucumber' should contain files
