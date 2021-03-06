Feature: continuous integration of RSpec 2.x specs
  In order to facilitate TDD and enhance code quality
  RightSupport should provide a Rake CI harness with JUnit XML output
  So any Ruby project can have a beautiful, info-rich Jenkins project

  Background:
    Given a Ruby application
    And a Gemfile
    And a gem dependency on 'rake ~> 0.9'
    And a gem dependency on 'rspec ~> 2.0'
    And a gem dependency on 'builder ~> 3.0'
    And the Rakefile contains a RightSupport::CI::RakeTask

  Scenario: passing examples
    And a trivial RSpec spec
    When I install the bundle
    And I rake 'ci:spec'
    Then the command should succeed
    And the file 'measurement/rspec/rspec.xml' should mention 2 passing test cases
    And the file 'measurement/rspec/rspec.xml' should mention 0 failing test cases

  Scenario: failing examples
    And a trivial failing RSpec spec
    When I install the bundle
    And I rake 'ci:spec'
    Then the command should fail
    And the file 'measurement/rspec/rspec.xml' should mention 2 passing test cases
    And the file 'measurement/rspec/rspec.xml' should mention 1 failing test case
