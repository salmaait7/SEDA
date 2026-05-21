#logical expressions representation
module Seda
  module Expr
    class Var # our variables (a, b, c...)
      attr_reader :name

      def initialize(name)
        @name = name
      end

      def to_s
        name.to_s
      end
    end
#our gates 
    class Unary 
      attr_reader :op, :expr

      def initialize(op, expr)
        @op = op
        @expr = expr
      end

      def to_s
        "(#{op} #{expr})"
      end
    end

    class Binary 
      attr_reader :op, :lhs, :rhs

      def initialize(op, lhs, rhs)
        @op = op
        @lhs = lhs
        @rhs = rhs
      end

      def to_s
        "(#{lhs} #{op} #{rhs})"
      end
    end

    class Not < Unary
      def initialize(expr)
        super(:not, expr)
      end
    end

    class Buffer < Unary
      def initialize(expr)
        super(:buff, expr)
      end
    end

    class And < Binary
      def initialize(lhs, rhs)
        super(:and, lhs, rhs)
      end
    end

    class Or < Binary
      def initialize(lhs, rhs)
        super(:or, lhs, rhs)
      end
    end

    class Xor < Binary
      def initialize(lhs, rhs)
        super(:xor, lhs, rhs)
      end
    end

    class Nand < Binary
      def initialize(lhs, rhs)
        super(:nand, lhs, rhs)
      end
    end

    class Nor < Binary
      def initialize(lhs, rhs)
        super(:nor, lhs, rhs)
      end
    end
  end
end