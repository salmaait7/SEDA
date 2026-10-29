require "fileutils"

module Seda
  class TestbenchGenerator
    # Représente un signal interne exposé par un port de debug
    DbgSignal = Struct.new(:name)

    def initialize(
      step_time: "20 ns",
      nb_vectors: 10,
      debug: true,
      stimulus_seed: 300
    )
      @step_time = step_time
      @nb_vectors = nb_vectors
      @debug = debug
      @stimulus_seed = stimulus_seed
    end

    def generate(circuit)
      puts "[+] Generating testbench for circuit '#{circuit.name}'..."

      code = Code.new
      code << ieee
      code << gen_entity(circuit)
      code.newline
      code << gen_arch(circuit)

      output_dir = "build/vhdl/circuits/tb"
      FileUtils.mkdir_p(output_dir)

      filename = "tb_#{circuit.name}.vhd"
      output_file = File.join(output_dir, filename)

      code.save_as(output_file)

      puts "[+] Testbench saved as '#{output_file}'"

      output_file
    end

    def ieee
      code = Code.new

      code << "library ieee;"
      code << "use ieee.std_logic_1164.all;"
      code << "use ieee.numeric_std.all;"
      code << "library std;"
      code << "use std.env.all;"
      code.newline

      code
    end

    def gen_entity(circuit)
      code = Code.new

      code << "entity tb_#{circuit.name} is"
      code << "end entity tb_#{circuit.name};"

      code
    end

    def gen_arch(circuit)
      code = Code.new

      code << "architecture sim of tb_#{circuit.name} is"
      code.indent = 2

      ports =
        circuit.inputs +
        circuit.outputs +
        (@debug ? debug_signals(circuit) : [])
      code << "signal simulation_done : std_logic:= '0';"
        

      # Déclaration des signaux du testbench
      ports.each do |port|
        code << "signal #{vhdl_identifier(port.name)} : std_logic;"
      end

      code.indent = 0
      code << "begin"
      code.indent = 2

      # Instanciation du circuit.
      code << "dut : entity work.#{circuit.name}"
      code << "port map("
      code.indent = 4

      ports.each_with_index do |port, index|
        identifier = vhdl_identifier(port.name)
        line = "#{identifier} => #{identifier}"
        line += "," unless index == ports.length - 1

        code << line
      end

      code.indent = 2
      code << ");"
      code.newline

      # Processus d'application des stimuli.
      code << "stim_proc : process"
      code << "begin"
      code.indent = 4

      stimulus_vectors(circuit.inputs.size).each do |vector|
        circuit.inputs.each_with_index do |input, index|
          code << "#{vhdl_identifier(input.name)} <= '#{vector[index]}';"
        end

        code << "wait for #{@step_time};"
        code.newline
      end

      code << "simulation_done <= '1';"
      code << "wait for 1 ps;"
      code << "stop;"
      code << "wait;"

      code.indent = 2
      code << "end process;"

      code.indent = 0
      code << "end architecture sim;"

      code
    end

    def vhdl_identifier(name)
      name = name.to_s

      return name unless name.start_with?("\\")

      body = name.delete_prefix("\\")
      body = body.gsub("\\") { "\\\\" }

      "\\" + body + "\\"
    end

    def internal_outputs(circuit)
      circuit.components.flat_map(&:outputs)
    end

    def debug_signals(circuit)
      reserved_names = (
        circuit.inputs + circuit.outputs
      ).map { |port| port.name.downcase }

      wire_index = 0

      internal_outputs(circuit).map do |_port|
        loop do
          candidate = "w#{wire_index}"
          wire_index += 1

          next if reserved_names.include?(candidate.downcase)
          next if reserved_names.include?("dbg_#{candidate}".downcase)

          break DbgSignal.new("dbg_#{candidate}")
        end
      end
    end

    def stimulus_vectors(nb_inputs)

      rng = Random.new(@stimulus_seed)
      state_count = 2**nb_inputs
      vectors = []
      previous = nil

      @nb_vectors.times do |index|
        value =
          if index.zero?
            0
          else
            candidate = rng.rand(state_count - 1)
            candidate >= previous ? candidate + 1 : candidate
          end

        vector = Array.new(nb_inputs) do |bit|
          ((value >> bit) & 1).to_s
        end

        vectors << vector
        previous = value
      end

      warn "[DEBUG] fichier : #{__FILE__}"
      warn "[DEBUG] demandés : #{@nb_vectors}, générés : #{vectors.size}"

      vectors
    end
  end
end