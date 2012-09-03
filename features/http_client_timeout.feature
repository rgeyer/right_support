Feature: HTTP client request timeout
  In order to enhance system availability for customers
  RightSupport should provide robust REST query interfaces 
  So apps do not become hung during network failures

  Scenario: well-behaved server
    Given a server that responds with 200
    When a client makes a request to '/' with timeout 1 and open_timeout 2
    Then the request should complete in less than 3 seconds

  Scenario: overloaded server
    Given an overloaded server
    When a client makes a request to '/' with timeout 1 and open_timeout 2
    Then the request should raise in less than 3 seconds

  Scenario: blackholed servers
    Given a blackholed server
    When a client makes a load-balanced request to '/' with timeout 1 and open_timeout 2
    Then the request should raise in less than 3 seconds
