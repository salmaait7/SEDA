require "csv"

show_details = ARGV.delete("--details")
ref_file = ARGV.shift
run_file = ARGV.shift

NB_CYCLES = Integer(
  ENV.fetch("NB_CYCLES", "436")
)
CYCLE_TIME_PS = 20_000

def load_activity(file)
  data = {}

  CSV.foreach(file, headers: true) do |row|
    sequence = row["sequence"].to_s.split(">").reject(&:empty?)

    times = row["transition_times"]
      .to_s
      .split(">")
      .reject(&:empty?)
      .map { |time| (time.to_f * 1000).round }

    key = [row["signal"], row["cycle"].to_i]

    data[key] = {
      sequence: sequence,
      times: times
    }
  end

  data
end

def percentile(values, level)
  sorted = values.sort
  position = (sorted.size - 1) * level

  lower = position.floor
  upper = position.ceil

  sorted[lower] +
    (sorted[upper] - sorted[lower]) *
    (position - lower)
end

def temporal_hamming(reference_times, run_times, cycle_time)
  events = reference_times + run_times
  events = events.select { |time| time >= 0 && time < cycle_time }

  events << cycle_time # events contient tous les instants de transition, y compris la fin du cycle
  events.sort!

  different = false
  previous_time = 0
  duration = 0

  events.each do |time|
    duration += time - previous_time if different

    different = !different unless time == cycle_time

    previous_time = time
  end
  duration
end

ref = load_activity(ref_file)
run = load_activity(run_file)

ref_signals = ref.keys.map(&:first).uniq
run_signals = run.keys.map(&:first).uniq

signals = (ref_signals & run_signals)
  .reject do |signal|
    signal.start_with?("ALTER_") ||
      signal.match?(/\Anet\d+\z/)
  end
  .sort

empty_data = {
  sequence: [],
  times: []
}

n_changed = 0
sequence_changed = 0
timing_pairs = 0
delta_t = []
hamming_durations = []


signals.each do |signal|
  (0...NB_CYCLES).each do |cycle|
    key = [signal, cycle]

    reference_data = ref[key] || empty_data
    run_data = run[key] || empty_data

    reference_n = reference_data[:sequence].size
    run_n = run_data[:sequence].size

    n_changed += 1 if reference_n != run_n

    sequence_difference =
      reference_data[:sequence] != run_data[:sequence]

    sequence_changed += 1 if sequence_difference

    hamming = temporal_hamming(
      reference_data[:times],
      run_data[:times],
      CYCLE_TIME_PS
    )

    hamming_durations << hamming

   

    if sequence_difference && show_details
      puts(
        "Signal: #{signal}, " \
        "Cycle: #{cycle}, " \
        "Ref: #{reference_data[:sequence].join('>')}, " \
        "Run: #{run_data[:sequence].join('>')}, " \
        "Hamming: #{ hamming/ 1000.0} ns"
      )
    end

    timing_comparable =
      reference_n > 0 &&
      reference_data[:sequence] == run_data[:sequence]

    next unless timing_comparable

    timing_pairs += 1

    reference_data[:times]
      .zip(run_data[:times])
      .each do |reference_time, run_time|
        delta_t << (run_time - reference_time).abs
      end
  end
end

total_pairs = signals.size * NB_CYCLES

n_changed_rate =
  100.0 * n_changed / total_pairs

sequence_changed_rate =
  100.0 * sequence_changed / total_pairs

nonzero_delta_t =
  delta_t.select(&:positive?) # on prend uniquement les différences non nulles pour le calcul des statistiques

nonzero_hamming =
  hamming_durations.select(&:positive?)

hamming_changed_rate =
  100.0 * nonzero_hamming.size / total_pairs

total_hamming =
  hamming_durations.sum

global_hamming_rate =
  100.0 * total_hamming /
  (total_pairs * CYCLE_TIME_PS)

puts
puts "=================================================="
puts "Comparison results"
puts "=================================================="
puts
puts "Reference file          : #{ref_file}"
puts "Compared file           : #{run_file}"
puts
puts "Signals                 : #{signals.size}"
puts "Cycles                  : #{NB_CYCLES}"
puts "Total pairs             : #{total_pairs}"
puts
puts "N changed               : #{n_changed}"
puts "N changed rate          : #{format('%.4f', n_changed_rate)} %"
puts
puts
# puts "Timing pairs comparable : #{timing_pairs}" # les paires comparables sont celles qui ont la même séquence de transitions
puts "Comparable transitions  : #{delta_t.size}"

unless nonzero_delta_t.empty?
  mean = nonzero_delta_t.sum.to_f / nonzero_delta_t.size
  median = percentile(nonzero_delta_t, 0.50)
  p95 = percentile(nonzero_delta_t, 0.95)
  maximum = nonzero_delta_t.max

  shifted_rate =
    100.0 * nonzero_delta_t.size / delta_t.size

  puts
  # puts "Shifted transitions     : #{nonzero_delta_t.size}"
  puts "Shifted transition rate : #{format('%.4f', shifted_rate)} %"
  # puts "Mean |ΔT|      : #{format('%.6f', mean / 1000.0)} ns"
  puts "Median |ΔT|    : #{format('%.6f', median / 1000.0)} ns"
  puts "P95 |ΔT|       : #{format('%.6f', p95 / 1000.0)} ns"
  puts "Max |ΔT|       : #{format('%.6f', maximum / 1000.0)} ns"
end

puts