library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
 
entity half_adder is
  port(
    e1 : in  std_logic;
    e2 : in  std_logic;
    sum : out std_logic;
    cout : out std_logic;
  );
end entity half_adder;
 
architecture netlist of half_adder is 
  signal w_60 : std_logic;
  signal w_80 : std_logic;
  signal w_100 : std_logic;
  signal w_120 : std_logic;
begin
  w_60 <= e1;
  w_80 <= e2;
 
  and2_i : entity work.and2
  port map(
    a => w_60,
    b => w_80,
    f => w_100,
  );
  xor2_i : entity work.xor2
  port map(
    a => w_60,
    b => w_80,
    f => w_120,
  );
 
  sum <= w_100;
  cout <= w_120;
end architecture netlist;
 
