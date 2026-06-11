require_relative "circuit_example"

circuits = build_example_circuits

circuit_fixed_delay = circuits[:fixed_delay]
circuit_fixed_epsilon = circuits[:fixed_epsilon]
circuit_variable_epsilon = circuits[:variable_epsilon]

puts
puts "[+] Circuit generated:"
puts "inputs: #{circuit_fixed_delay.inputs.map(&:name).join(', ')}"
puts "outputs: #{circuit_fixed_delay.outputs.map(&:name).join(', ')}"
puts "components: #{circuit_fixed_delay.components.size}"

Seda::VHDLDelayGenerator.new(delay_mode: :fixed)
  .generate(circuit_fixed_delay)

Seda::VHDLDelayGenerator.new(delay_mode: :inter_die)
  .generate(circuit_fixed_epsilon)

Seda::VHDLDelayGenerator.new(delay_mode: :intra_die)
  .generate(circuit_variable_epsilon)

puts

Seda::TestbenchGenerator.new(
  step_time: "20 ns",
  nb_vectors: 16
).generate(circuit_fixed_delay)

Seda::TestbenchGenerator.new(
  step_time: "20 ns",
  nb_vectors: 16
).generate(circuit_fixed_epsilon)

Seda::TestbenchGenerator.new(
  step_time: "20 ns",
  nb_vectors: 16
).generate(circuit_variable_epsilon)