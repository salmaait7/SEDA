module Seda
  class ActivityAnalyzer
    def initialize(file:, signals:, input_signals:)
      @file = file
      @signals = signals
      @input_signals = input_signals
    end

    def run
      rows = read_activity_file
      transitions = compute_transitions(rows)
      counts = transition_counts(transitions)
      observed_counts = counts_for_observed_signals(counts)

   
      puts "activity analysis"
      puts "=================="

      print_transition_counts(counts)
      print_node_statistics(observed_counts)
      print_netlist_statistics(observed_counts)

      {
        rows: rows,
        transitions: transitions,
        counts: counts,
        observed_counts: observed_counts
      }
    end
    #read the file and transform it to a a Ruby data structure (array of hashes)
    def read_activity_file
      rows = []

      File.readlines(@file).each do |line|
        line = line.strip
        next if line.empty?

        parts = line.split(",").map(&:strip)

        time_part = parts[0].split.first
        values_part = parts[1..].map { |v| v.strip.gsub("'", "") }

        row = {
          time: time_part,
          values: {}
        }

        @signals.each_with_index do |sig, i|
          row[:values][sig] = values_part[i]
        end

        rows << row
      end

      rows
    end

    def compute_transitions(rows)
      transitions = Hash.new { |h, k| h[k] = [] }
      previous = {}

      @signals.each do |sig|
        previous[sig] = nil
      end

      rows.each do |row|
        time = row[:time]

        @signals.each do |sig|
          value = row[:values][sig]

          next if value == "U"

          if previous[sig].nil? #first time we see this signal, just record the value
            previous[sig] = value
            next
          end

          if value != previous[sig]
            transitions[sig] << {
              time: time,
              from: previous[sig],
              to: value
            }

            previous[sig] = value
          end
        end
      end

      transitions
    end

    def transition_counts(transitions)
      counts = {}

      @signals.each do |sig|
        counts[sig] = transitions[sig].size
      end

      counts
    end


    def counts_for_observed_signals(counts)
      (@signals - @input_signals).map { |sig| counts[sig] }
    end

    def print_transition_counts(counts)
      puts
      puts "[1] Number of transitions per signal"

      @signals.each do |sig|
        puts "#{sig.ljust(10)} : #{counts[sig]}"
      end
    end

    def print_node_statistics(counts)
      puts
      puts "[2] Statistics over nodes"

      min = counts.min
      max = counts.max
      avg = mean(counts)
      std = stddev(counts)

      puts "min     : #{min}"
      puts "max     : #{max}"
      puts "average : #{format('%.3f', avg)}"
      puts "stddev  : #{format('%.3f', std)}"
    end

    def print_netlist_statistics(counts)
      puts
      puts "[3] Netlist level statistics"

      total = counts.sum

      puts "total transitions on observed netlist : #{total}"
    end

    def mean(values)
      return 0.0 if values.empty?

      values.sum.to_f / values.size
    end

    def stddev(values)
      return 0.0 if values.empty?

      avg = mean(values)
      variance = values.map { |v| (v - avg) ** 2 }.sum / values.size
      Math.sqrt(variance)
    end
  end
end