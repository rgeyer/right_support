Feature: continuous integration of RSpec 1.x specs
  In order to facilitate TDD and enhance code quality
  RightSupport should provide a Rake CI harness with JUnit XML output
  So any Ruby project can have a beautiful, info-rich Jenkins project

  Background:
    Given a Ruby application
    And a Gemfile
    And a gem dependency on 'rake ~> 0.9'
    And a gem dependency on 'rspec ~> 1.0'
    And a gem dependency on 'builder ~> 3.0'
    And the Rakefile contains a RightSupport::CI::RakeTask

  Scenario: passing RSpec 1.x examples
    Given a trivial RSpec spec
    When I install the bundle
    And I rake 'ci:spec'
    Then the command should succeed
    And the output should contain '** Execute ci:spec'
    And the directory 'measurement/rspec' should contain files

  Scenario: failing RSpec 1.x examples
    Given a trivial failing RSpec spec
    When I install the bundle
    And I rake 'ci:spec'
    Then the command should fail
    And the output should contain '** Execute ci:spec'
    And the directory 'measurement/rspec' should contain files
