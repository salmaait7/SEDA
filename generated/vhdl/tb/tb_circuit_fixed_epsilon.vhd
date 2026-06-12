library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library std;
use std.textio.all;

entity tb_circuit_fixed_epsilon is
end entity tb_circuit_fixed_epsilon;

architecture sim of tb_circuit_fixed_epsilon is
  signal x3 : std_logic;
  signal x2 : std_logic;
  signal x0 : std_logic;
  signal x1 : std_logic;
  signal y0 : std_logic;
  signal y1 : std_logic;
  signal y2 : std_logic;
  signal dbg_w0 : std_logic;
  signal dbg_w1 : std_logic;
  signal dbg_w2 : std_logic;
  signal dbg_w3 : std_logic;
  signal dbg_w4 : std_logic;
  signal dbg_w5 : std_logic;
  signal dbg_w6 : std_logic;
  signal dbg_w7 : std_logic;
  signal dbg_w8 : std_logic;
  signal dbg_w9 : std_logic;
  signal dbg_w10 : std_logic;
  signal dbg_w11 : std_logic;
  signal dbg_w12 : std_logic;
  signal dbg_w13 : std_logic;
  signal dbg_w14 : std_logic;
  signal dbg_w15 : std_logic;
  signal dbg_w16 : std_logic;
  signal dbg_w17 : std_logic;
  signal dbg_w18 : std_logic;
  signal dbg_w19 : std_logic;
  signal dbg_w20 : std_logic;
  signal dbg_w21 : std_logic;
  signal dbg_w22 : std_logic;
  signal dbg_w23 : std_logic;
  signal dbg_w24 : std_logic;
  signal dbg_w25 : std_logic;

  file activity_file : text open write_mode is "activity/activity_circuit_fixed_epsilon.csv";
begin
  dut : entity work.circuit_fixed_epsilon
  port map(
    x3 => x3,
    x2 => x2,
    x0 => x0,
    x1 => x1,
    y0 => y0,
    y1 => y1,
    y2 => y2,
    dbg_w0 => dbg_w0,
    dbg_w1 => dbg_w1,
    dbg_w2 => dbg_w2,
    dbg_w3 => dbg_w3,
    dbg_w4 => dbg_w4,
    dbg_w5 => dbg_w5,
    dbg_w6 => dbg_w6,
    dbg_w7 => dbg_w7,
    dbg_w8 => dbg_w8,
    dbg_w9 => dbg_w9,
    dbg_w10 => dbg_w10,
    dbg_w11 => dbg_w11,
    dbg_w12 => dbg_w12,
    dbg_w13 => dbg_w13,
    dbg_w14 => dbg_w14,
    dbg_w15 => dbg_w15,
    dbg_w16 => dbg_w16,
    dbg_w17 => dbg_w17,
    dbg_w18 => dbg_w18,
    dbg_w19 => dbg_w19,
    dbg_w20 => dbg_w20,
    dbg_w21 => dbg_w21,
    dbg_w22 => dbg_w22,
    dbg_w23 => dbg_w23,
    dbg_w24 => dbg_w24,
    dbg_w25 => dbg_w25
  );

  stim_proc : process
  begin
    x3 <= '0';
    x2 <= '0';
    x0 <= '0';
    x1 <= '0';
    wait for 20 ns;

    x3 <= '0';
    x2 <= '0';
    x0 <= '0';
    x1 <= '1';
    wait for 20 ns;

    x3 <= '0';
    x2 <= '0';
    x0 <= '1';
    x1 <= '0';
    wait for 20 ns;

    x3 <= '0';
    x2 <= '0';
    x0 <= '1';
    x1 <= '1';
    wait for 20 ns;

    x3 <= '0';
    x2 <= '1';
    x0 <= '0';
    x1 <= '0';
    wait for 20 ns;

    x3 <= '0';
    x2 <= '1';
    x0 <= '0';
    x1 <= '1';
    wait for 20 ns;

    x3 <= '0';
    x2 <= '1';
    x0 <= '1';
    x1 <= '0';
    wait for 20 ns;

    x3 <= '0';
    x2 <= '1';
    x0 <= '1';
    x1 <= '1';
    wait for 20 ns;

    x3 <= '1';
    x2 <= '0';
    x0 <= '0';
    x1 <= '0';
    wait for 20 ns;

    x3 <= '1';
    x2 <= '0';
    x0 <= '0';
    x1 <= '1';
    wait for 20 ns;

    x3 <= '1';
    x2 <= '0';
    x0 <= '1';
    x1 <= '0';
    wait for 20 ns;

    x3 <= '1';
    x2 <= '0';
    x0 <= '1';
    x1 <= '1';
    wait for 20 ns;

    x3 <= '1';
    x2 <= '1';
    x0 <= '0';
    x1 <= '0';
    wait for 20 ns;

    x3 <= '1';
    x2 <= '1';
    x0 <= '0';
    x1 <= '1';
    wait for 20 ns;

    x3 <= '1';
    x2 <= '1';
    x0 <= '1';
    x1 <= '0';
    wait for 20 ns;

    x3 <= '1';
    x2 <= '1';
    x0 <= '1';
    x1 <= '1';
    wait for 20 ns;

    wait;
  end process;

  monitor_proc : process(x3, x2, x0, x1, y0, y1, y2, dbg_w0, dbg_w1, dbg_w2, dbg_w3, dbg_w4, dbg_w5, dbg_w6, dbg_w7, dbg_w8, dbg_w9, dbg_w10, dbg_w11, dbg_w12, dbg_w13, dbg_w14, dbg_w15, dbg_w16, dbg_w17, dbg_w18, dbg_w19, dbg_w20, dbg_w21, dbg_w22, dbg_w23, dbg_w24, dbg_w25)
  variable L : line;
