Feature: continuous integration
  In order to facilitate TDD and enhance code quality
  RightSupport should provide a Rake CI harness with JUnit XML output
  So any Ruby project can have a beautiful, info-rich Jenkins project

  Background:
    Given a Ruby application
    And a Gemfile
    And a gem dependency on 'rake ~> 0.9'
    Given a gem dependency on 'rspec ~> 2.0'
    And a gem dependency on 'builder ~> 3.0'

  Scenario: run RSpec 2.x examples
    And the Rakefile contains a RightSupport::CI::RakeTask
    And a trivial RSpec spec
    When I install the bundle
    And I rake 'ci:spec'
    Then the output should contain '** Execute ci:spec'
    And the directory 'measurement/rspec' should contain files
