require "csv"
require "fileutils"

module Seda
  class VHDLDelayGenerator
    DELAYS = {
      "And2"  => "1.5 ns",
      "Or2"   => "1.7 ns",
      "Xor2"  => "2.5 ns",
      "Nand2" => "1.0 ns",
      "Nor2"  => "1.2 ns",
      "Not"   => "0.5 ns",
      "Buf"   => "0.6 ns"
    }.freeze

    attr_reader :applied_delays

    def initialize(
      delay_mode: :fixed,
      delays: DELAYS,
      margin: 0.0,
      seed: nil,
      debug: true
    )
      @delays = delays
      @delay_mode = delay_mode
      @margin = margin.to_f
      @debug = debug

      # Random indépendant pour rendre un tirage reproductible.
      @seed = seed || Random.new_seed
      @random = Random.new(@seed)

      @wire_names = {}
      @wire_index = 0

      # Contient les variations réellement appliquées aux portes.
      @applied_delays = []

      # Utilisé uniquement pour le mode inter_die.
      @global_epsilon = nil
    end

    def generate(
      circuit,
      output_dir: "generated/vhdl/circuits",
      filename: nil,
      delay_report_file: nil
    )
      validate_parameters!

      @circuit = circuit
      @wire_names = {}
      @wire_index = 0
      @applied_delays = []
      @global_epsilon = nil

      puts "[+] Generating VHDL circuit '#{circuit.name}'..."
      puts "    delay mode: #{@delay_mode}"
      puts "    margin: ±#{(@margin * 100).round(2)}%"
      puts "    seed: #{@seed}"

      code = Code.new
      code << ieee
      code << gen_entity(circuit)
      code.newline
      code << gen_arch(circuit)

      FileUtils.mkdir_p(output_dir)

      filename ||= "#{circuit.name}.vhd"
      output_file = File.join(output_dir, filename)

      code.save_as(output_file)

      puts "[+] VHDL saved as '#{output_file}'"

      if delay_report_file
        save_delay_report(delay_report_file)
        puts "[+] Delay report saved as '#{delay_report_file}'"
      end

      output_file
    end

    def delay_for(gate, gate_index:)
      gate_name = gate.class.name.split("::").last

      base_delay_string = @delays[gate_name]

      unless base_delay_string
        raise ArgumentError,
              "No nominal delay defined for gate type '#{gate_name}'"
      end

      base_delay = numeric_delay(base_delay_string)
      epsilon = epsilon_for_current_run
      final_delay = base_delay * epsilon

      output_port = gate.get_port_named("f")

      @applied_delays << {
        gate_index: gate_index,
        gate_type: gate_name,
        output_signal: signal_ref(output_port),
        base_delay_ns: base_delay,
        epsilon: epsilon,
        variation_percent: (epsilon - 1.0) * 100.0,
        final_delay_ns: final_delay
      }

      "#{format_delay(final_delay)} ns"
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

      normal_ports =
        circuit.inputs.sort_by { |port| numeric_part(port.name) } +
        circuit.outputs.sort_by { |port| numeric_part(port.name) }

      debug_ports = @debug ? internal_outputs(circuit) : []

      port_lines = []

      normal_ports.each do |port|
        direction = circuit.inputs.include?(port) ? "in" : "out"
        port_lines << "#{port.name} : #{direction} std_logic"
      end

      debug_ports.each do |port|
        port_lines << "dbg_#{wire_name(port)} : out std_logic"
      end

      port_lines.each_with_index do |line, index|
        line += ";" unless index == port_lines.length - 1
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

      circuit.components.each_with_index do |gate, gate_index|
        code << assignment_for_gate(
          gate,
          gate_index: gate_index
        )
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

    def assignment_for_gate(gate, gate_index:)
      delay = delay_for(
        gate,
        gate_index: gate_index
      )

      out = signal_ref(gate.get_port_named("f"))

      case gate
      when Gtech::Buf
        input = signal_ref(gate.get_port_named("e").source)

        "#{out} <= #{input} after #{delay};"

      when Gtech::Not
        input = signal_ref(gate.get_port_named("e").source)

        "#{out} <= not #{input} after #{delay};"

      when Gtech::And2
        input_a = signal_ref(gate.get_port_named("e1").source)
        input_b = signal_ref(gate.get_port_named("e2").source)

        "#{out} <= #{input_a} and #{input_b} after #{delay};"

      when Gtech::Or2
        input_a = signal_ref(gate.get_port_named("e1").source)
        input_b = signal_ref(gate.get_port_named("e2").source)

        "#{out} <= #{input_a} or #{input_b} after #{delay};"

      when Gtech::Xor2
        input_a = signal_ref(gate.get_port_named("e1").source)
        input_b = signal_ref(gate.get_port_named("e2").source)

        "#{out} <= #{input_a} xor #{input_b} after #{delay};"

      when Gtech::Nand2
        input_a = signal_ref(gate.get_port_named("e1").source)
        input_b = signal_ref(gate.get_port_named("e2").source)

        "#{out} <= #{input_a} nand #{input_b} after #{delay};"

      when Gtech::Nor2
        input_a = signal_ref(gate.get_port_named("e1").source)
        input_b = signal_ref(gate.get_port_named("e2").source)

        "#{out} <= #{input_a} nor #{input_b} after #{delay};"

      else
        raise ArgumentError,
              "Unsupported gate type: #{gate.class}"
      end
    end

    def signal_ref(port)
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

    def save_delay_report(file)
      directory = File.dirname(file)
      FileUtils.mkdir_p(directory) unless directory == "."

      CSV.open(file, "w") do |csv|
        csv << [
          "seed",
          "delay_mode",
          "margin",
          "gate_index",
          "gate_type",
          "output_signal",
          "base_delay_ns",
          "epsilon",
          "variation_percent",
          "final_delay_ns"
        ]

        @applied_delays.each do |delay|
          csv << [
            @seed,
            @delay_mode,
            @margin,
            delay[:gate_index],
            delay[:gate_type],
            delay[:output_signal],
            delay[:base_delay_ns],
            delay[:epsilon],
            delay[:variation_percent],
            delay[:final_delay_ns]
          ]
        end
      end
    end

    private

    def epsilon_for_current_run
      case @delay_mode
      when :fixed
        1.0

      when :inter_die
        # Une seule variation est générée puis appliquée
        # à toutes les portes du circuit.
        @global_epsilon ||= random_epsilon

      when :intra_die
        # Chaque porte reçoit une variation indépendante.
        random_epsilon

      else
        raise ArgumentError,
              "Unknown delay mode: #{@delay_mode}"
      end
    end

    def random_epsilon
      minimum = 1.0 - @margin
      maximum = 1.0 + @margin

      minimum + @random.rand * (maximum - minimum)
    end

    def numeric_delay(delay)
      delay.to_s
           .strip
           .sub(/\s*ns\z/i, "")
           .to_f
    end

    def format_delay(delay)
      # Il vaut mieux garder plusieurs décimales.
      # Avec round(2), de faibles variations peuvent disparaître.
      format("%.6f", delay)
        .sub(/0+\z/, "")
        .sub(/\.\z/, "")
    end

    def numeric_part(name)
      number = name.to_s.gsub(/\D/, "")
      number.empty? ? Float::INFINITY : number.to_i
    end

    def validate_parameters!
      unless %i[fixed inter_die intra_die].include?(@delay_mode)
        raise ArgumentError,
              "Unknown delay mode: #{@delay_mode}"
      end

      unless @margin.between?(0.0, 1.0)
        raise ArgumentError,
              "Margin must be between 0.0 and 1.0"
      end
    end
  end
end