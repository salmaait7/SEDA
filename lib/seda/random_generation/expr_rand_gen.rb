require_relative "expr_ast"

# generates random expressions with controlled depth
module Seda
  class ExprRandGen
    EXPR_KIND = {
      1 => [Expr::Not, Expr::Buffer],
      2 => [Expr::And, Expr::Or, Expr::Xor, Expr::Nand, Expr::Nor]
    }

    def initialize(vars:, depth:, nb_outputs:)
      @vars = vars.map { |v| Expr::Var.new(v) }
      @depth = depth
      @nb_outputs = nb_outputs
      @expr_pool = []
      @unused_vars = []
    end

    def generate
      expressions = []
      @expr_pool = []
      @unused_vars = @vars.shuffle 

      @common_depth = rand(1..@depth)
      puts "common depth: #{@common_depth}"
      common_expr = gen_common_expr(@common_depth)

      @nb_outputs.times do
        expressions << extend_path_from_common(common_expr)
      end

      if @unused_vars.any?
        puts "some inputs were not used:"
        puts @unused_vars.map(&:name).join(", ")
      end

      expressions
    end

    def gen_common_expr(depth)
      return choose_var if depth <= 0

      gate_kind = EXPR_KIND[2].sample
      gate_kind_unary = EXPR_KIND[1].sample

      if depth == 1
        gate_kind.new(choose_var, choose_var)
      else
        if rand < 0.5
          gate_kind.new(gen_common_expr(depth - 1), choose_var)
        else
          gate_kind_unary.new(gen_common_expr(depth - 1))
        end
      end
    end

    def extend_path_from_common(common_expr)
      path_length = @depth - @common_depth
      expr = common_expr

      path_length.times do
        gate_kind = EXPR_KIND[2].sample
        gate_kind_unary = EXPR_KIND[1].sample
        side_expr = choose_var

        expr =
          if rand < 0.3
            gate_kind_unary.new(expr)
          else
            gate_kind.new(side_expr, expr)
          end
      end

      expr
    end

    def choose_var
      if @unused_vars.any?
        @unused_vars.shift
      else
        @vars.sample
      end
    end
  end
end