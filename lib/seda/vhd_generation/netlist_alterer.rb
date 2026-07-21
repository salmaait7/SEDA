module Seda
  class NetlistAlterer
    def initialize(netlist)
      @netlist = netlist
    end

    def insert_buffer_on_output(output_name = nil, new_name: nil)
      output_name ||= @netlist.outputs.last
      altered = clone_netlist("#{@netlist.name}_altered")

      driver_gate = altered.gates.find { |g| g.output == output_name }

      unless driver_gate
        raise "No gate drives output '#{output_name}'"
      end

      internal_net = "#{output_name}"

      # old gate now drives an internal wire
      driver_gate.output = internal_net
      altered.wires << internal_net unless altered.wires.include?(internal_net)

      # buffer drives the real output
      altered.gates << GateInst.new(
        "buf",
        "BUF_#{output_name}",
        output_name,
        [internal_net]
      )

      altered
    end

    private

    def clone_netlist(name)
      gates = @netlist.gates.map do |g|
        GateInst.new(
          g.type,
          g.name,
          g.output,
          g.inputs.dup
        )
      end

      NetlistIR.new(
        name,
        @netlist.inputs.dup,
        @netlist.outputs.dup,
        @netlist.wires.dup,
        gates
      )
    end
  end
end