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
  circuit_name: "random_IC"
)

puts
puts "[+] Circuit:"
puts "inputs: #{circuit.inputs.map(&:name).join(', ')}"
puts "outputs: #{circuit.outputs.map(&:name).join(', ')}"
puts "components: #{circuit.components.map(&:instance_name).join(', ')}"

Seda::VHDLGenerator.new.generate(circuit)