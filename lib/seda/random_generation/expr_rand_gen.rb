require_relative "expr_ast"

#generates random expressions with controlled dpth
module Seda
  class ExprRandGen
    EXPR_KIND = {
      1 => [Expr::Not, Expr::Buffer],
      2 => [Expr::And, Expr::Or, Expr::Xor, Expr::Nand, Expr::Nor]
    }

    def initialize(vars:, depth:, nb_outputs:, reuse_probability: 0.5)
      @vars = vars.map { |v| Expr::Var.new(v) }
      @depth = depth
      @nb_outputs = nb_outputs
      @reuse_probability = reuse_probability
      @expr_pool = [] # to store generated expressions for potential reuse
      @unused_vars = []
    end

    def generate
      expressions = []
      @expr_pool = [] # pool of previously generated expressions for reuse
      @unused_vars = @vars.shuffle # inputs that must be used at least once

      @nb_outputs.times do
        expressions << gen_expr(@depth, top_level: true)
      end

      if @unused_vars.any?
        puts "some inputs were not used:"
        puts @unused_vars.map(&:name).join(", ")
      end

      expressions
    end

    def gen_expr(depth, top_level: false)
      if depth == 0
        return choose_var
      end

      # to prevent that some inputs are never used, we force the generator to use them until they are all used at least once
      if !top_level && @unused_vars.empty? && !@expr_pool.empty? && rand < @reuse_probability
        return @expr_pool.sample
      end

      arity = choose_arity
      gate_kind = EXPR_KIND[arity].sample

      expr =
        if arity == 1
          gate_kind.new(gen_expr(depth - 1))
        else
          gate_kind.new(gen_expr(depth - 1), gen_expr(depth - 1)) # it generates per example (x0 And (Not x1))
        end

      remember_expr(expr)

      expr
    end

    def choose_var
      # first use inputs that have not appeared yet
      # after that, choose randomly from all inputs
      if @unused_vars.any?
        @unused_vars.shift
      else
        @vars.sample
      end
    end

    def choose_arity
      # while some inputs are still unused, prefer binary gates
      # because binary gates create more leaves and help consume all inputs
      if @unused_vars.any?
        2
      else
        [1, 2].sample
      end
    end

    def remember_expr(expr)
      return if expr.is_a?(Expr::Var) # don't store variables in the pool

      @expr_pool << expr unless @expr_pool.include?(expr) # avoid duplicat
    end
  end
end