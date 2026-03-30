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
    
    def disconnect_from sink
      @sinks.delete(sink)
      
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

    def get_component_named name
      components.find{|comp| comp.instance_name == name || comp.name == name}
    end

    def insert_gate_between(src, dst, gate_def)
      in_port = gate_def.inputs.first
      out_port = gate_def.outputs.first

      unless src.sinks.include?(dst) #verifier s'il est connecté à dst
        raise ArgumentError, "#{src.name} is not connected to #{dst.name}"
      end

      src.disconnect_from(dst)

      self << gate_def unless components.include?(gate_def)

      src.connect_to(in_port)
      out_port.connect_to(dst)

      gate_def
    end
  end
end