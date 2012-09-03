Feature: request balancer error handling
  In order to enhance app availability and development velocity
  RequestBalancer should consider certain errors as fatal by default
  So careless developers do not cause unexpected behavior when failures occur

  Scenario: well-behaved servers
    Given 5 servers that respond with 200
    When a client makes a load-balanced request to '/'
    Then the request should complete
    And the request should be attempted once

  Scenario: resource not found
    Given 4 servers that respond with 404
    When a client makes a load-balanced request to '/'
    Then the request should raise ResourceNotFound
    And the request should be attempted once

  Scenario: client-side error
    Given a server that responds with 200
    When a client makes a buggy load-balanced request to '/'
    Then the request should raise ArgumentError
    And the request should be attempted once

  Scenario: socket open timeout
    Given 2 blackholed servers
    When a client makes a load-balanced request to '/'
    Then the request should be attempted 2 times
    And the request should raise NoResult

  Scenario: HTTP request timeout
    Given 2 overloaded servers
    When a client makes a load-balanced request to '/'
    Then the request should be attempted 2 times
    And the request should raise NoResult
