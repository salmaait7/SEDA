library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity random_circuit is
  port(
    x3 : in  std_logic;
    x4 : in  std_logic;
    x0 : in  std_logic;
    x1 : in  std_logic;
    x2 : in  std_logic;
    y0 : out std_logic;
    y1 : out std_logic;
    y2 : out std_logic
  );
end entity random_circuit;

architecture Archi of random_circuit is 
  signal w_16 : std_logic;
  signal w_24 : std_logic;
  signal w_32 : std_logic;
  signal w_40 : std_logic;
  signal w_48 : std_logic;
  signal w_56 : std_logic;
  signal w_64 : std_logic;
  signal w_72 : std_logic;
  signal w_80 : std_logic;
  signal w_88 : std_logic;
  signal w_96 : std_logic;
  signal w_104 : std_logic;
  signal w_112 : std_logic;
  signal w_120 : std_logic;
  signal w_128 : std_logic;
  signal w_136 : std_logic;
  signal w_144 : std_logic;
  signal w_152 : std_logic;
  signal w_160 : std_logic;
  signal w_168 : std_logic;
  signal w_176 : std_logic;
  signal w_184 : std_logic;
  signal w_192 : std_logic;
begin
  w_16 <= x3;
  w_24 <= x4;
  w_32 <= x0;
  w_40 <= x1;
  w_48 <= x2;

  U0 : entity work.XOR2
  port map(
    a => w_16,
    b => w_16,
    y => w_56
  );
  U1 : entity work.BUF
  port map(
    a => w_56,
    y => w_64
  );
  U2 : entity work.NOT
  port map(
    a => w_24,
    y => w_72
  );
  U3 : entity work.NOT
  port map(
    a => w_32,
    y => w_80
  );
  U4 : entity work.XOR2
  port map(
    a => w_72,
    b => w_80,
    y => w_88
  );
  U5 : entity work.OR2
  port map(
    a => w_64,
    b => w_88,
    y => w_96
  );
  U6 : entity work.NOT
  port map(
    a => w_40,
    y => w_104
  );
  U7 : entity work.NAND2
  port map(
    a => w_32,
    b => w_24,
    y => w_112
  );
  U8 : entity work.XOR2
  port map(
    a => w_104,
    b => w_112,
    y => w_120
  );
  U9 : entity work.XOR2
  port map(
    a => w_40,
    b => w_32,
    y => w_128
  );
  U10 : entity work.BUF
  port map(
    a => w_128,
    y => w_136
  );
  U11 : entity work.NAND2
  port map(
    a => w_120,
    b => w_136,
    y => w_144
  );
  U12 : entity work.NOT
  port map(
    a => w_40,
    y => w_152
  );
  U13 : entity work.OR2
  port map(
    a => w_24,
    b => w_32,
    y => w_160
  );
  U14 : entity work.OR2
  port map(
    a => w_152,
    b => w_160,
    y => w_168
  );
  U15 : entity work.NOR2
  port map(
    a => w_24,
    b => w_48,
    y => w_176
  );
  U16 : entity work.NOT
  port map(
    a => w_176,
    y => w_184
  );
  U17 : entity work.OR2
  port map(
    a => w_168,
    b => w_184,
    y => w_192
  );

  y0 <= w_96;
  y1 <= w_144;
  y2 <= w_192;
end architecture Archi;
