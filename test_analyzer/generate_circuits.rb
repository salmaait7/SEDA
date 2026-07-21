# frozen_string_literal: true

require_relative "../lib/seda"

circuit_name = ENV.fetch("CIRCUIT", "c432")
verilog_file = ENV.fetch("VERILOG_FILE", "data/#{circuit_name}.v")
margins = ENV.fetch("MARGINS", "0.05,0.10,0.15,0.20")
             .split(",")
             .map { |value| Float(value) }
number_of_runs = Integer(ENV.fetch("NUMBER_OF_RUNS", "30"))
step_time_ns = Float(ENV.fetch("STEP_TIME_NS", "20.0"))
nb_vectors = Integer(ENV.fetch("NB_VECTORS", "100"))
debug = ENV.fetch("DEBUG_INTERNAL_SIGNALS", "true") == "true"

parser = Seda::VerilogGateCircuitParser.new
netlist = parser.parse_netlist(
  file: verilog_file,
  circuit_name: circuit_name
)

circuit = Seda::GateCircuitSynthesizer.new.build_from_netlist(netlist)
actual_vector_count = [nb_vectors, 2**circuit.inputs.length].min

puts "[+] Circuit: #{circuit_name}"
puts "[+] Gates: #{circuit.components.length}"
puts "[+] Delay margins: #{margins.map { |m| format('%g%%', m * 100) }.join(', ')}"
puts "[+] Runs per margin: #{number_of_runs}"
puts "[+] Stimulus vectors: #{actual_vector_count}"

# Generate the nominal reference once.
reference_name = format("%s_margin_00_run_%03d", circuit_name, 1)
Seda::VHDLDelayGenerator.new(
  delay_mode: :fixed,
  margin: 0.0,
  seed: 0,
  debug: debug
).generate(
  circuit,
  output_dir: "generated/vhdl/circuits/margin_00",
  filename: "#{reference_name}.vhd",
  delay_report_file:
    "generated/delays/margin_00/#{reference_name}_delays.csv"
)

# Generate clean circuits affected only by intra-die delay variation.
margins.each do |margin|
  margin_percent = (margin * 100).round
  margin_name = format("margin_%02d", margin_percent)

  1.upto(number_of_runs) do |run_number|
    seed = (margin_percent * 100_000) + run_number
    run_name = format(
      "%s_margin_%02d_run_%03d",
      circuit_name,
      margin_percent,
      run_number
    )

    Seda::VHDLDelayGenerator.new(
      delay_mode: :intra_die,
      margin: margin,
      seed: seed,
      debug: debug
    ).generate(
      circuit,
      output_dir: "generated/vhdl/circuits/#{margin_name}",
      filename: "#{run_name}.vhd",
      delay_report_file:
        "generated/delays/#{margin_name}/#{run_name}_delays.csv"
    )
  end
end

# All runs use exactly the same deterministic stimulus sequence.
Seda::TestbenchGenerator.new(
  step_time: "#{step_time_ns} ns",
  nb_vectors: actual_vector_count,
  debug: debug
).generate(circuit)

puts "[+] Clean variation cases generated successfully"