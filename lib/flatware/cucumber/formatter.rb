require 'cucumber/formatter/console'
module Flatware
  module Cucumber

    FORMATS = {
      :passed    => '.',
      :failed    => 'F',
      :undefined => 'U',
      :pending   => 'P',
      :skipped   => '-'
    }

    STATUSES = FORMATS.keys

    class Formatter
      def initialize(step_mother, *)
        @step_mother = step_mother
      end

      def scenario_name(keyword, name, file_colon_line, source_indent)
        @current_scenario = file_colon_line
      end

      def after_step_result(keyword, step_match, multiline_arg, status, exception, source_indent, background)
        Sink.push StepResult.new status, exception, @current_scenario
      end

      def before_outline_table(outline_table)
        @outline_table = outline_table
      end

      def after_outline_table(outline_table)
        @outline_table = nil
      end

      def before_table_row(table_row)
        if example_row? table_row
          @step_counts = STATUSES.inject({}) do |counts, status|
            counts.merge status => step_mother.steps(status).size
          end
        end
      end

      def after_table_row(table_row)
        if example_row? table_row
          # this will determine if the outline row was a failure.
          Sink.push ExampleRowResult.new table_row
          # the cucumber progress formatter doesn't use this: it's oblivious.
          # it provides no feedback until the summary is printed, which is not
          # congruous with our design goal of always reporting status as soon
          # as it is known.
          #
          # POLYMORPHIC INTERFACE FOR RESULT MESSAGES
          #
          class Result
            # a string to print as a progress message. will be blank for
            # example row results.
            def progress
            end

            # an array of steps. empty for example cells. one for regular
            # steps. many for example row results.
            # these can be summed by the summary code.
            def steps
              []
            end
          end

        end
      end

      def table_cell_value(_, status)
        # Sink.push ExampleCellResult.new status if example_cell? status
      end

      private

      attr_reader :step_mother

      def example_row?(table_row)
        outline_table? and not table_header_row? table_row
      end

      def example_cell?(status)
        outline_table? and not table_header_cell? status
      end

      def table_header_cell?(status)
        status == :skipped_param
      end

      def outline_table?
        !!@outline_table
      end

      def table_header_row?(table_row)
        table_row.failed?
      rescue ::Cucumber::Ast::OutlineTable::ExampleRow::InvalidForHeaderRowError
        true
      else
        false
      end
    end

    class ScenarioResult
      attr_reader :id, :steps

      def initialize(id, steps=[])
        @id = id
        @steps = steps
      end

      def passed?
        steps.all? &:passed?
      end

      def failed?
        steps.any? &:failed?
      end

      def status
        failed? ? :failed : :passed
      end
    end

    class Summary
      include ::Cucumber::Formatter::Console
      attr_reader :io, :steps

      def initialize(steps, io=StringIO.new)
        @io = io
        @steps = steps
      end

      def scenarios
        @scenarios ||= steps.group_by(&:scenario_id).map do |scenario, steps|
          ScenarioResult.new(scenario, steps)
        end
      end

      def summarize
        2.times { io.puts }
        print_steps :failed
        print_scenario_counts
        print_step_counts
      end

      private

      def print_steps(status)
        print_elements steps.select(&with_status(status)), status, 'steps'
      end

      def print_scenario_counts
        io.puts "#{pluralize 'scenario', scenarios.size} (#{count_summary scenarios})"
      end

      def print_step_counts
        io.puts "#{pluralize 'step', steps.size} (#{count_summary steps})"
      end

      def pluralize(word, number)
        "#{number} #{number == 1 ? word : word + 's'}"
      end

      def with_status(status)
        proc {|r| r.status == status}
      end

      def count_summary(results)
        STATUSES.map do |status|
          count = results.select(&with_status(status)).size
          format_string "#{count} #{status}", status if count > 0
        end.compact.join ", "
      end

      def count(status)
        completed_scenarios.select {|scenario| scenario.status == status}.count
      end
    end

    class StepResult
      include ::Cucumber::Formatter::Console
      attr_reader :status, :exception, :scenario_id

      def initialize(status, exception, scenario_id=nil)
        @status, @exception, @scenario_id = status, serialized(exception), scenario_id
      end

      def passed?
        status == :passed
      end

      def failed?
        status == :failed
      end

      def progress
        format_string FORMATS[status], status
      end

      private
      def serialized(e)
        SerializedException.new(e.class, e.message, e.backtrace) if e
      end
    end

    class SerializedException
      attr_reader :class, :message, :backtrace
      def initialize(klass, message, backtrace)
        @class, @message, @backtrace = serialized(klass), message, backtrace
      end

      private
      def serialized(klass)
        SerializedClass.new(klass.to_s)
      end
    end

    class SerializedClass
      attr_reader :name
      alias to_s name
      def initialize(name); @name = name end
    end
  end
end
