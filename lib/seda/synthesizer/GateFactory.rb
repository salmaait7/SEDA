module Seda
  class GateFactory
    GATE_NAMES = { #so that we don't call the gates "and", "or", etc. that reseved on vhdl
      buffer: "BUF",
      not:    "NOT",
      and:    "AND2",
      or:     "OR2",
      xor:    "XOR2",
      nand:   "NAND2",
      nor:    "NOR2"
    }

    def self.build(type, instance_name)
      gate_name = GATE_NAMES.fetch(type)

      gate = Circuit.new(gate_name, instance_name)

      case type
      when :buffer, :not
        gate << Input.new("a")
        gate << Output.new("y")

      when :and, :or, :xor, :nand, :nor
        gate << Input.new("a")
        gate << Input.new("b")
        gate << Output.new("y")

      else
        raise "Unsupported gate type: #{type}"
      end

      gate
    end
  end
end