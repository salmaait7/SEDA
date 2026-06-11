# tests_generate_IC/5_dot.rb

require_relative "circuit_example"

circuits = build_example_circuits

circuit = circuits[:fixed_epsilon]

generator = Seda::DotGenerator.new
generator.generate(circuit)