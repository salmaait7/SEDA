module Seda
  class Port
    attr_accessor :name
    attr_accessor :source
    attr_accessor :sinks  # listesd of ports to which I am connected
    attr_accessor :circuit # to which circui I belong

    def initialize name
      @name=name
      @source=nil
      @sinks=[]
    end

    def connect_to sink #on modélise une connexion orientée :a → b
      @sinks << sink
      sink.source=self
    end
  end

  class Input < Port
  end

  class Output < Port
  end


  class Circuit

    attr_accessor :name
    attr_accessor :inputs,:outputs
    attr_accessor :components
    attr_accessor :instance_name

    def initialize name
      @name=name
      @instance_name= instance_name || name
      @inputs=[]
      @outputs=[]
      @components=[]
    end

    def <<(e)
      case e
      when Input
        @inputs << e
        e.circuit=self
      when Output
        @outputs << e
        e.circuit=self
      when Circuit
        @components << e
      end
    end

    def ports
      [@inputs,@outputs].flatten
    end

    def get_port_named name
      ports.find{|port| port.name==name}
    end
  end
end
