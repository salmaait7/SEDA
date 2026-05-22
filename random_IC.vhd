library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity random_IC is
  port(
    x3 : in  std_logic;
    x0 : in  std_logic;
    x1 : in  std_logic;
    x2 : in  std_logic;
    y0 : out std_logic;
    y1 : out std_logic;
    y2 : out std_logic
  );
end entity random_IC;

architecture Archi of random_IC is 
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
begin
  w_16 <= x3;
  w_24 <= x0;
  w_32 <= x1;
  w_40 <= x2;

  U0 : entity work.XOR2_GATE
  port map(
    e1 => w_56,
    e2 => w_72,
    f => w_48
  );
  U1 : entity work.NOT_GATE
  port map(
    e => w_64,
    f => w_56
  );
  U2 : entity work.BUF_GATE
  port map(
    e => w_16,
    f => w_64
  );
  U3 : entity work.BUF_GATE
  port map(
    e => w_80,
    f => w_72
  );
  U4 : entity work.NAND2_GATE
  port map(
    e1 => w_24,
    e2 => w_24,
    f => w_80
  );
  U5 : entity work.NOR2_GATE
  port map(
    e1 => w_96,
    e2 => w_112,
    f => w_88
  );
  U6 : entity work.BUF_GATE
  port map(
    e => w_104,
    f => w_96
  );
  U7 : entity work.BUF_GATE
  port map(
    e => w_16,
    f => w_104
  );
  U8 : entity work.XOR2_GATE
  port map(
    e1 => w_120,
    e2 => w_128,
    f => w_112
  );
  U9 : entity work.AND2_GATE
  port map(
    e1 => w_32,
    e2 => w_16,
    f => w_120
  );
  U10 : entity work.NOT_GATE
  port map(
    e => w_16,
    f => w_128
  );
  U11 : entity work.NOT_GATE
  port map(
    e => w_144,
    f => w_136
  );
  U12 : entity work.BUF_GATE
  port map(
    e => w_152,
    f => w_144
  );
  U13 : entity work.BUF_GATE
  port map(
    e => w_40,
    f => w_152
  );

  y0 <= w_48;
  y1 <= w_88;
  y2 <= w_136;
end architecture Archi;
