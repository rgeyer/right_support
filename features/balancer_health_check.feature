Feature: request balancer health check
  In order to enhance system availability for customers
  RightSupport should track endpoint health when making load-balanced REST requests
  So apps do not become hung during network failures

Scenario: mixed servers (overloaded, blackholed) using health check
  Given 4 overloaded servers
  And 4 blackholed servers
  And HealthCheck balancing policy
  When a client makes a load-balanced request to '/' with timeout 1 and open_timeout 2
  Then the request should raise in less than 12 seconds

Scenario: mixed servers (well-behaved, blackholed) using health check
  Given 4 servers that respond with 200
  And 4 blackholed servers
  And HealthCheck balancing policy
  When a client makes a load-balanced request to '/' with timeout 1 and open_timeout 2
  Then the request should complete in less than 8 seconds

Scenario: mixed servers (overloaded, well-behaved, blackholed) using health check
  Given 1 overloaded server
  And 1 server that responds with 200
  And 1 blackholed server
  And HealthCheck balancing policy
  When a client makes a load-balanced request to '/' with timeout 1 and open_timeout 2
  Then the request should complete in less than 3 seconds

Scenario: mixed servers (condition commented by Tony https://rightscale.acunote.com/projects/2091/tasks/23987#comments) using health check
  Given 3 overloaded servers
  And 1 server that responds with 200
  And HealthCheck balancing policy
  When a client makes a load-balanced request to '/' with timeout 1 and open_timeout 2
  Then the request should complete in less than 3 seconds
