require_relative '../lib/seda'
require_relative '0_build_circuit'
require_relative '5_full_adder'

def build_full_adder_with_insertion
  fa_with_insertion = build_full_adder

  ha2 = fa_with_insertion.get_component_named('ha2')
  src = ha2.get_port_named('sum')
  dst = fa_with_insertion.get_port_named('sum')

  ins_gate = Seda::Circuit.new('inv')
  ins_gate << Seda::Input.new('a')
  ins_gate << Seda::Output.new('f')
  ins_gate.instance_name = 'ins_gate'

  fa_with_insertion.insert_gate_between(src, dst, ins_gate)

  fa_with_insertion
end

fa_with_insertion = build_full_adder_with_insertion

generator = Seda::VHDLGenerator.new
generator.generate(fa_with_insertion)