require_relative "../lib/seda"

vars = 5.times.map { |i| "x#{i}" }

generator = Seda::ExprRandGen.new(
  vars: vars,
  depth: 3,
  nb_outputs: 3
)

expressions = generator.generate

puts "[+] Generated expressions:"
expressions.each_with_index do |expr, i|
  puts "y#{i} = #{expr}"
end

synth = Seda::ExprSynthesizer.new

circuit_fixed_delay = synth.synthesize(
  expressions,
  
  circuit_name: "circuit_fixed_delay"
)

circuit_fixed_epsilon = synth.synthesize(
  expressions,  
  circuit_name: "circuit_fixed_epsilon"
)

circuit_variable_epsilon = synth.synthesize(
  expressions,
  circuit_name: "circuit_variable_epsilon"
)

puts
puts "[+] Circuit generated:"
puts "inputs: #{circuit_fixed_delay.inputs.map(&:name).join(', ')}"
puts "outputs: #{circuit_fixed_delay.outputs.map(&:name).join(', ')}"
puts "components: #{circuit_fixed_delay.components.size}"

generator_vhdl_C1= Seda::VHDLDelayGenerator.new(delay_mode: :fixed)
generator_vhdl_C1.generate(circuit_fixed_delay) 

generator_vhdl_C2= Seda::VHDLDelayGenerator.new(delay_mode: :inter_die)
generator_vhdl_C2.generate(circuit_fixed_epsilon)

generator_vhdl_C3= Seda::VHDLDelayGenerator.new(delay_mode: :intra_die)
generator_vhdl_C3.generate(circuit_variable_epsilon)

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


