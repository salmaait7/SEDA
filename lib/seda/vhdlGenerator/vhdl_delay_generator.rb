require "csv"
require "digest"
require "fileutils"
require "json"

module Seda
  class VHDLDelayGenerator
    attr_reader :applied_delays

    def initialize(
      delay_file:,
      delay_mode: :fixed,
      margin: 0.0,
      seed: nil,
      debug: true
    )
      @delays = load_delays_from_json(delay_file)
      @delay_mode = delay_mode.to_sym
      @margin = Float(margin)
      @seed = Integer(seed || Random.new_seed)
      @debug = debug

      @wire_names = {}
      @wire_index = 0
      @applied_delays = []
      @global_epsilon = nil
      @used_gate_identifiers = {}
    end

    def generate(
      circuit,
      output_dir: "build/vhdl/circuits",
      filename: nil,
      delay_report_file: nil
    )
      validate_parameters!

      @circuit = circuit
      @wire_names = {}
      @wire_index = 0
      @applied_delays = []
      @global_epsilon = nil
      @used_gate_identifiers = {}

      puts "[+] Generating VHDL circuit '#{circuit.name}'..."
      puts "    delay mode: #{@delay_mode}"
      puts "    margin: +/-#{(@margin * 100).round(2)}%"
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
      gate_type = gate.class.name.split("::").last
      gate_identifier = stable_gate_identifier(gate, gate_index)
      gate_delays = @delays[gate_type]

      unless gate_delays
        raise ArgumentError,
              "No nominal delay defined for gate type '#{gate_type}'"
      end

      register_gate_identifier!(gate_identifier, gate_index)

      base_rise = gate_delays.fetch(:rise)
      base_fall = gate_delays.fetch(:fall)
      epsilon = epsilon_for_current_run(gate_identifier)

      # une instance conserve le meme epsilon pour ses deux fronts
      final_rise = base_rise * epsilon
      final_fall = base_fall * epsilon

      output_port = gate.get_port_named("f")

      @applied_delays << {
        gate_index: gate_index,
        instance_name: gate_identifier,
        gate_type: gate_type,
        output_signal: signal_ref(output_port),
        base_rise_ns: base_rise,
        base_fall_ns: base_fall,
        epsilon: epsilon,
        variation_percent: (epsilon - 1.0) * 100.0,
        final_rise_ns: final_rise,
        final_fall_ns: final_fall
      }

      {
        rise: final_rise,
        fall: final_fall
      }
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
        circuit.inputs.sort_by { |port| sort_key(port.name) } +
        circuit.outputs.sort_by { |port| sort_key(port.name) }

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

      rise_delay = delay.fetch(:rise)
      fall_delay = delay.fetch(:fall)
      out = signal_ref(gate.get_port_named("f"))

      expression =
        case gate
        when Gtech::Buf
          signal_ref(gate.get_port_named("e").source)

        when Gtech::Not
          input = signal_ref(gate.get_port_named("e").source)
          "not #{input}"

        when Gtech::And2
          input_a = signal_ref(gate.get_port_named("e1").source)
          input_b = signal_ref(gate.get_port_named("e2").source)
          "#{input_a} and #{input_b}"

        when Gtech::Or2
          input_a = signal_ref(gate.get_port_named("e1").source)
          input_b = signal_ref(gate.get_port_named("e2").source)
          "#{input_a} or #{input_b}"

        when Gtech::Xor2
          input_a = signal_ref(gate.get_port_named("e1").source)
          input_b = signal_ref(gate.get_port_named("e2").source)
          "#{input_a} xor #{input_b}"

        when Gtech::Nand2
          input_a = signal_ref(gate.get_port_named("e1").source)
          input_b = signal_ref(gate.get_port_named("e2").source)
          "#{input_a} nand #{input_b}"

        when Gtech::Nor2
          input_a = signal_ref(gate.get_port_named("e1").source)
          input_b = signal_ref(gate.get_port_named("e2").source)
          "#{input_a} nor #{input_b}"

        else
          raise ArgumentError,
                "Unsupported gate type: #{gate.class}"
        end

      generate_delayed_assignment(
        out,
        expression,
        rise_delay,
        fall_delay
      )
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
          "instance_name",
          "gate_type",
          "output_signal",
          "base_rise_ns",
          "base_fall_ns",
          "epsilon",
          "variation_percent",
          "final_rise_ns",
          "final_fall_ns"
        ]

        @applied_delays.each do |delay|
          csv << [
            @seed,
            @delay_mode,
            @margin,
            delay.fetch(:gate_index),
            delay.fetch(:instance_name),
            delay.fetch(:gate_type),
            delay.fetch(:output_signal),
            delay.fetch(:base_rise_ns),
            delay.fetch(:base_fall_ns),
            delay.fetch(:epsilon),
            delay.fetch(:variation_percent),
            delay.fetch(:final_rise_ns),
            delay.fetch(:final_fall_ns)
          ]
        end
      end
    end

    private

    def load_delays_from_json(file)
      data = JSON.parse(File.read(file))

      data.each_with_object({}) do |(gate_name, values), delays|
        rise = values["rise"]
        fall = values["fall"]

        if rise.nil? || fall.nil?
          raise ArgumentError,
                "Rise or fall delay missing for gate '#{gate_name}'"
        end

        rise = Float(rise)
        fall = Float(fall)

        # if rise.negative? || fall.negative?
        #   raise ArgumentError,
        #         "Negative delay for gate '#{gate_name}'"
        # end

        delays[gate_name] = {
          rise: rise,
          fall: fall
        }
      end
    end

    def generate_delayed_assignment(
      out,
      expression,
      rise_delay,
      fall_delay
    )
      rise = format_delay(rise_delay)
      fall = format_delay(fall_delay)

      "#{out} <= (#{expression}) after #{rise} ns " \
        "when (#{expression}) = '1' else " \
        "(#{expression}) after #{fall} ns;"
    end

    def epsilon_for_current_run(instance_name)
      case @delay_mode
      when :fixed
        1.0

      when :inter_die
        @global_epsilon ||= deterministic_epsilon("__global__")

      when :intra_die
        deterministic_epsilon(instance_name)

      else
        raise ArgumentError,
              "Unknown delay mode: #{@delay_mode}"
      end
    end

    def deterministic_epsilon(instance_name)
      key = "#{@seed}:#{instance_name}"
      digest = Digest::SHA256.hexdigest(key)
      local_seed = digest[0, 16].to_i(16)
      local_random = Random.new(local_seed)

      minimum = 1.0 - @margin
      maximum = 1.0 + @margin

      minimum + local_random.rand * (maximum - minimum)
    end

    def stable_gate_identifier(gate, gate_index)
      if gate.respond_to?(:instance_name)
        instance_name = gate.instance_name.to_s.strip
        return instance_name unless instance_name.empty?
      end

      "#{gate.class.name}:#{gate_index}"
    end

    def register_gate_identifier!(gate_identifier, gate_index)
      previous_index = @used_gate_identifiers[gate_identifier]

      # unless previous_index.nil?
      #   raise ArgumentError,
      #         "duplicate gate instance name '#{gate_identifier}' " \
      #         "for gate indexes #{previous_index} and #{gate_index}"
      # end

      @used_gate_identifiers[gate_identifier] = gate_index
    end

    def format_delay(delay)
      format("%.6f", delay)
        .sub(/0+\z/, "")
        .sub(/\.\z/, "")
    end

    def numeric_part(name)
      number = name.to_s.gsub(/\D/, "")
      number.empty? ? Float::INFINITY : number.to_i
    end

    def sort_key(name)
      [numeric_part(name), name.to_s]
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