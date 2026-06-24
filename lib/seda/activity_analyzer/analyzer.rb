module Seda
  class ActivityAnalyzer
    def self.analyze_file(file, input_signals: nil)
      signals = read_signals(file)
      input_signals ||= signals.select { |s| s.match?(/^x\d+$/) }

      analyzer = new(file, signals, input_signals)
      analyzer.run
    end

    def self.read_signals(file)
      header = File.readlines(file).first
      header.split(",")[1..].map(&:strip) # remove time
    end

    def self.compare(results, case_a, case_b)
      counts_a = results[case_a][:counts]
      counts_b = results[case_b][:counts]

      signals = (counts_a.keys + counts_b.keys).uniq

      total_a = signals.sum { |sig| counts_a[sig] || 0 } # nb total des transitions pour le cas
      total_b = signals.sum { |sig| counts_b[sig] || 0 }

      puts
      puts "Comparison: #{case_a} vs #{case_b}"
      puts "total #{case_a}: #{total_a}"
      puts "total #{case_b}: #{total_b}"
      puts "delta: #{total_b - total_a}"

      signals.each do |sig|
        a = counts_a[sig] || 0
        b = counts_b[sig] || 0
        delta = b - a

        next if delta == 0

        puts "#{sig.ljust(10)} : #{a} -> #{b}"
      end
    end

    def self.compare_transition_times(results, case_a, case_b, signal)
      transitions_a = results[case_a][:transitions][signal] 
      transitions_b = results[case_b][:transitions][signal]
      puts
      puts "Transition times comparison for #{signal}"
      puts "#{case_a}:"
      print_transition_list(transitions_a)

      puts "#{case_b}:"
      print_transition_list(transitions_b)
    end

    def self.print_transition_list(transitions)
      if transitions.empty?
        puts "  no transition"
        return
      end

      transitions.each do |transition|
        puts "  t=#{transition[:time]} : #{transition[:from]} -> #{transition[:to]}"
      end
    end

    def initialize(file, signals, input_signals)
      @file = file
      @signals = signals
      @input_signals = input_signals
    end

    def run
      rows = read_file
      transitions = count_transitions(rows)
      counts = transition_counts(transitions)
      # observed_counts = exclude_inputs(counts)

      print_results(counts)

      {
        rows: rows,
        transitions: transitions,
        counts: counts
      }
    end

    def read_file
      rows = []

      File.readlines(@file).each_with_index do |line, index|
        line = line.strip
        next if line.empty?
        next if index == 0 && line.start_with?("time,")

        parts = line.split(",").map(&:strip)

        time = parts[0]
        values = parts[1..].map { |v| v.gsub("'", "") }


        row = { time: time, values: {} }

        @signals.each_with_index do |sig, i|
          row[:values][sig] = values[i]
        end

        rows << row
      end

      rows
    end

    def count_transitions(rows)
      transitions = Hash.new { |hash, key| hash[key] = [] }
      previous = {}

      rows.each do |row|
        @signals.each do |sig|
          value = row[:values][sig]

          next if value == "U"

          if previous[sig].nil?
            previous[sig] = value
            next
          end

          next if value == previous[sig]

          transitions[sig] << {
            time: row[:time],
            from: previous[sig],
            to: value
          }

          previous[sig] = value
        end
      end

      @signals.each { |sig| transitions[sig] ||= [] }

      transitions
    end

    def transition_counts(transitions)
      counts = {}
      observed_signals = @signals - @input_signals

      observed_signals.each do |sig|
        counts[sig] = transitions[sig].size
      end

      counts
    end


    def print_results(counts)
      puts
      puts "[1] Transitions per signal"
      @signals.each do |sig|
        puts "#{sig.ljust(10)} : #{counts[sig]}"
      end

      values = counts.values

      puts
      puts "[2] Netlist statistics"
      puts "min     : #{values.min || 0}"
      puts "max     : #{values.max || 0}"
      puts "average : #{format('%.3f', mean(values))}"
      puts "stddev  : #{format('%.3f', stddev(values))}"
      puts "total   : #{values.sum}"
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