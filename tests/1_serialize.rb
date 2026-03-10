require_relative "../lib/seda"
require_relative "0_build_circuit"

ha=build_a_half_adder()

serializer=Serializer.new
serializer.write(ha)
