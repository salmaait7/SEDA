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

      # Déclaration des signaux du testbench.
      ports.each do |port|
        code << "signal #{port.name} : std_logic;"
      end

      code.indent = 0
      code << "begin"
      code.indent = 2

      # Instanciation du circuit.
      code << "dut : entity work.#{circuit.name}"
      code << "port map("
      code.indent = 4

      ports.each_with_index do |port, index|
        line = "#{port.name} => #{port.name}"
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
          code << "#{input.name} <= '#{vector[index]}';"
        end

        code << "wait for #{@step_time};"
        code.newline
      end

      code << "stop;"
      code << "wait;"

      code.indent = 2
      code << "end process;"

      code.indent = 0
      code << "end architecture sim;"

      code
    end

    def internal_outputs(circuit)
      circuit.components.flat_map(&:outputs)
    end

    def debug_signals(circuit)
      internal_outputs(circuit).each_index.map do |index|
        DbgSignal.new("dbg_w#{index}")
      end
    end

    def stimulus_vectors(nb_inputs)
      # Nombre maximal de combinaisons possibles
      max_vectors = 2**nb_inputs
      count = [@nb_vectors, max_vectors].min

      rng = Random.new(@stimulus_seed)

      vectors = []
      seen = {}

      add_vector = lambda do |vector|
        key = vector.join

        return if seen[key]
        return if vectors.size >= count

        vectors << vector
        seen[key] = true
      end

      zero = Array.new(nb_inputs, "0")
      add_vector.call(zero)

   
      # one = Array.new(nb_inputs, "1")
      # add_vector.call(one)

     
      nb_inputs.times do |index|
        vector = Array.new(nb_inputs, "0")
        vector[index] = "1"

        add_vector.call(vector)
      end

      
      while vectors.size < count
        vector = Array.new(nb_inputs) do
          rng.rand(2).to_s
        end

        add_vector.call(vector)
      end

      vectors
    end
  end
end