begin
  write(L, now);
  write(L, string'(","));
  write(L, std_logic'image(x3));
  write(L, string'(","));
  write(L, std_logic'image(x2));
  write(L, string'(","));
  write(L, std_logic'image(x0));
  write(L, string'(","));
  write(L, std_logic'image(x1));
  write(L, string'(","));
  write(L, std_logic'image(y0));
  write(L, string'(","));
  write(L, std_logic'image(y1));
  write(L, string'(","));
  write(L, std_logic'image(y2));
  write(L, string'(","));
  write(L, std_logic'image(dbg_w0));
  write(L, string'(","));
  write(L, std_logic'image(dbg_w1));
  write(L, string'(","));
  write(L, std_logic'image(dbg_w2));
  write(L, string'(","));
  write(L, std_logic'image(dbg_w3));
  write(L, string'(","));
  write(L, std_logic'image(dbg_w4));
  write(L, string'(","));
  write(L, std_logic'image(dbg_w5));
  write(L, string'(","));
  write(L, std_logic'image(dbg_w6));
  write(L, string'(","));
  write(L, std_logic'image(dbg_w7));
  write(L, string'(","));
  write(L, std_logic'image(dbg_w8));
  write(L, string'(","));
  write(L, std_logic'image(dbg_w9));
  write(L, string'(","));
  write(L, std_logic'image(dbg_w10));
  write(L, string'(","));
  write(L, std_logic'image(dbg_w11));
  write(L, string'(","));
  write(L, std_logic'image(dbg_w12));
  write(L, string'(","));
  write(L, std_logic'image(dbg_w13));
  write(L, string'(","));
  write(L, std_logic'image(dbg_w14));
  write(L, string'(","));
  write(L, std_logic'image(dbg_w15));
  write(L, string'(","));
  write(L, std_logic'image(dbg_w16));
  write(L, string'(","));
  write(L, std_logic'image(dbg_w17));
  write(L, string'(","));
  write(L, std_logic'image(dbg_w18));
  write(L, string'(","));
  write(L, std_logic'image(dbg_w19));
  write(L, string'(","));
  write(L, std_logic'image(dbg_w20));
  write(L, string'(","));
  write(L, std_logic'image(dbg_w21));
  write(L, string'(","));
  write(L, std_logic'image(dbg_w22));
  write(L, string'(","));
  write(L, std_logic'image(dbg_w23));
  write(L, string'(","));
  write(L, std_logic'image(dbg_w24));
  write(L, string'(","));
  write(L, std_logic'image(dbg_w25));
  writeline(activity_file, L);
end process;
end architecture sim;
