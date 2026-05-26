require_relative "../lib/seda"

vars = 5.times.map { |i| "x#{i}" }

expr_generator = Seda::ExprRandGen.new(
  vars: vars,
  depth: 3,
  nb_outputs: 3
)

expressions = expr_generator.generate

puts "[+] Generated expressions:"
expressions.each_with_index do |expr, i|
  puts "y#{i} = #{expr}"
end

synth = Seda::ExprSynthesizer.new

circuit = synth.synthesize(
  expressions,
  circuit_name: "random_delay_circuit"
)

Seda::VHDLGenerator.new.generate(circuit)

Seda::TestbenchGenerator.new(
  step_time: "20 ns",
  nb_vectors: 16
).generate(circuit)