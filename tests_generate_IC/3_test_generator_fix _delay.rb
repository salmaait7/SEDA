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

circuit = synth.synthesize(
  expressions,
  circuit_name: "circuit2"
)

puts
puts "[+] Circuit generated:"
puts "inputs: #{circuit.inputs.map(&:name).join(', ')}"
puts "outputs: #{circuit.outputs.map(&:name).join(', ')}"
puts "components: #{circuit.components.size}"

generator_vhdl = Seda::VHDLDelayGenerator.new

generator_vhdl.generate(circuit)

puts