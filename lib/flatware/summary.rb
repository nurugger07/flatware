require 'cucumber/formatter/console'
module Flatware
  class Summary
    include ::Cucumber::Formatter::Console
    attr_reader :io, :steps

    def initialize(steps, io=StringIO.new)
      @io = io
      @steps = steps
    end

    def scenarios
      @scenarios ||= scenario_steps.group_by(&:scenario_id).map do |scenario, steps|
        ScenarioResult.new(scenario, steps)
      end
    end

    def summarize
      2.times { io.puts }
      print_steps :failed
      print_counts 'scenario', scenarios
      print_counts 'step', steps
    end

    private

    def scenario_steps
      steps.select &:scenario_id
    end

    def print_steps(status)
      print_elements steps.select(&with_status(status)), status, 'steps'
    end

    def print_counts(label, collection)
      io.puts pluralize(label, collection.size) + count_summary(collection)
    end

    def pluralize(word, number)
      "#{number} #{number == 1 ? word : word + 's'}"
    end

    def with_status(status)
      proc {|r| r.status == status}
    end

    def count_summary(results)
      return "" unless results.any?
      status_counts = Cucumber::STATUSES.map do |status|
        count = results.select(&with_status(status)).size
        format_string "#{count} #{status}", status if count > 0
      end.compact.join ", "

      " (#{status_counts})"
    end

    def count(status)
      completed_scenarios.select {|scenario| scenario.status == status}.count
    end
  end
end
