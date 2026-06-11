
require_relative "../lib/seda"

def build_example_circuits
  vars = 3.times.map { |i| "x#{i}" }

  generator = Seda::ExprRandGen.new(
    vars: vars,
    depth: 3,
    nb_outputs: 5,
    reuse_probability: 0.7
  )

  expressions = generator.generate

  puts "[+] Generated expressions:"
  expressions.each_with_index do |expr, i|
    puts "y#{i} = #{expr}"
  end

  synth = Seda::ExprSynthesizer.new

  {
    fixed_delay: synth.synthesize(
      expressions,
      circuit_name: "circuit_fixed_delay"
    ),

    fixed_epsilon: synth.synthesize(
      expressions,
      circuit_name: "circuit_fixed_epsilon"
    ),

    variable_epsilon: synth.synthesize(
      expressions,
      circuit_name: "circuit_variable_epsilon"
    )
  }
end