module Seda
  class VHDLGenerator
    def generate circuit
      puts "[+] generating VHDL for '#{circuit.name}'"
      code=Code.new
      code << ieee
      code << gen_entity(circuit)
      code.newline
      code << gen_arch(circuit)
      code.save_as vhdl_name="#{circuit.name}.vhd"
      puts "[+] code saved as '#{vhdl_name}'"
    end

    def ieee
      code=Code.new
      code << "library ieee;"
      code << "use ieee.std_logic_1164.all;"
      code << "use ieee.numeric_std.all;"
      code.newline
      code
    end

    def gen_entity circuit
      code=Code.new
      code << "entity #{circuit.name} is"
      code.indent=2
      code << "port("
      code.indent=4
      circuit.inputs.each do |input|
         code << "#{input.name} : in  std_logic;"
      end
      circuit.outputs.each do |output|
         code << "#{output.name} : out std_logic;"
      end
      code.indent=2
      code << ");"
      code.indent=0
      code << "end entity #{circuit.name};"
      code
    end

    def gen_arch circuit
      code=Code.new
      signals=get_signals(circuit)
      code << "architecture netlist of #{circuit.name} is "
      code.indent=2
      signals.each do |sig|
        code << "signal w_#{sig.object_id} : std_logic;"
      end
      code.indent=0
      code << "begin"
      code.indent=2

      circuit.inputs.each do |sig|
        code << "w_#{sig.object_id} <= #{sig.name};"
      end

      code.newline

      circuit.components.each do |comp|
        code << "#{comp.name}_i : entity work.#{comp.name}"
        code << "port map("
        code.indent=4
        comp.inputs.each do |input|
          code << "#{input.name} => w_#{input.source.object_id},"
        end
        comp.outputs.each do |output|
          code << "#{output.name} => w_#{output.object_id},"
        end
        code.indent=2
        code << ");"
      end

      code.newline

      circuit.outputs.each do |sig|
        code << "#{sig.name} <= w_#{sig.source.object_id};"
      end
      code.indent=0
      code << "end architecture netlist;"
      code.newline
      code
    end

    def get_signals circuit
      signals=[]
      signals << circuit.inputs
      signals << circuit.components.collect{|comp| comp.outputs}
      signals.flatten!
    end
  end
end
