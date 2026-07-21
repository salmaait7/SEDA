require_relative "../lib/seda"

circuit_name = ENV.fetch("CIRCUIT", "c432")
verilog_file = ENV.fetch("VERILOG_FILE", "data/#{circuit_name}.v")
activity_root = ENV.fetch("ACTIVITY_ROOT", "results/activity")
analysis_root = ENV.fetch("ANALYSIS_ROOT", "results/analysis")
step_time = Float(ENV.fetch("STEP_TIME_NS", "20.0"))
nb_vectors = Integer(ENV.fetch("NB_VECTORS", "100"))

parser = Seda::VerilogGateCircuitParser.new
netlist = parser.parse_netlist(
  file: verilog_file,
  circuit_name: circuit_name
)
circuit = Seda::GateCircuitSynthesizer.new.build_from_netlist(netlist)

input_signals = circuit.inputs.map(&:name)
nb_cycles = [nb_vectors, 2**input_signals.length].min

activity_files = Dir.glob(
  File.join(activity_root, "margin_*", "#{circuit_name}_*_activity.csv")
).sort

if activity_files.empty?
  abort "[ERROR] No activity CSV files found for #{circuit_name} in #{activity_root}"
end

puts "[+] Circuit: #{circuit_name}"
puts "[+] Inputs excluded: #{input_signals.join(', ')}"
puts "[+] Cycles: #{nb_cycles}"
puts "[+] Activity files: #{activity_files.size}"

activity_files.each do |activity_file|
  margin_name = File.basename(File.dirname(activity_file))
  run_name = File.basename(activity_file, ".csv")

  result = Seda::ActivityAnalyzer.analyze_file(
    activity_file,
    input_signals: input_signals,
    step_time: step_time,
    nb_cycles: nb_cycles
  )

  output_file = File.join(
    analysis_root,
    margin_name,
    "#{run_name}_nwc.csv"
  )

  Seda::ActivityAnalyzer.save_cycle_activity(result, output_file)
end

puts "[+] All clean variation activity files analyzed"