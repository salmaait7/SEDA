require "fileutils"
require_relative "../../lib/seda"

def build_circuit(file:, circuit_name:)
  parser = Seda::VerilogGateCircuitParser.new

  netlist = parser.parse_netlist(
    file: file,
    circuit_name: circuit_name
  )

  Seda::GateCircuitSynthesizer.new.build_from_netlist(netlist)
end

def port_names(ports)
  ports.map(&:name)
end

def validate_same_interface!(clean, trojan)
  unless port_names(clean.inputs) == port_names(trojan.inputs)
    raise "Les entrées clean et Trojan diffèrent ou sont dans un ordre différent"
  end

  unless port_names(clean.outputs) == port_names(trojan.outputs)
    raise "Les sorties clean et Trojan diffèrent ou sont dans un ordre différent"
  end
end

def delays_by_instance(generator)
  generator.applied_delays.each_with_object({}) do |delay, result|
    name = delay.fetch(:instance_name)

    raise "Instance dupliquée : #{name}" if result.key?(name)

    result[name] = delay
  end
end

def verify_paired_delays!(clean_generator, trojan_generator, label:)
  clean = delays_by_instance(clean_generator)
  trojan = delays_by_instance(trojan_generator)

  missing = clean.keys - trojan.keys

  unless missing.empty?
    raise "Instances clean absentes du Trojan : #{missing.join(', ')}"
  end

  mismatches = clean.keys.select do |name|
    clean.fetch(name).fetch(:gate_type) !=
      trojan.fetch(name).fetch(:gate_type) ||
      clean.fetch(name).fetch(:epsilon) !=
        trojan.fetch(name).fetch(:epsilon)
  end

  unless mismatches.empty?
    raise "Appariement incorrect pour #{label} : #{mismatches.join(', ')}"
  end

  puts "[+] Appariement vérifié : #{label}"
end

def generate_case(
  circuit:,
  variant:,
  circuit_name:,
  margin_percent:,
  run_number:,
  delay_file:,
  margin:,
  seed:
)
  margin_name = format("margin_%02d", margin_percent)

  run_name = format(
    "%s_%s_margin_%02d_run_%03d",
    circuit_name,
    variant,
    margin_percent,
    run_number
  )

  generator = Seda::VHDLDelayGenerator.new(
    delay_file: delay_file,
    delay_mode: margin.zero? ? :fixed : :intra_die,
    margin: margin,
    seed: seed,
    debug: false
  )

  generator.generate(
    circuit,
    output_dir: File.join(
      "build", "vhdl", "paired", variant.to_s, margin_name
    ),
    filename: "#{run_name}.vhd",
    delay_report_file: File.join(
      "build", "delays", "paired",
      variant.to_s, margin_name, "#{run_name}_delays.csv"
    )
  )

  generator
end

# Paramètres transmis par le lanceur
circuit_name = ENV.fetch("CIRCUIT", "c432")

clean_file = ENV.fetch(
  "CLEAN_VERILOG_FILE",
  "data/benchmarks/clean/#{circuit_name}.v"
)

trojan_file = ENV.fetch(
  "TROJAN_VERILOG_FILE",
  "data/benchmarks/trojan/#{circuit_name}_alt2.v"
)

delay_file = ENV.fetch(
  "DELAY_FILE",
  "config/delay_models/gate_delays.json"
)

margins = ENV.fetch("MARGINS", "0.05,0.10,0.15,0.20")
             .split(",")
             .map { |value| Float(value) }

number_of_runs = Integer(ENV.fetch("NUMBER_OF_RUNS", "30"))
nb_vectors = Integer(ENV.fetch("NB_VECTORS", "100"))
step_time_ns = Float(ENV.fetch("STEP_TIME_NS", "40.0"))
stimulus_seed = Integer(ENV.fetch("STIMULUS_SEED", "42"))

# Vérifications
[clean_file, trojan_file, delay_file].each do |file|
  raise "Fichier introuvable : #{file}" unless File.file?(file)
end

raise "NUMBER_OF_RUNS doit être > 0" unless number_of_runs.positive?
raise "NB_VECTORS doit être > 0" unless nb_vectors.positive?
raise "STEP_TIME_NS doit être > 0" unless step_time_ns.positive?

unless !margins.empty? && margins.all?(&:positive?)
  raise "Il faut au moins une marge, strictement positive"
end

# Les noms des fichiers utilisent des pourcentages entiers
margin_percentages = margins.map { |margin| (margin * 100).round }

if margin_percentages.any?(&:zero?) ||
   margin_percentages.uniq.length != margin_percentages.length
  raise "Les marges produisent des noms nuls ou dupliqués après arrondi"
end

# Construction des deux circuits
clean_circuit = build_circuit(
  file: clean_file,
  circuit_name: circuit_name
)

trojan_circuit = build_circuit(
  file: trojan_file,
  circuit_name: circuit_name
)

validate_same_interface!(clean_circuit, trojan_circuit)

# Listes communes des entrées et sorties
inputs_file = "data/inputs/inputs_#{circuit_name}.txt"
outputs_file = "data/outputs/outputs_#{circuit_name}.txt"

FileUtils.mkdir_p(File.dirname(inputs_file))
FileUtils.mkdir_p(File.dirname(outputs_file))

File.write(
  inputs_file,
  port_names(clean_circuit.inputs).join("\n") + "\n"
)

File.write(
  outputs_file,
  port_names(clean_circuit.outputs).join("\n") + "\n"
)


cases = [[0.0, 0, 1, 0]]

margins.each do |margin|
  percent = (margin * 100).round

  1.upto(number_of_runs) do |run_number|
    seed = percent * 100_000 + run_number
    cases << [margin, percent, run_number, seed]
  end
end

circuits = {
  clean: clean_circuit,
  trojan: trojan_circuit
}

cases.each do |margin, percent, run_number, seed|
  generators = {}

  circuits.each do |variant, circuit|
    generators[variant] = generate_case(
      circuit: circuit,
      variant: variant,
      circuit_name: circuit_name,
      margin_percent: percent,
      run_number: run_number,
      delay_file: delay_file,
      margin: margin,
      seed: seed
    )
  end

  verify_paired_delays!(
    generators.fetch(:clean),
    generators.fetch(:trojan),
    label: format("margin_%02d/run_%03d", percent, run_number)
  )
end

# Même testbench et mêmes stimuli
actual_vector_count = [
  nb_vectors,
  2**clean_circuit.inputs.length
].min

Seda::TestbenchGenerator.new(
  step_time: "#{step_time_ns} ns",
  nb_vectors: actual_vector_count,
  debug: false,
  stimulus_seed: stimulus_seed
).generate(clean_circuit)

puts "Génération terminée : #{cases.length * 2} circuits VHDL."
puts "Vecteurs de test : #{actual_vector_count}"