require "fileutils"
require_relative "../../lib/seda"

circuit_name = ENV.fetch(
  "CIRCUIT",
  "c432"
)

verilog_file = ENV.fetch(
  "VERILOG_FILE",
  "data/benchmarks/clean/#{circuit_name}.v"
)

delay_file = ENV.fetch(
  "DELAY_FILE",
  "data/delay_mode/gate_delays.json"
)

margins = ENV.fetch(
  "MARGINS",
  "0.05,0.10,0.15,0.20"
).split(",").map do |value|
  Float(value)
end

number_of_runs = Integer(
  ENV.fetch("NUMBER_OF_RUNS", "30")
)

step_time_ns = Float(
  ENV.fetch("STEP_TIME_NS", "40.0")
)

nb_vectors = Integer(
  ENV.fetch("NB_VECTORS", "100")
)

stimulus_seed = Integer(
  ENV.fetch("STIMULUS_SEED", "42")
)

debug =
  ENV.fetch(
    "DEBUG_INTERNAL_SIGNALS",
    "false"
  ) == "true"

abort("[ERROR] Verilog file not found: #{verilog_file}") \
  unless File.file?(verilog_file)

abort("[ERROR] Delay JSON not found: #{delay_file}") \
  unless File.file?(delay_file)

parser = Seda::VerilogGateCircuitParser.new

netlist = parser.parse_netlist(
  file: verilog_file,
  circuit_name: circuit_name
)

circuit =
  Seda::GateCircuitSynthesizer
    .new
    .build_from_netlist(netlist)

actual_vector_count = [
  nb_vectors,
  2**circuit.inputs.length
].min

#generation des entrees

metadata_dir = "data/inputs"
FileUtils.mkdir_p(metadata_dir)

inputs_file = File.join(
  metadata_dir,
  "inputs_#{circuit_name}.txt"
)

input_names = circuit.inputs.map(&:name)

File.write(
  inputs_file,
  input_names.join("\n") + "\n"
)



margin_labels = margins.map do |margin|
  format(
    "%g%%",
    margin * 100
  )
end

puts
puts "=================================================="
puts "Circuit generation"
puts "=================================================="
puts
puts "[+] Circuit: #{circuit_name}"
puts "[+] Verilog file: #{verilog_file}"
puts "[+] Inputs: #{circuit.inputs.length}"
puts "[+] Outputs: #{circuit.outputs.length}"
puts "[+] Gates: #{circuit.components.length}"
puts "[+] Delay margins: #{margin_labels.join(', ')}"
puts "[+] Runs per margin: #{number_of_runs}"
puts "[+] Stimulus vectors: #{actual_vector_count}"
puts "[+] Stimulus seed: #{stimulus_seed}"
puts "[+] Step time: #{step_time_ns} ns"
puts "[+] Debug signals: #{debug}"
puts "[+] Input list: #{inputs_file}"



reference_name = format(
  "%s_margin_00_run_%03d",
  circuit_name,
  1
)

Seda::VHDLDelayGenerator.new(
  delay_file: delay_file,
  delay_mode: :fixed,
  margin: 0.0,
  seed: 0,
  debug: debug
).generate(
  circuit,
  output_dir:
    "build/vhdl/circuits/#{circuit_name}/margin_00",
  filename:
    "#{reference_name}.vhd",
  delay_report_file:
    "build/delays/#{circuit_name}/margin_00/" \
    "#{reference_name}_delays.csv"
)


margins.each do |margin|
  margin_percent = (
    margin * 100
  ).round

  margin_name = format(
    "margin_%02d",
    margin_percent
  )

  1.upto(number_of_runs) do |run_number|
    delay_seed =
      (margin_percent * 100_000) +
      run_number

    run_name = format(
      "%s_margin_%02d_run_%03d",
      circuit_name,
      margin_percent,
      run_number
    )

    Seda::VHDLDelayGenerator.new(
      delay_file: delay_file,
      delay_mode: :intra_die,
      margin: margin,
      seed: delay_seed,
      debug: debug
    ).generate(
      circuit,
      output_dir:
        "build/vhdl/circuits/#{circuit_name}/#{margin_name}",
      filename:
        "#{run_name}.vhd",
      delay_report_file:
        "build/delays/#{circuit_name}/#{margin_name}/" \
        "#{run_name}_delays.csv"
    )
  end
end


Seda::TestbenchGenerator.new(
  step_time: "#{step_time_ns} ns",
  nb_vectors: actual_vector_count,
  debug: debug,
  stimulus_seed: stimulus_seed
).generate(circuit)



puts
puts "=================================================="
puts "Generation completed"
puts "=================================================="
puts
puts "[+] Circuit: #{circuit_name}"
puts "[+] Reference: #{reference_name}"
puts "[+] Runs per margin: #{number_of_runs}"
puts "[+] Number of margins: #{margins.length}"
puts "[+] Total varied runs: #{margins.length * number_of_runs}"
puts "[+] Number of vectors: #{actual_vector_count}"
puts "[+] Stimulus seed: #{stimulus_seed}"
puts "[+] Inputs file: #{inputs_file}"
puts