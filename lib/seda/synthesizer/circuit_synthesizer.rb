# lib/seda/synthesizer/circuit_synthesizer.rb
require_relative "../vhd_generation/expression_gate_builder"
module Seda
  class GateCircuitSynthesizer
    def build_from_netlist(netlist, circuit_name: nil)
      if netlist.respond_to?(:assignments) &&
        !Array(netlist.assignments).empty?
       netlist = ExpressionGateBuilder.convert(netlist)
      end

      @circuit = Circuit.new(circuit_name || netlist.name)
      @ports = {}

      create_circuit_inputs(netlist)
      create_circuit_constants(netlist)
      prepare_connections(netlist)
      

      # resolve_connections
      create_circuit_gates(netlist)

      unless @pending_connections.empty?
        raise "Unresolved connections: #{@pending_connections.keys.join(', ')}"
      end

      create_circuit_outputs(netlist)

      @circuit
    end

    private
    
    def create_circuit_constants(netlist)
      Array(netlist.constants).each do |constant|
        name = constant.fetch(:target)

        if @ports.key?(name)
          raise "Plusieurs pilotes pour le signal #{name}"
        end

        port = ConstantPort.new(name, constant.fetch(:value))
        port.circuit = @circuit

        @ports[name] = port
      end
    end


    def prepare_connections(netlist)
      @pending_connections =
        if netlist.respond_to?(:connections)
          Array(netlist.connections).map(&:dup)
        else
          []
        end

      driven_names =
        netlist.inputs +
        netlist.gates.map(&:output) +
        Array(netlist.constants).map{|constant| constant.fetch(:target)}
        @pending_connections.map do |connection|
          connection.fetch(:target)
        end

      duplicate = driven_names
        .group_by { |name| name }
        .find { |_name, occurrences| occurrences.size > 1 }

      if duplicate
        raise "Plusieurs pilotes pour le signal #{duplicate.first}"
      end
    end

    def resolve_connections
      loop do
        ready, blocked = @pending_connections.partition do |connection|
          @ports.key?(connection.fetch(:source))
        end

        break if ready.empty?

        ready.each do |connection|
          target = connection.fetch(:target)
          source = connection.fetch(:source)

          @ports[target] = @ports.fetch(source)
        end

        @pending_connections = blocked
      end
    end
   

    def create_circuit_inputs(netlist)
      netlist.inputs.each do |name|
        if @ports.key?(name)
          raise "Duplicated circuit input #{name}"
        end

        input = Input.new(name)

        @circuit << input
        @ports[name] = input
      end
    end

    def create_circuit_gates(netlist)
      # Les instances Verilog ne sont pas nécessairement
      # déclarées dans l'ordre topologique.
      pending_gates = netlist.gates.dup

      until pending_gates.empty?
        ready_gates, blocked_gates =
          pending_gates.partition do |gate|
            gate_ready?(gate)
          end

        if ready_gates.empty?
          raise_unresolved_dependencies(blocked_gates)
        end

        ready_gates.each do |gate|
          if @ports.key?(gate.output)
            raise(
              "Multiple drivers for net #{gate.output} " \
              "(gate #{gate.name})"
            )
          end

          output_port = synth_gate(gate)
          @ports[gate.output] = output_port
        end

        resolve_connections

        pending_gates = blocked_gates
      end
    end

    def gate_ready?(gate)
      gate.inputs.all? do |input_name|
        @ports.key?(input_name)
      end
    end

    def raise_unresolved_dependencies(blocked_gates)
      details = blocked_gates.first(10).map do |gate|
        missing_inputs = gate.inputs.reject do |input_name|
          @ports.key?(input_name)
        end

        "#{gate.name} (#{gate.type}): " \
          "missing #{missing_inputs.join(', ')}"
      end

      remaining = blocked_gates.size - details.size

      message =
        "Unable to resolve gate dependencies:\n" \
        "#{details.join("\n")}"

      if remaining.positive?
        message += "\n... and #{remaining} other blocked gates"
      end

      raise message
    end

    def create_circuit_outputs(netlist)
      netlist.outputs.each do |name|
        driver = @ports[name]

        unless driver
          raise "No driver for output #{name}"
        end

        output = Output.new(name)
        @circuit << output

        driver.connect_to(output)
      end
    end

    def synth_gate(gate)
      inputs = gate.inputs.map do |name|
        @ports[name] ||
          raise("No driver for net #{name}")
      end

      # Exemple :
      # "and9"  devient "and"
      # "nand4" devient "nand"
      type =
        gate.type
            .to_s
            .downcase
            .gsub(/\d+$/, "")

      case type
      when "and", "or", "xor"
        synth_multi(
          type,
          gate.name,
          inputs
        )

      when "nand"
        synth_nand(
          gate.name,
          inputs
        )

      when "nor"
        synth_nor(
          gate.name,
          inputs
        )

      when "not", "inv"
        synth_unary(
          Gtech::Not.new,
          gate.name,
          inputs[0]
        )

      when "buf"
        synth_unary(
          Gtech::Buf.new,
          gate.name,
          inputs[0]
        )

      else
        raise(
          "Unsupported gate #{gate.type} " \
          "(instance #{gate.name})"
        )
      end
    end

    def synth_nand(name, inputs)
      if inputs.size == 2
        synth_binary(
          Gtech::Nand2.new,
          name,
          inputs[0],
          inputs[1]
        )
      else
        and_output = synth_multi(
          "and",
          "#{name}_and",
          inputs
        )

        synth_unary(
          Gtech::Not.new,
          "#{name}_not",
          and_output
        )
      end
    end

    def synth_nor(name, inputs)
      if inputs.size == 2
        synth_binary(
          Gtech::Nor2.new,
          name,
          inputs[0],
          inputs[1]
        )
      else
        or_output = synth_multi(
          "or",
          "#{name}_or",
          inputs
        )

        synth_unary(
          Gtech::Not.new,
          "#{name}_not",
          or_output
        )
      end
    end

    def synth_binary(gate, name, input_a, input_b)
      unless input_a && input_b
        raise "Missing input for gate #{name}"
      end

      if gate.respond_to?(:instance_name=)
        gate.instance_name = name
      end

      @circuit << gate

      input_a.connect_to(
        gate.get_port_named("e1")
      )

      input_b.connect_to(
        gate.get_port_named("e2")
      )

      gate.get_port_named("f")
    end

    def synth_unary(gate, name, input)
      unless input
        raise "Missing input for gate #{name}"
      end

      if gate.respond_to?(:instance_name=)
        gate.instance_name = name
      end

      @circuit << gate

      input.connect_to(
        gate.get_port_named("e")
      )

      gate.get_port_named("f")
    end

    # Décompose une porte multi-entrée en arbre
    # de portes à deux entrées.
    def synth_multi(type, name, inputs)
      if inputs.empty?
        raise "No inputs for gate #{name}"
      end

      return inputs.first if inputs.size == 1

      current_level = inputs
      level = 0

      while current_level.size > 1
        next_level = []

        current_level
          .each_slice(2)
          .with_index do |pair, index|
            if pair.size == 1
              next_level << pair.first
              next
            end

            gate = create_gate(type)

            output = synth_binary(
              gate,
              "#{name}_L#{level}_#{index}",
              pair[0],
              pair[1]
            )

            next_level << output
          end

        current_level = next_level
        level += 1
      end

      current_level.first
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
        raise(
          "Unsupported multi-input gate #{type}"
        )
      end
    end
  end
end