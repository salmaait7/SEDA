module Seda
  class ActivityAnalyzer
    def self.analyze_file(file, input_signals: nil, step_time: 20.0, nb_cycles: nil, signals_to_analyze: nil)
      signals = read_signals(file)
      input_signals ||= signals.select { |s| s.match?(/^x\d+$/) }
      signals_to_analyze ||= signals

      analyzer = new(file, signals, input_signals, step_time, nb_cycles, signals_to_analyze)
      analyzer.run
    end

    def self.read_signals(file)
      header = File.readlines(file).first
      header.split(",")[1..-1].map(&:strip) # remove time
    end

    

    def self.compare(results, case_a, case_b)
      stats_a = results[case_a][:stats]
      stats_b = results[case_b][:stats]

      signals = stats_a.keys & stats_b.keys

      total_a = signals.sum { |sig| stats_a[sig][:total] }
      total_b = signals.sum { |sig| stats_b[sig][:total] }

      puts
      puts "Comparison: #{case_a} vs #{case_b}"
      puts "total #{case_a}: #{total_a}"
      puts "total #{case_b}: #{total_b}"
      puts "delta: #{total_b - total_a}"

      puts
      puts "[2.1] Activity statistics differences"

      signals.each do |sig|
        a = stats_a[sig]
        b = stats_b[sig]

        delta_total = b[:total] - a[:total]
        delta_avg   = b[:average_per_cycle] - a[:average_per_cycle]
        delta_std   = b[:stddev_per_cycle] - a[:stddev_per_cycle]

        next if delta_total == 0 &&
                delta_avg.abs == 0 &&
                delta_std.abs == 0 &&
                a[:min_per_cycle] == b[:min_per_cycle] &&
                a[:max_per_cycle] == b[:max_per_cycle]

        puts
        puts sig
        puts "  total     : #{a[:total]} -> #{b[:total]}  delta=#{delta_total}"
        puts "  avg/cycle : #{format('%.3f', a[:average_per_cycle])} -> #{format('%.3f', b[:average_per_cycle])}  delta=#{format('%.3f', delta_avg)}"
        puts "  stddev    : #{format('%.3f', a[:stddev_per_cycle])} -> #{format('%.3f', b[:stddev_per_cycle])}  delta=#{format('%.3f', delta_std)}"
        puts "  min       : #{a[:min_per_cycle]} -> #{b[:min_per_cycle]}"
        puts "  max       : #{a[:max_per_cycle]} -> #{b[:max_per_cycle]}"
      end

      # puts
      # puts "[2.2] Delayed first transition times differences"

      # first_transitions_a = results[case_a][:first_transitions]
      # first_transitions_b = results[case_b][:first_transitions]

      # if first_transitions_a.nil? && first_transitions_b.nil?
      #   puts "No first transition data available for either case."
      # return
      # end

      # found_difference = false
      # signals.each do |sig|
      #   first_a = first_transitions_a[sig]
      #   first_b = first_transitions_b[sig]

      #   next if first_a.nil? && first_b.nil?

      #   cycles = (first_a.keys + first_b.keys).uniq.sort
      #   cycles.each do |cycle|
      #     time_a = first_a[cycle]
      #     time_b = first_b[cycle]

      #     next if time_a.nil? && time_b.nil?

      #     if time_a != time_b
      #       found_difference = true
      #       puts
      #       puts "#{sig} - cycle #{cycle}:"
      #       puts "  #{case_a}: #{time_a.nil? ? 'no transition' : format('%.3f', time_a)} ns"
      #       puts "  #{case_b}: #{time_b.nil? ? 'no transition' : format('%.3f', time_b)} ns"
      #     end
      #   end
      # end
    end
        
    


    def self.compare_cycle_activity(results, case_a, case_b, signal)
      activity_a = results[case_a][:cycle_activity][signal] || {}
      activity_b = results[case_b][:cycle_activity][signal] || {}

      cycles = (activity_a.keys + activity_b.keys).uniq.sort

      puts
      puts "Cycle activity comparison for #{signal}"
      puts "#{case_a} vs #{case_b}"

      cycles.each do |cycle|
        a = activity_a[cycle] || 0
        b = activity_b[cycle] || 0
        delta = b - a

        next if delta == 0

        puts "  cycle #{cycle}: #{a} -> #{b}  delta=#{delta}"
      end
    end

    # def self.compare_transition_times(results, case_a, case_b, signal)
    #   transitions_a = results[case_a][:transitions][signal] || []
    #   transitions_b = results[case_b][:transitions][signal] || []

    #   puts
    #   puts "Transition times comparison for #{signal}"

    #   puts "#{case_a}:"
    #   print_transition_list(transitions_a)

    #   puts "#{case_b}:"
    #   print_transition_list(transitions_b)
    # end

    # def self.print_transition_list(transitions)
    #   if transitions.empty?
    #     puts "  no transition"
    #     return
    #   end

    #   transitions.each do |transition|
    #     puts "  t=#{format('%.3f', transition[:time])} ns : #{transition[:from]} -> #{transition[:to]}  cycle=#{transition[:cycle]}"
    #   end
    # end

    def initialize(file, signals, input_signals, step_time, nb_cycles, signals_to_analyze)
      @file = file
      @signals = signals
      @input_signals = input_signals
      @observed_signals = signals - input_signals
      @step_time = step_time.to_f
      @nb_cycles = nb_cycles
      @signals_to_analyze = signals_to_analyze  

    end

    def run
      rows = read_file

      transitions = count_transitions(rows)

      counts = transition_counts(transitions)

      cycle_activity = activity_by_cycle(transitions, rows)

      first_transitions = first_transitions_by_cycle(transitions, rows)

      stats = activity_stats_by_node(cycle_activity)

      print_results(cycle_activity, stats)

      {
        rows: rows,
        transitions: transitions,
        counts: counts,
        cycle_activity: cycle_activity,
        first_transitions: first_transitions,
        stats: stats
      }
    end

    def read_file
      rows = []

      File.readlines(@file).each_with_index do |line, index|
        line = line.strip
        next if line.empty?
        next if index == 0 && line.start_with?("time,")

        parts = line.split(",").map(&:strip)

        time = parse_time(parts[0])
        values = parts[1..-1].map { |v| clean_value(v) }

        row = {
          time: time,
          values: {}
        }

        @signals.each_with_index do |sig, i|
          row[:values][sig] = values[i]
        end

        rows << row
      end

      rows
    end

    def parse_time(value)
      value.to_s.gsub("ns", "").strip.to_f
    end

    def clean_value(value)
      value.to_s.strip.gsub("'", "")
    end

    def valid_logic_value?(value)
      value == "0" || value == "1"
    end

    def count_transitions(rows)
      transitions = Hash.new { |hash, key| hash[key] = [] }
      previous = {}

      rows.each do |row|
        current_cycle = cycle_id(row[:time])

        @signals.each do |sig|
          value = row[:values][sig]

          next unless valid_logic_value?(value)

          if previous[sig].nil?
            previous[sig] = value
            next
          end

          next if value == previous[sig]

          transitions[sig] << {
            time: row[:time],
            from: previous[sig],
            to: value,
            cycle: current_cycle
          }

          previous[sig] = value
        end
      end

      @signals.each { |sig| transitions[sig] ||= [] }

      transitions
    end

    def transition_counts(transitions)
      counts = {}

      analyzed_signals.each do |sig|
        counts[sig] = transitions[sig].size
      end

      counts
    end

    def activity_by_cycle(transitions, rows)
      activity = {}
      cycles = cycle_ids(rows)

      analyzed_signals.each do |sig|
        activity[sig] = {}

        cycles.each do |cycle|
          activity[sig][cycle] = 0
        end

        transitions[sig].each do |transition|
          cycle = transition[:cycle]

          next unless activity[sig].key?(cycle)

          activity[sig][cycle] += 1
        end
      end

      activity
    end

    def activity_stats_by_node(cycle_activity)
      stats = {}

      cycle_activity.each do |sig, cycles|
        values = cycles.values

        stats[sig] = {
          total: values.sum,
          average_per_cycle: mean(values),
          stddev_per_cycle: stddev(values),
          min_per_cycle: values.min || 0,
          max_per_cycle: values.max || 0
        }
      end
      
      stats
    end

    def first_transitions_by_cycle(transitions, rows)
      first_transitions = {}
      cycles = cycle_ids(rows)
  
      analyzed_signals.each do |sig|
        first_transitions[sig] = {}
        cycles.each do |cycle|
          first_transitions[sig][cycle] = nil
        end

        transitions[sig].each do |transition|
          cycle = transition[:cycle]
          next unless first_transitions[sig].key?(cycle)
          cycle_start_time = cycle * @step_time
          relative_time = transition[:time] - cycle_start_time
          current_first = first_transitions[sig][cycle]
          if current_first.nil? || relative_time < current_first
            first_transitions[sig][cycle] = relative_time
          end
        end
      end
      first_transitions
    end
        


      

    def cycle_id(time)
      (time / @step_time).floor
    end

    def cycle_ids(rows)
      if @nb_cycles
        return (0...@nb_cycles).to_a
      end

      return [] if rows.empty?

      max_time = rows.map { |row| row[:time] }.max
      max_cycle = cycle_id(max_time)

      (0..max_cycle).to_a
    end

    def analyzed_signals
      if @signals_to_analyze
        @signals_to_analyze & @observed_signals
      else
        @observed_signals
      end
    end

    def print_results(cycle_activity, stats)
      # puts
      # puts "[1.1] Activity per node and per cycle"

      # cycle_activity.each do |sig, cycles|
      #   puts
      #   puts sig

      #   cycles.keys.sort.each do |cycle|
      #     puts "  cycle #{cycle} : #{cycles[cycle]} transitions"
      #   end
      # end

      puts
      puts "[1.2] Statistics per node"

      puts format(
        "%-12s %8s %12s %12s %8s %8s",
        "signal",
        "total",
        "avg/cycle",
        "stddev",
        "min",
        "max"
      )

      stats.each do |sig, s|
        puts format(
          "%-12s %8d %12.3f %12.3f %8d %8d",
          sig,
          s[:total],
          s[:average_per_cycle],
          s[:stddev_per_cycle],
          s[:min_per_cycle],
          s[:max_per_cycle]
        )
      end

      total_activity = stats.values.sum { |s| s[:total] }

      puts
      puts "[1.3] Global activity"
      puts "total transitions: #{total_activity}"
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