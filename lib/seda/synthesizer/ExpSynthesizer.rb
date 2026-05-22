

module Seda
  class ExprSynthesizer
    def initialize
      @gate_index = 0
    end

    def synthesize(expressions, circuit_name: "random_circuit") 
      @circuit = Circuit.new(circuit_name)
      @gate_index = 0

      expressions.each_with_index do |expr, i|
        final_port = synth_expr(expr) # we get the final port of the expression, which is the output of the last gate in the expression tree

        out = Output.new("y#{i}")
        @circuit << out  

        final_port.connect_to(out) #we connect the final port to an output port ( passe from math to circuit)
      end

      @circuit
    end

    

    def synth_expr(expr) # the function that takes us from our logical expressions to a circuit(function of synthesizer)
      case expr
      when Expr::Var
        input = @circuit.get_port_named(expr.name)

        unless input
          input = Input.new(expr.name)
          @circuit << input
        end

        input

      when Expr::Buffer
        src = synth_expr(expr.expr)
        gate = new_gate(:buffer)
        @circuit << gate

        src.connect_to(gate.inputs[0])
        gate.outputs[0]

      when Expr::Not
        src = synth_expr(expr.expr)
        gate = new_gate(:not)
        @circuit << gate

        src.connect_to(gate.inputs[0])
        gate.outputs[0]

      when Expr::And, Expr::Or, Expr::Xor, Expr::Nand, Expr::Nor
        left_src  = synth_expr(expr.lhs)
        right_src = synth_expr(expr.rhs)

        gate = new_gate(expr.op)
        @circuit << gate

        left_src.connect_to(gate.inputs[0])
        right_src.connect_to(gate.inputs[1])

        gate.outputs[0]

      else
        raise "unsupported expression: #{expr.class}"
      end
    end

    def new_gate(type) #we create a new gate with the type and an instance name
      gate = GateFactory.build(type, "U#{@gate_index}")
      @gate_index += 1
      gate
    end
  end
end