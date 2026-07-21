module Seda
  GateInst = Struct.new(:type, :name, :output, :inputs)

  NetlistIR = Struct.new(
    :name,
    :inputs,
    :outputs,
    :wires,
    :gates
  )

  class VerilogGateCircuitParser
    Token = Struct.new(:type, :value, :pos)

    class Lexer
      def tokenize(src)
        tokens = []
        line = 1
        col = 1

        until src.empty?
          case src
          when /\A\/\/.*/
          

          when /\A\/\*.*?\*\//m
            
          when /\A[ \t\r]+/
        

          when /\A\n/
            line += 1
            col = 1

          
          when /\Amodule\b/i
            tokens << Token.new(:module, $&, [line, col])

          when /\Aendmodule\b/i
            tokens << Token.new(:endmodule, $&, [line, col])

          when /\Ainput\b/i
            tokens << Token.new(:input, $&, [line, col])

          when /\Aoutput\b/i
            tokens << Token.new(:output, $&, [line, col])

          when /\Awire\b/i
            tokens << Token.new(:wire, $&, [line, col])

       
          when /\A(?:and|or|xor|nand|nor|not|buf|inv)\d*\b/i
            tokens << Token.new(:gate_type, $&.downcase, [line, col])

          when /\A,/
            tokens << Token.new(:comma, $&, [line, col])

          when /\A;/
            tokens << Token.new(:semicolon, $&, [line, col])

          when /\A\(/
            tokens << Token.new(:lparen, $&, [line, col])

          when /\A\)/
            tokens << Token.new(:rparen, $&, [line, col])

          when /\A[a-zA-Z_][a-zA-Z0-9_$]*/
            tokens << Token.new(:ident, $&, [line, col])

          else
            raise "Lexical error at #{[line, col]} near: #{src[0, 20]}"
          end

          matched = $&

          col += matched.size unless matched == "\n"
          src.delete_prefix!(matched)
        end

        tokens
      end
    end

    class Parser
      def parse_file(file, circuit_name: nil)
        src = File.read(file)
        @tokens = Lexer.new.tokenize(src)

        parse_module(circuit_name: circuit_name)
      end

      private

      def show_next
        @tokens.first
      end

      def accept_it
        @tokens.shift
      end

      def expect(type)
        tok = show_next

        if tok.nil?
          raise "Syntax error: expected #{type}, got end of file"
        end

        if tok.type == type
          accept_it
        else
          raise "Syntax error at #{tok.pos}: expected #{type}, got #{tok.type} '#{tok.value}'"
        end
      end

      def parse_module(circuit_name:)
        expect(:module)

        module_name = expect(:ident).value
        name = circuit_name || module_name

        parse_port_list
        expect(:semicolon)

        inputs = []
        outputs = []
        wires = []
        gates = []

        until show_next.nil? || show_next.type == :endmodule
          case show_next.type
          when :input
            inputs.concat(parse_declaration(:input))

          when :output
            outputs.concat(parse_declaration(:output))

          when :wire
            wires.concat(parse_declaration(:wire))

          when :gate_type
            gates << parse_gate_instance

          else
            tok = show_next
            raise "Syntax error at #{tok.pos}: unexpected token #{tok.type} '#{tok.value}'"
          end
        end

        expect(:endmodule)

        NetlistIR.new(
          name: name,
          inputs: inputs.uniq,
          outputs: outputs.uniq,
          wires: wires.uniq,
          gates: gates
        )
      end

      def parse_port_list
        expect(:lparen)
        parse_ident_list_until(:rparen)
        expect(:rparen)
      end

      def parse_declaration(keyword)
        expect(keyword)

        names = parse_ident_list_until(:semicolon)

        expect(:semicolon)

        names
      end

      def parse_gate_instance
        raw_type = expect(:gate_type).value
        type = normalize_gate_type(raw_type)

        name = expect(:ident).value

        expect(:lparen)

        ports = parse_ident_list_until(:rparen)

        expect(:rparen)
        expect(:semicolon)

        output = ports.first
        inputs = ports[1..] || []

        GateInst.new(
          type: type,
          name: name,
          output: output,
          inputs: inputs
        )
      end

      def parse_ident_list_until(ending)
        list = []

        while show_next && show_next.type != ending
          list << expect(:ident).value

          if show_next&.type == :comma
            accept_it
          elsif show_next&.type != ending
            tok = show_next
            raise "Syntax error at #{tok.pos}: expected comma or #{ending}, got #{tok.type}"
          end
        end

        list
      end

      def normalize_gate_type(type)
        case type.downcase
        when /\Aand\d*\z/
          "and"
        when /\Aor\d*\z/
          "or"
        when /\Axor\d*\z/
          "xor"
        when /\Anand\d*\z/
          "nand"
        when /\Anor\d*\z/
          "nor"
        when "not", "inv"
          "not"
        when "buf"
          "buf"
        else
          raise "Unsupported gate type '#{type}'"
        end
      end
    end

    

    def parse_netlist(file:, circuit_name: nil)
      netlist = Parser.new.parse_file(file, circuit_name: circuit_name)
      print_summary(netlist)
      return netlist


      # GateCircuitSynthesizer.new.build_from_netlist(netlist, circuit_name: circuit_name)

    end

    private

    def print_summary(netlist)
      puts "[+] Verilog file parsed"
      puts "[+] Circuit : #{netlist.name}"
      puts "[+] Inputs  : #{netlist.inputs.join(', ')}"
      puts "[+] Outputs : #{netlist.outputs.join(', ')}"
      puts "[+] Wires   : #{netlist.wires.join(', ')}"
      puts "[+] Gates   : #{netlist.gates.size}"
    end
  end
end