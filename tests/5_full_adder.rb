require_relative "../lib/seda"
require_relative "0_build_circuit"

ha1 = build_a_half_adder
ha1.instance_name = "ha1"

ha2 = build_a_half_adder
ha2.instance_name = "ha2"

or2=Circuit.new("or2")
or2 << Input.new("a")
or2 << Input.new("b")
or2 << Output.new("f")



fa=Circuit.new("full_adder")
fa << e1=Input.new("e1")
fa << e2=Input.new("e2")
fa << cin=Input.new("cin")
fa << sum  = Output.new("sum")
fa << cout = Output.new("cout")
fa << ha1
fa << ha2

fa << or2

# connect everything
e1.connect_to ha1.get_port_named("e1")
e2.connect_to ha1.get_port_named("e2")
cin.connect_to ha2.get_port_named("e1") 
ha1.get_port_named("sum").connect_to ha2.get_port_named("e2")
ha2.get_port_named("sum").connect_to sum    
ha1.get_port_named("cout").connect_to or2.get_port_named("a")
ha2.get_port_named("cout").connect_to or2.get_port_named("b")
or2.get_port_named("f").connect_to cout

generator=Seda::VHDLGenerator.new
generator.generate(fa)