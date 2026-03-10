module Seda
  class DotGenerator
    def generate circuit
      puts "[+] generating dot for '#{circuit.name}'"
      code=Code.new
      code << "digraph{"
      code.indent=2
      code << "rankdir=LR;"
      code << "node [fontname=\"Helvetica\",fontsize=10];"

      circuit.inputs.each do |input|
         code << "#{input.object_id}[shape=circle,label=\"#{input.name}\", style=filled, fillcolor=\"#cce5ff\"];"
      end

      code.newline

      circuit.outputs.each do |output|
         code << "#{output.object_id}[shape=circle,label=\"#{output.name}\", style=filled, fillcolor=\"#ffcccc\"];"
      end

      code.newline

      circuit.components.each do |comp|
        name=comp.name
        inputs=comp.inputs.map{|input| "<#{input.name}> #{input.name}"}.join('|')
        outputs=comp.outputs.map{|output| "<#{output.name}> #{output.name}"}.join('|')
        label="{{#{inputs}}|#{name}|{#{outputs}}}"
        code << "#{comp.name}[shape=record,style=\"rounded,filled\",fillcolor=\"#fff5cc\",label=\"#{label}\"];"
      end

      ports=[]
      ports << circuit.ports
      ports << circuit.components.collect{|comp| comp.ports}
      ports.flatten!

      ports.each do |source|
        source.sinks.each do |sink|
          so=name_for(source,circuit)
          si=name_for(sink,circuit)
          code << "#{so} -> #{si}[label=\"\"];"
        end
      end

      code.indent=0
      code << "}"
      code.save_as dot_name="#{circuit.name}.dot"
      puts "[+] code saved as '#{dot_name}'"
    end

    def name_for port,circuit
      if port.circuit==circuit
        return port.object_id
      else
        return "#{port.circuit.name}:#{port.name}"
      end
    end
  end
end
