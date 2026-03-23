require_relative "../lib/seda"

def build_a_half_adder
  puts "[+] building a half_adder programmatically"
  include Seda #pour ne pas devoir préfixer les classes avec 'Seda::'
  and2=Circuit.new("and2")
  and2 << Input.new("a")
  and2 << Input.new("b")
  and2 << Output.new("f")

  xor2=Circuit.new("xor2")
  xor2 << Input.new("a")
  xor2 << Input.new("b")
  xor2 << Output.new("f")

  ha=Circuit.new("half_adder")
  ha << e1=Input.new("e1")
  ha << e2=Input.new("e2")
  ha << sum  = Output.new("sum")
  ha << cout = Output.new("cout")
  ha << and2
  ha << xor2

  # connect everything
  and2_a=and2.get_port_named("a")
  and2_b=and2.get_port_named("b")
  and2_f=and2.get_port_named("f")

  xor2_a=xor2.get_port_named("a")
  xor2_b=xor2.get_port_named("b")
  xor2_f=xor2.get_port_named("f")

  e1.connect_to and2_a
  e2.connect_to and2_b
  e1.connect_to xor2_a
  e2.connect_to xor2_b
  xor2_f.connect_to sum
  and2_f.connect_to cout

  return ha
end

if __FILE__==$0
  ha=build_a_half_adder()

  puts ha # peut recevoir presque n’importe quel objet
end
