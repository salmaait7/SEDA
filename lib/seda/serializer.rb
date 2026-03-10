module Seda
  class Serializer

    def initialize
      @symtable={}
    end

    def write circuit
      code=serialize(circuit)
      code.save_as sxp_filename="#{circuit.name}.sxp"
      puts "[+] circuit '#{circuit.name}' saved as '#{sxp_filename}'"
    end

    def read filename
      @toks=tokenize(filename)
      parse_circuit()
    end

    private
    def serialize circuit,kind="circuit"
      code=Code.new
      code << "(#{kind} #{circuit.name}"
      code.indent=2
      circuit.inputs.each do |input|
        code << "(input #{input.name})"
      end
      circuit.outputs.each do |output|
        code << "(output #{output.name})"
      end
      circuit.components.each do |component|
        code << serialize(component,"component")
      end
      sources=circuit.inputs + circuit.components.collect{|comp| comp.outputs}
      sources.flatten!
      sources.each do |source|
        source.sinks.each do |sink|
          code << "(connect (source #{source.circuit.name} #{source.name}) (sink #{sink.circuit.name} #{sink.name}))"
        end
      end
      code.indent=0
      code << ")"
      code
    end

    def tokenize filename
      str=IO.read(filename)
      tokens=[]
      while str.size>0
        case str
        when /\A\s+/
        when /\A\(/
          tokens << $&
        when /\A\)/
          tokens << $&
        when /\w+/
          tokens << $&
        end
        str.delete_prefix!($&)
      end
      tokens
    end

    def parse_circuit type="circuit" # type = circuit or component
      expect "("
      expect type
      name=accept()
      circuit=Circuit.new(name)
      @symtable[name]=circuit
      while @toks.first!=")"
        case @toks[1]
        when "input"
          circuit << parse_input()
        when "output"
          circuit << parse_output()
        when "component"
          circuit << parse_component()
        when "connect"
          parse_connect()
        end
      end
      expect ")"
      return circuit
    end

    def parse_input
      expect "("
      expect "input"
      name=accept()
      expect ")"
      Input.new(name)
    end

    def parse_output
      expect "("
      expect "output"
      name=accept()
      expect ")"
      Output.new(name)
    end

    def parse_component
      parse_circuit "component"
    end

    def parse_connect
      expect "("
      expect "connect"
      so_comp_name,so_port_name=parse_source()
      si_comp_name,si_port_name=parse_sink()
      so_port=get_port(so_comp_name,so_port_name)
      si_port=get_port(si_comp_name,si_port_name)
      if so_port and si_port
        so_port.connect_to(si_port)
      else
        raise "connexion error !"
      end
      expect ")"
    end

    def get_port comp_name,port_name
      if comp=@symtable[comp_name]
        if port=comp.get_port_named(port_name)
          return port
        else
          "port named '#{port_name}' not found in circuit '#{comp_name}'"
        end
      else
        raise "circuit '#{comp_name}' not found"
      end
    end

    def parse_source
      expect "("
      expect "source"
      comp_name=accept()
      port_name=accept()
      expect ")"
      [comp_name,port_name]
    end

    def parse_sink
      expect "("
      expect "sink"
      comp_name=accept()
      port_name=accept()
      expect ")"
      [comp_name,port_name]
    end

    def expect tok
      if @toks.first==tok
        accept
      else
        raise "malformed s-expression ! Expecting '#{tok}'. Got '#{@toks.first}'"
      end
    end

    def accept
      @toks.shift
    end

  end
end
