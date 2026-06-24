module Seda

  class VerilogGateExprParser

    Token = Struct.new(:type, :value)
    Gate = Struct.new(:name, :inputs, :output)

    class Lexer
      GateTypes = %w[and2 or2 xor2 nand2 nor2 buf not]
      def tokenizer(src)
        tokens = []
        line = 1
        col = 1
        until src.empty?
          case src
          when /\A\/\/.*/
          when /


