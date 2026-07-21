module Seda
  class DotGenerator
    def generate(circuit)
      puts "[+] generating dot for '#{circuit.name}'"

      validate_ports!(circuit)

      code = Code.new
      code << "digraph {"
      code.indent = 2

      code << "rankdir=LR;"
      code << "graph [fontname=\"Ubuntu Sans\"];"
      code << "node [fontname=\"Ubuntu Sans\", fontsize=10];"
      code << "edge [fontname=\"Ubuntu Sans\"];"
      code.newline

      # Inputs
      circuit.inputs.each do |input|
        code << "#{node_id_for(input)} [shape=circle, label=\"#{input.name}\", style=filled, fillcolor=\"#cce5ff\"];"
      end

      code.newline

      # Outputs
      circuit.outputs.each do |output|
        code << "#{node_id_for(output)} [shape=circle, label=\"#{output.name}\", style=filled, fillcolor=\"#ffcccc\"];"
      end

      code.newline

      # Gates / components
      circuit.components.each_with_index do |comp, index|
        node_id = node_id_for(comp)

        inputs = comp.inputs.map do |input|
          "<#{input.name}> #{input.name}"
        end.join("|")

        outputs = comp.outputs.map do |output|
          "<#{output.name}> #{output.name}"
        end.join("|")
        debug_name = "dbg_w#{index}"

        label = "{{#{inputs}}|#{comp.name}\\n#{debug_name}|{#{outputs}}}"

        code << "#{node_id} [shape=record, style=\"rounded,filled\", fillcolor=\"#fff5cc\", label=\"#{label}\"];"
      end

      code.newline

      # Connections
      all_ports = []
      all_ports << circuit.ports
      all_ports << circuit.components.map(&:ports)
      all_ports.flatten!

      all_ports.each do |source|
        source.sinks.each do |sink|
          so = name_for(source, circuit)
          si = name_for(sink, circuit)
          code << "#{so} -> #{si};"
        end
      end

      code.indent = 0
      code << "}"

      dot_name = "#{circuit.name}.dot"
      code.save_as("generated/dot/#{dot_name}")

      puts "[+] code saved as '#{dot_name}'"
    end

    private

    def node_id_for(obj)
      if obj.respond_to?(:instance_name) && obj.instance_name
        obj.instance_name
      else
        "n#{obj.object_id}"
      end
    end

    def name_for(port, circuit)
      raise "DotGenerator error: nil port" if port.nil?

      if port.circuit.nil?
        raise "DotGenerator error: port '#{port.name}' has no owner/circuit"
      end

      if port.circuit == circuit
        node_id_for(port)
      else
        "#{node_id_for(port.circuit)}:#{port.name}"
      end
    end

    def validate_ports!(circuit)
      all_ports = []
      all_ports << circuit.ports
      all_ports << circuit.components.map(&:ports)
      all_ports.flatten!

      all_ports.each do |port|
        if port.circuit.nil?
          raise "Invalid circuit: port '#{port.name}' has no owner/circuit"
        end
      end
    end
  end
end