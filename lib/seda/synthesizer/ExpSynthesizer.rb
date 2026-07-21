module Seda
  class ExprSynthesizer
    def initialize
      @gate_index = 0
      @ports = {}
      @exp_cache = {}
    end

    def synthesize(expressions, circuit_name: "random_circuit")
      @circuit = Circuit.new(circuit_name)
      @gate_index = 0
      @ports = {}
      @exp_cache = {} # cache for already synthesized expressions

      expressions.each_with_index do |expr, i|
        final_port = synth_expr(expr) # we get the final port of the expression, which is the output of the last gate in the expression tree

        out = Output.new("y#{i}")
        @circuit << out

        final_port.connect_to(out) # we connect the final port to an output port (passe from math to circuit)
      end

      @circuit
    end

    def synth_expr(expr) # the function that takes us from our logical expressions to a circuit(function of synthesizer)

      # variables are already handled by @ports
      # for gates/expressions, reuse the port if this expression was already synthesized
      unless expr.is_a?(Expr::Var)
        key = expr.object_id

        if @exp_cache.key?(key)
          return @exp_cache[key]
        end
      end

      result =
        case expr
        when Expr::Var
          get_or_create_input(expr.name)

        when Expr::Buffer
          synth_unary(expr, Gtech::Buf.new)

        when Expr::Not
          synth_unary(expr, Gtech::Not.new)

        when Expr::And
          synth_binary(expr, Gtech::And2.new)

        when Expr::Or
          synth_binary(expr, Gtech::Or2.new)

        when Expr::Xor
          synth_binary(expr, Gtech::Xor2.new)

        when Expr::Nand
          synth_binary(expr, Gtech::Nand2.new)

        when Expr::Nor
          synth_binary(expr, Gtech::Nor2.new)

        else
          raise "unsupported expression: #{expr.class}"
        end

      # store the generated output port for this expression
      unless expr.is_a?(Expr::Var)
        @exp_cache[key] = result
      end

      result
    end

    def get_or_create_input(name)
      return @ports[name] if @ports[name]

      input = Input.new(name)
      @ports[name] = input
      @circuit << input

      input
    end

    def synth_unary(expr, gate)
      src = synth_expr(expr.expr)
      add_gate(gate)
      src.connect_to(gate.get_port_named("e"))

      gate.get_port_named("f")
    end

    def synth_binary(expr, gate) # synth of 2 inputs gates
      

      left_src  = synth_expr(expr.lhs)
      right_src = synth_expr(expr.rhs)
      add_gate(gate) 

      left_src.connect_to(gate.get_port_named("e1"))
      right_src.connect_to(gate.get_port_named("e2"))

      gate.get_port_named("f")
    end

    def add_gate(gate)
      gate.instance_name = "U#{@gate_index}" if gate.respond_to?(:instance_name=)
      @gate_index += 1

      @circuit << gate
    end
  end
end