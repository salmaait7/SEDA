require_relative "expr_ast"
#generates random expressions with controlled dpth
module Seda
  class ExprRandGen
    EXPR_KIND = {
      1 => [Expr::Not, Expr::Buffer],
      2 => [Expr::And, Expr::Or, Expr::Xor, Expr::Nand, Expr::Nor]
    }

    def initialize(vars:, depth:)
      @vars = vars.map { |v| Expr::Var.new(v) }
      @depth = depth
    end

    def generate
      gen_expr(@depth)
    end

    def gen_expr(depth)
      if depth == 0
        return @vars.sample
      end

      arity = [1, 2].sample
      gate_kind = EXPR_KIND[arity].sample

      if arity == 1
        gate_kind.new(gen_expr(depth - 1))
      else
        gate_kind.new(gen_expr(depth - 1), gen_expr(depth - 1)) # it generates per example (x0 And (Not x1))
      end
    end
  end
end