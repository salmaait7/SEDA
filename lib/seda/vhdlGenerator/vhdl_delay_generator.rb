module Seda
  class VHDLDelayGenerator
    DELAYS = {
      "And2"  => "4 ns",
      "Or2"   => "4 ns",
      "Xor2"  => "3 ns",
      "Nand2" => "2 ns",
      "Nor2"  => "2 ns",
      "Not"   => "1 ns",
      "Buf"   => "1 ns"
    }

    def initialize(delay_mode: :intra_die, delays: DELAYS, debug: true)
      @delays = delays
      @wire_names = {}
      @debug = debug
      @wire_index = 0
      @delay_mode = delay_mode
    end

    def delay_for(gate)
      gate_name = gate.class.name.split("::").last # remove the module prefix gtech:: to get the gate name
      base_delay = @delays[gate_name]
      case @delay_mode
      when :fixed
        base_delay
      when :inter_die
        # add a random variation of +/- 20% to the base delay for all gates
        @fixed_epsilon ||= 1.2
        final_delay = base_delay.to_f * @fixed_epsilon
        "#{final_delay.round(2)} ns"

      when :intra_die
        # add a random variation of +/- 20% to the base delay for each gate independently
        epsilon = rand(0.8..1.2)
        final_delay = base_delay.to_f * epsilon
        "#{final_delay.round(2)} ns"

      else
        raise ArgumentError, "Unknown delay mode: #{@delay_mode}"
      end
    end

    def generate(circuit)
      @circuit = circuit
      @wire_names = {}
      @wire_index = 0

      puts "[+] Generating VHDL circuit '#{circuit.name}'..."

      code = Code.new
      code << ieee
      code << gen_entity(circuit)
      code.newline
      code << gen_arch(circuit)

      filename = "#{circuit.name}.vhd"
      code.save_as(filename)

      puts "[+] VHDL saved as '#{filename}'"
    end

    def ieee
      code = Code.new
      code << "library ieee;"
      code << "use ieee.std_logic_1164.all;"
      code << "use ieee.numeric_std.all;"
      code.newline
      code
    end

    def gen_entity(circuit)
      code = Code.new

      code << "entity #{circuit.name} is"
      code.indent = 2
      code << "port("
      code.indent = 4

      normal_ports = circuit.inputs + circuit.outputs
      debug_ports = @debug ? internal_outputs(circuit) : []

      ports_lines = []

      normal_ports.each do |port|
        direction = circuit.inputs.include?(port) ? "in " : "out" 
        ports_lines << "#{port.name} : #{direction} std_logic"
      end

      debug_ports.each do |port|
       ports_lines << "dbg_#{wire_name(port)} : out std_logic"
      end
      ports_lines.each_with_index do |line, index|
        line += ";" unless index == ports_lines.size - 1
        code << line
      end


      code.indent = 2
      code << ");"
      code.indent = 0
      code << "end entity #{circuit.name};"

      code
    end

    def gen_arch(circuit)
      code = Code.new

      code << "architecture Behavioral of #{circuit.name} is"
      code.indent = 2

      internal_outputs(circuit).each do |port|
        code << "signal #{wire_name(port)} : std_logic;"
      end

      code.indent = 0
      code << "begin"
      code.indent = 2

      circuit.components.each do |gate|
        code << assignment_for_gate(gate)
      end

      code.newline

      circuit.outputs.each do |output|
        code << "#{output.name} <= #{signal_ref(output.source)};"
      end

      if @debug
        code.newline
        code << "-- Debug signals for internal wires"
        internal_outputs(circuit).each do |port|
            code << "dbg_#{wire_name(port)} <= #{wire_name(port)};"
        end
      end

      code.indent = 0
      code << "end architecture Behavioral;"

      code
    end

    def internal_outputs(circuit)
      circuit.components.flat_map(&:outputs)
    end

    def assignment_for_gate(gate)
      delay = delay_for(gate)
      out = signal_ref(gate.get_port_named("f")) # output port is always named "f" in our gate models

      case gate
      when Gtech::Buf
        a = signal_ref(gate.get_port_named("e").source)
        "#{out} <= #{a} after #{delay};"

      when Gtech::Not
        a = signal_ref(gate.get_port_named("e").source)
        "#{out} <= not #{a} after #{delay};"

      when Gtech::And2
        a = signal_ref(gate.get_port_named("e1").source)
        b = signal_ref(gate.get_port_named("e2").source)
        "#{out} <= #{a} and #{b} after #{delay};"

      when Gtech::Or2
        a = signal_ref(gate.get_port_named("e1").source)
        b = signal_ref(gate.get_port_named("e2").source)
        "#{out} <= #{a} or #{b} after #{delay};"

      when Gtech::Xor2
        a = signal_ref(gate.get_port_named("e1").source)
        b = signal_ref(gate.get_port_named("e2").source)
        "#{out} <= #{a} xor #{b} after #{delay};"

      when Gtech::Nand2
        a = signal_ref(gate.get_port_named("e1").source)
        b = signal_ref(gate.get_port_named("e2").source)
        "#{out} <= #{a} nand #{b} after #{delay};"

      when Gtech::Nor2
        a = signal_ref(gate.get_port_named("e1").source)
        b = signal_ref(gate.get_port_named("e2").source)
        "#{out} <= #{a} nor #{b} after #{delay};"

      else
        raise "unsupported gate type: #{gate.class}"
      end
    end

    # def delay_for(gate)
    #   gate_name = gate.class.name.split("::").last # remove the module prefix gtech:: to get the gate name
    #   puts "the gate name is #{gate_name}"
    #   @delays[gate_name]
    # end

    def signal_ref(port) # le signal soit un port d'entrée du circuit, soit une sortie d'une porte interne. Si c'est un port d'entrée, on utilise son nom, sinon on utilise le nom du fil interne qui le connecte à la sortie de la porte
      if @circuit.inputs.include?(port)
        port.name
      else
        wire_name(port)
      end
    end

    def wire_name(port)
      @wire_names[port] ||= begin
        name = "w#{@wire_index}"
        @wire_index += 1
        name
      end
    end
  end
end