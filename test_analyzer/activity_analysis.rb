require_relative "../lib/ActivityAnalyzer/analyzer"

signals = [
  "x1", "x0", "x3", "x4", "x2",
  "y0", "y1", "y2"
] + (0..15).map { |i| "dbg_w#{i}" }

input_signals = ["x1", "x0", "x3", "x4", "x2"]

files = {
  fixed: "activity/activity_circuit_fixed_delay.csv",
  inter_die: "activity/activity_circuit_fixed_epsilon.csv",
  variable_epsilon: "activity/activity_circuit_variable_epsilon.csv"
}

results = {}

files.each do |case_name, file|
  puts
  puts "===================================="
  puts "Case: #{case_name}"
  puts "File: #{file}"
  puts "===================================="

  analyzer = Seda::ActivityAnalyzer.new(
    file: file,
    signals: signals,
    input_signals: input_signals
  )

  results[case_name] = analyzer.run
end