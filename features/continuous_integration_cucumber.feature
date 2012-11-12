Feature: continuous integration of Cucumber features
  In order to facilitate TDD and enhance code quality
  RightSupport should provide CI tasks with Cucumber with JUnit XML output
  So any Ruby project can have a beautiful, info-rich Jenkins project

  Background:
    Given a Ruby application
    And a Gemfile
    And a gem dependency on 'rake ~> 0.9'
    And a gem dependency on 'builder ~> 3.0'

  Scenario: run Cucumber features
    Given a gem dependency on 'cucumber ~> 1.0'
    And the Rakefile contains a RightSupport::CI::RakeTask
    And a trivial Cucumber feature
    When I install the bundle
    And I rake 'ci:cucumber'
    Then the output should contain '** Execute ci:cucumber'
    And the directory 'measurement/cucumber' should contain files
