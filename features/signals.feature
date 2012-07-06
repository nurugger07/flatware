Feature: Signals

  Scenario: CTRL-C
    Given the following scenario:
    """
    Scenario: I iz very tired!
      Given sleep 10
    """
    When I start flatware
    But I hit CTRL-C before it is done
    Then I am back at the prompt
    And I see a summary of unfinished work
