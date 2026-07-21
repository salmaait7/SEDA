module Seda
  class TestbenchGenerator
    DbgSignal = Struct.new(:name) #class pour représenter les signaux de debug

    def initialize(step_time: "20 ns", nb_vectors: 10, debug: true)
      @step_time = step_time
      @nb_vectors = nb_vectors
      @debug = debug
    end

    def generate(circuit)
      puts "[+] Generating testbench for circuit '#{circuit.name}'..."

      code = Code.new
      code << ieee
      code << gen_entity(circuit)
      code.newline
      code << gen_arch(circuit)

      filename = "tb_#{circuit.name}.vhd"
      code.save_as("generated/vhdl/tb/#{filename}")

      puts "[+] Testbench saved as '#{filename}'"
    end

    def ieee
      code = Code.new
      code << "library ieee;"
      code << "use ieee.std_logic_1164.all;"
      code << "use ieee.numeric_std.all;"
      code << "library std;"
      code << "use std.textio.all;"
      code.newline
      code
    end

    def gen_entity(circuit)
      code = Code.new
      code << "entity tb_#{circuit.name} is"
      code.indent = 2
      code << "generic ("
      code << "    Result_file : string := \"activity.csv\""
      code << ");"
      code.indent = 0
      code << "end entity tb_#{circuit.name};"
      code
    end

    def gen_arch(circuit)
      code = Code.new

      code << "architecture sim of tb_#{circuit.name} is"
      code.indent = 2
      ports = circuit.inputs + circuit.outputs + (@debug ? debug_signals(circuit) : [])
      ports.each do |port|
         code << "signal #{port.name} : std_logic;"
       end
      code.newline
      code << "file activity_file : text open write_mode is Result_file;"

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
      
      code.newline
      code << "monitor_proc : process(#{ports.map(&:name).join(', ')})"
      code.indent = 2
      code << "variable L : line;"
      code << "variable header_written : boolean := false;"
      code.indent = 0
      code << "begin"
      code.indent = 2

# Write CSV header only once
      code << "if not header_written then"
      code.indent = 4
      code << "write(L, string'(\"time\"));"

      ports.each do |port|
        code << "write(L, string'(\",#{port.name}\"));"
      end

      code << "writeline(activity_file, L);"
      code << "header_written := true;"
      code.indent = 2
      code << "end if;"
      code.newline

# Write activity values
      code << "write(L, now);"

      ports.each do |port|
       code << "write(L, string'(\",\"));"
       code << "write(L, std_logic'image(#{port.name}));"
      end

     code << "writeline(activity_file, L);"

     code.indent = 0
     code << "end process;"

      code.indent = 0
      code << "end architecture sim;"


      code

    end

    def internal_outputs(circuit)
     circuit.components.flat_map(&:outputs)
    end
    def debug_signals(circuit)
      internal_outputs(circuit).each_with_index.map do |port, index|
        DbgSignal.new("dbg_w#{index}")
      end
    end

    def stimulus_vectors(nb_inputs)
      max_vectors = 2 ** nb_inputs #nombre de combinaisons possibles pour nb_inputs bits
      count = [@nb_vectors, max_vectors].min #limiter le nombre de vecteurs générés à nb_vectors ou au maximum possible

      rng = Random.new(42)
      vectors = []
      seen = {}
      add_vector = lambda do |vec|
        key = vec.join
        return if seen[key]
        return if vectors.size >= count
        vectors << vec
        seen[key] = true
      end

      zero = Array.new(nb_inputs, "0")
      add_vector.call(zero)
      one = Array.new(nb_inputs, "1")
      add_vector.call(one)


      nb_inputs.times do |i| #forcer chaque bit à 1 une fois
        vec = Array.new(nb_inputs, "0")
        vec[i] = "1"
        add_vector.call(vec)
      end

     while vectors.size < count
        vec = Array.new(nb_inputs) { rng.rand(2).to_s }
        add_vector.call(vec)
      end
      
      vectors
      # for i in 0...vectors.size
      #   puts "Vector #{i}: #{vectors[i].join}"
      # end
    end
  end

end