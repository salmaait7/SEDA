require_relative "../lib/seda"

comp=Seda::Serializer.new.read("half_adder.sxp")

if comp
  puts "[+] 'ha' back in memory ! Good !"
end
