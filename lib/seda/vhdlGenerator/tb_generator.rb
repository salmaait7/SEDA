module Seda
  class TestbenchGenerator
    def initialize(step_time: "20 ns", nb_vectors: 10)
      @step_time = step_time
      @nb_vectors = nb_vectors
    end

    def generate(circuit)
      puts "[+] Generating testbench for circuit '#{circuit.name}'..."

      code = Code.new
      code << ieee
      code << gen_entity(circuit)
      code.newline
      code << gen_arch(circuit)

      filename = "tb_#{circuit.name}.vhd"
      code.save_as(filename)

      puts "[+] Testbench saved as '#{filename}'"
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
      code << "entity tb_#{circuit.name} is"
      code << "end entity tb_#{circuit.name};"
      code
    end

    def gen_arch(circuit)
      code = Code.new

      code << "architecture sim of tb_#{circuit.name} is"
      code.indent = 2
      ports = circuit.inputs + circuit.outputs
      ports.each do |port|
         code << "signal #{port.name} : std_logic;"
       end

      code.indent = 0
      code << "begin"
      code.indent = 2

      code << "dut : entity work.#{circuit.name}"
      code << "port map("
      code.indent = 4

    #   ports = circuit.inputs + circuit.outputs

      ports.each_with_index do |port, i|
        line = "#{port.name} => #{port.name}"
        line << "," unless i == ports.length - 1
        code << line
      end

      code.indent = 2
      code << ");"
      code.newline

      code << "stim_proc : process"
      code << "begin"
      code.indent = 4

      stimulus_vectors(circuit.inputs.size).each do |vector|
        circuit.inputs.each_with_index do |input, i|
          code << "#{input.name} <= '#{vector[i]}';"
        end
        code << "wait for #{@step_time};"
        code.newline
      end

      code << "wait;"
      code.indent = 2
      code << "end process;"

      code.indent = 0
      code << "end architecture sim;"

      code
    end

    def stimulus_vectors(nb_inputs)
      max_vectors = 2 ** nb_inputs
      count = [@nb_vectors, max_vectors].min

      vectors = []

      count.times do |i|
        binary = i.to_s(2).rjust(nb_inputs, "0")
        vectors << binary.chars
      end

      vectors
    end
  end
end