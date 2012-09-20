Feature: JSON serialization
  In order to facilitate Ruby apps' use of external JSON data stores
  RightSupport should cleanly serialize arbitrary Ruby objects to JSON without data loss or semantic ambiguity
  So app code can be idiomatic and focus on the business problem, not the encoding details

  Background:
    Given a serializer named 'RightSupport::Data::Serializer'
    And a stateful Ruby class named 'GotState'

  Scenario Outline: Ruby types with a native JSON representation
    When I serialize the Ruby value: <ruby>
    Then the serialized value should be: <json>
    And the serialized value should round-trip cleanly

  Examples:
    | ruby                                  | json                               |
    | true                                  | true                               |
    | false                                 | false                              |
    | nil                                   | null                               |
    | 0                                     | 0                                  |
    | 42                                    | 42                                 |
    | -32                                   | -32                                |
    | 3.1415926535                          | 3.1415926535                       |
    | "hello, world!"                       | "hello, world!"                    |
    | [0,true,nil,['a',false]]              | [0,true,null,["a",false]]          |
    | {"one"=>2}                            | {"one":2}                          |
    | {"hash"=>{"lucky"=>777,"seq"=>[2,3]}} | {"hash":{"lucky":777,"seq":[2,3]}} |

  Scenario: complex Ruby structures with a native JSON representation
    When I serialize a complex random data structure
    Then the serialized value should round-trip cleanly

  Scenario Outline: object-escaped Symbol
    When I serialize the Ruby value: <ruby>
    Then the serialized value should be: <json>
    And the serialized value should round-trip cleanly

  Examples:
    | ruby            | json            |
    | :my_symbol      | ":my_symbol"    |
    | :'weird symbol' | ":weird symbol" |

  Scenario Outline: object-escaped Time
    When I serialize the Ruby value: <ruby>
    Then the serialized value should be: <json>
    And the serialized value should round-trip cleanly

  Examples:
    | ruby                                          | json                                      |
    | Time.mktime(2009, 2, 13, 15, 31, 31, -8*3600) | "2009-02-13T23:31:30Z" |
    | Time.at(1234567890)                           | "2009-02-13T23:31:30Z" |
    | Time.at(1234567890).utc                       | "2009-02-13T23:31:30Z" |

  Scenario Outline: object-escaped String
    When I serialize the Ruby value: <ruby>
    Then the serialized value should be: <json>
    And the serialized value should round-trip cleanly

  Examples:
    | ruby            | json                                             |
    | ":not_a_symbol" | {"_ruby_class":"String","value":":not_a_symbol"} |

  Scenario Outline: Ruby Class and Module types

  Scenario Outline: Ruby Class and Module types
    When I serialize the Ruby value: <ruby>
    Then the serialized value should be a JSON object
    And the serialized value should round-trip cleanly

  Examples:
    | ruby                              |
    | String                            |
    | RightSupport::Ruby::EasySingleton |
    | RightSupport::Net::HTTPClient     |
    | Hash                              |
    | Kernel                            |

  Scenario Outline: arbitrary Ruby objects
    When I serialize the Ruby value: <ruby>
    Then the serialized value should be a JSON object
    And the serialized value should have a suitable _ruby_class

  Examples:
    | ruby                                   |
    | RightSupport::Crypto::SignedHash.new() |
    | GotState.new                           |

  Scenario: arbitrary Ruby object round-trip, happy path
    When I serialize the Ruby value: GotState.new
    Then the serialized value should round-trip cleanly

  Scenario: arbitrary Ruby object round-trip, sad path
    When I serialize the Ruby value: GotState.new
    And an eldritch force deletes a key from the serialized value
    And the serialized value should fail to round-trip
