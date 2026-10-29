module Seda
  class ExpressionGateBuilder
    attr_reader :gates, :wires, :connections, :constants

    def initialize(used_names: [])
      @used_names = used_names.each_with_object({}) do |name, names|
        names[name.downcase] = true
      end

      @gates = []
      @wires = []
      @connections = []
      @constants = []
      @counter = 0
    end

    def build(expression, output:)
      if expression.fetch(:op) == :signal
        @connections << {
          target: output,
          source: expression.fetch(:name)
        }
      else
        emit_expression(expression, output: output)
      end

      self
    end

    def self.convert(netlist)
      used_names =
        netlist.inputs +
        netlist.outputs +
        netlist.wires +
        netlist.gates.map(&:name) +
        netlist.gates.map(&:output) +
        netlist.gates.flat_map(&:inputs)

      builder = new(used_names: used_names)

      Array(netlist.assignments).each do |assignment|
        builder.build(
          assignment.fetch(:expression),
          output: assignment.fetch(:target)
        )
      end

      converted = netlist.dup

      converted.wires = (netlist.wires + builder.wires).uniq
      converted.gates = netlist.gates + builder.gates
      converted.connections =
        Array(netlist.connections) + builder.connections
      converted.constants = 
        Array(netlist.constants) + builder.constants
      converted.assignments = []

      converted
    end

    private

    def fresh_name(prefix)
      loop do
        @counter += 1
        name = "#{prefix}_#{@counter}"
        key = name.downcase

        next if @used_names[key]

        @used_names[key] = true
        return name
      end
    end

    def emit_expression(expression, output: nil)
      op = expression.fetch(:op)

      return expression.fetch(:name) if op == :signal
      if op == :constant
        value = expression.fetch(:value).to_s

        unless ["0", "1"].include?(value)
          raise "Constante non prise en charge : #{value.inspect}"
        end

        unless output
          output = fresh_name("expr_constant")
          @wires << output
        end

        @constants << {
          target: output,
          value: value
        }

        return output
      end    



      operands =
        case op
        when :not
          [expression.fetch(:operand)]
        when :and, :or, :xor
          [
            expression.fetch(:left),
            expression.fetch(:right)
          ]
        else
          raise "Opérateur non pris en charge : #{op}"
        end

      inputs = operands.map do |operand|
        emit_expression(operand)
      end

      unless output
        output = fresh_name("expr_wire")
        @wires << output
      end

      gate = GateInst.new
      gate.type = op.to_s
      gate.name = fresh_name("expr_gate")
      gate.output = output
      gate.inputs = inputs

      @gates << gate

      output
    end
  end
end