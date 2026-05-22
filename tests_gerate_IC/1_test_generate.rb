require_relative "../lib/seda"

vars = 1.times.map { |i| Seda::Expr::Var.new("x#{i}") }

generator = Seda::ExprRandGen.new(
  vars: vars,
  depth: 3,
  nb_outputs: 2
)

expr = generator.generate

puts expr