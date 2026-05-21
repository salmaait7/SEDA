require_relative "../lib/seda"

vars = 5.times.map { |i| Seda::Expr::Var.new("x#{i}") }

generator = Seda::ExprRandGen.new(
  vars: vars,
  depth: 3
)

expr = generator.generate

puts expr