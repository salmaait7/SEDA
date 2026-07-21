require "csv"
require "fileutils"

module Seda
  class MonteCarloActivityAnalyzer
    Result = Struct.new(
      :signal,
      :cycle,
      :reference_count,
      :changed_runs,
      :total_runs,
      :change_frequency,
      :mean_delta,
      :min_delta,
      :max_delta,
      keyword_init: true
    )

    def initialize(
      reference_file:,
      variation_files:,
      step_time: 20.0,
      input_signals: nil
    )
      @reference_file = reference_file
      @variation_files = variation_files
      @step_time = step_time.to_f
      @input_signals = input_signals
    end

    def run
      validate_files!

      reference_activity = activity_by_signal_and_cycle(@reference_file)

      variation_activities = @variation_files.map do |file|
        activity_by_signal_and_cycle(file)
      end

      aggregate(reference_activity, variation_activities)
    end

    def export(results, output_file)
      FileUtils.mkdir_p(File.dirname(output_file))

      CSV.open(output_file, "w") do |csv|
        csv << [
          "signal",
          "cycle",
          "reference_count",
          "changed_runs",
          "total_runs",
          "change_frequency",
          "mean_delta",
          "min_delta",
          "max_delta"
        ]

        results.each do |result|
          csv << [
            result.signal,
            result.cycle,
            result.reference_count,
            result.changed_runs,
            result.total_runs,
            result.change_frequency,
            result.mean_delta,
            result.min_delta,
            result.max_delta
          ]
        end
      end
    end

    def print_summary(results, minimum_frequency: 0.0)
      selected = results.select do |result|
        result.change_frequency >= minimum_frequency
      end

      selected.sort_by do |result|
        [
          -result.change_frequency,
          result.signal,
          result.cycle
        ]
      end.each do |result|
        puts(
          "#{result.signal}, cycle #{result.cycle}: " \
          "Nref=#{result.reference_count}, " \
          "changed=#{result.changed_runs}/#{result.total_runs}, " \
          "frequency=#{format('%.2f', result.change_frequency * 100)}%, " \
          "mean_delta=#{format('%+.2f', result.mean_delta)}, " \
          "range=[#{result.min_delta}, #{result.max_delta}]"
        )
      end
    end

    private

    def validate_files!
      all_files = [@reference_file] + @variation_files

      missing_files = all_files.reject { |file| File.file?(file) }

      return if missing_files.empty?

      raise ArgumentError,
            "Fichiers introuvables:\n#{missing_files.join("\n")}"
    end

    def activity_by_signal_and_cycle(file)
      rows = CSV.read(file, headers: true)

      raise ArgumentError, "Le fichier #{file} est vide" if rows.empty?

      time_column = rows.headers.first

      signals = rows.headers[1..].map(&:strip)

      input_signals =
        if @input_signals
          @input_signals
        else
          detect_input_signals(signals)
        end

      observed_signals = signals - input_signals

      activity = Hash.new do |signal_hash, signal|
        signal_hash[signal] = Hash.new(0)
      end

      previous_values = {}

      rows.each_with_index do |row, row_index|
        time = parse_time(row[time_column])
        cycle = (time / @step_time).floor

        observed_signals.each do |signal|
          current_value = normalize_value(row[signal])

          next if current_value.nil?

          if row_index.positive? &&
             previous_values.key?(signal) &&
             previous_values[signal] != current_value

            activity[signal][cycle] += 1
          end

          previous_values[signal] = current_value
        end
      end

      activity
    end

    def aggregate(reference_activity, variation_activities)
      total_runs = variation_activities.length

      raise ArgumentError, "Aucun tirage fourni" if total_runs.zero?

      keys = all_signal_cycle_keys(
        reference_activity,
        variation_activities
      )

      keys.map do |signal, cycle|
        reference_count =
          reference_activity.dig(signal, cycle) || 0

        deltas = variation_activities.map do |activity|
          variation_count = activity.dig(signal, cycle) || 0
          variation_count - reference_count
        end

        changed_deltas = deltas.reject(&:zero?)

        Result.new(
          signal: signal,
          cycle: cycle,
          reference_count: reference_count,
          changed_runs: changed_deltas.length,
          total_runs: total_runs,
          change_frequency: changed_deltas.length.to_f / total_runs,
          mean_delta: mean(deltas),
          min_delta: deltas.min,
          max_delta: deltas.max
        )
      end
    end

    def all_signal_cycle_keys(reference_activity, variation_activities)
      keys = []

      ([reference_activity] + variation_activities).each do |activity|
        activity.each do |signal, cycles|
          cycles.each_key do |cycle|
            keys << [signal, cycle]
          end
        end
      end

      keys.uniq
    end

    def detect_input_signals(signals)
      signals.select do |signal|
        signal.match?(/\A(?:x|in|input|N)\d+\z/i)
      end
    end

    def parse_time(value)
      value.to_s
           .strip
           .sub(/\s*(fs|ps|ns|us|ms|s)\z/i, "")
           .to_f
    end

    def normalize_value(value)
      normalized = value.to_s.strip

      return nil if normalized.empty?
      return normalized if %w[0 1 U X Z W L H -].include?(normalized)

      normalized
    end

    def mean(values)
      return 0.0 if values.empty?

      values.sum.to_f / values.length
    end
  end
end