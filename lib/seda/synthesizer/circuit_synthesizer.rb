# lib/seda/vhd_generation/gate_circuit_synthesizer.rb

module Seda
  class GateCircuitSynthesizer
    def build_from_netlist(netlist, circuit_name: nil)
      @circuit = Circuit.new(circuit_name || netlist.name)
      @ports = {}

      # Create circuit inputs
      netlist.inputs.each do |name|
        input = Input.new(name)
        @circuit << input
        @ports[name] = input
      end

      # Create gates
      netlist.gates.each do |gate|
        out_port = synth_gate(gate)
        @ports[gate.output] = out_port
      end

      # Create circuit outputs
      netlist.outputs.each do |name|
        driver = @ports[name]

        raise "No driver for output #{name}" unless driver

        output = Output.new(name)
        @circuit << output

        driver.connect_to(output)
      end

      @circuit
    end

    private

    def synth_gate(gate)
      inputs = gate.inputs.map do |name|
        @ports[name] || raise("No driver for net #{name}")
      end

      # Example: "and9" -> "and", "nand4" -> "nand"
      type = gate.type.to_s.downcase.gsub(/\d+$/, "")

      case type
      when "and", "or", "xor"
        synth_multi(type, gate.name, inputs)

      when "nand"
        if inputs.size == 2
          synth_binary(Gtech::Nand2.new, gate.name, inputs[0], inputs[1])
        else
          and_out = synth_multi("and", "#{gate.name}_and", inputs)
          synth_unary(Gtech::Not.new, "#{gate.name}_not", and_out)
        end

      when "nor"
        if inputs.size == 2
          synth_binary(Gtech::Nor2.new, gate.name, inputs[0], inputs[1])
        else
          or_out = synth_multi("or", "#{gate.name}_or", inputs)
          synth_unary(Gtech::Not.new, "#{gate.name}_not", or_out)
        end

      when "not", "inv"
        synth_unary(Gtech::Not.new, gate.name, inputs[0])

      when "buf"
        synth_unary(Gtech::Buf.new, gate.name, inputs[0])

      else
        raise "Unsupported gate #{gate.type}"
      end
    end

    def synth_binary(gate, name, a, b)
      raise "Missing input for gate #{name}" unless a && b

      gate.instance_name = name if gate.respond_to?(:instance_name=)
      @circuit << gate

      a.connect_to(gate.get_port_named("e1"))
      b.connect_to(gate.get_port_named("e2"))

      gate.get_port_named("f")
    end

    def synth_unary(gate, name, a)
      raise "Missing input for gate #{name}" unless a

      gate.instance_name = name if gate.respond_to?(:instance_name=)
      @circuit << gate

      a.connect_to(gate.get_port_named("e"))

      gate.get_port_named("f")
    end

    # Decompose multi-input gates into a tree of 2-input gates
    def synth_multi(type, name, inputs)
      raise "No inputs for gate #{name}" if inputs.empty?

      return inputs.first if inputs.size == 1

      level = 0

      while inputs.size > 1
        next_level = []

        inputs.each_slice(2).with_index do |pair, index|
          if pair.size == 1
            next_level << pair.first
          else
            gate = create_gate(type)

            out = synth_binary(
              gate,
              "#{name}_L#{level}_#{index}",
              pair[0],
              pair[1]
            )

            next_level << out
          end
        end

        inputs = next_level
        level += 1
      end

      inputs.first
    end

    def create_gate(type)
      case type
      when "and"
        Gtech::And2.new
      when "or"
        Gtech::Or2.new
      when "xor"
        Gtech::Xor2.new
      else
        raise "Unsupported multi-input gate #{type}"
      end
    end
  end
end