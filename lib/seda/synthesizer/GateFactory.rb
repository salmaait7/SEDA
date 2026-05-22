module Seda
  module Gtech

    class And2 < Gate2
      def initialize
        super("AND2_GATE")
      end
    end

    class Or2 < Gate2
      def initialize
        super("OR2_GATE")
      end
    end

    class Nand2 < Gate2
      def initialize
        super("NAND2_GATE")
      end
    end

    class Nor2 < Gate2
      def initialize
        super("NOR2_GATE")
      end
    end

    class Xor2 < Gate2
      def initialize
        super("XOR2_GATE")
      end
    end

    class Buf < Gate1
      def initialize
        super("BUF_GATE")
      end
    end

    class Not < Gate1
      def initialize
        super("NOT_GATE")
      end
    end

  end
end