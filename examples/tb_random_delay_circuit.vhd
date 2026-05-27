library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library std;
use std.textio.all;

entity tb_random_delay_circuit is
end entity tb_random_delay_circuit;

architecture sim of tb_random_delay_circuit is
  signal x4 : std_logic;
  signal x1 : std_logic;
  signal x3 : std_logic;
  signal x2 : std_logic;
  signal y0 : std_logic;
  signal y1 : std_logic;
  signal y2 : std_logic;

  file activity_file : text open write_mode is "activity.csv";
begin
  dut : entity work.random_delay_circuit
  port map(
    x4 => x4,
    x1 => x1,
    x3 => x3,
    x2 => x2,
    y0 => y0,
    y1 => y1,
    y2 => y2
  );

  stim_proc : process
  begin
    x4 <= '0';
    x1 <= '0';
    x3 <= '0';
    x2 <= '0';
    wait for 20 ns;

    x4 <= '0';
    x1 <= '0';
    x3 <= '0';
    x2 <= '1';
    wait for 20 ns;

    x4 <= '0';
    x1 <= '0';
    x3 <= '1';
    x2 <= '0';
    wait for 20 ns;

    x4 <= '0';
    x1 <= '0';
    x3 <= '1';
    x2 <= '1';
    wait for 20 ns;

    x4 <= '0';
    x1 <= '1';
    x3 <= '0';
    x2 <= '0';
    wait for 20 ns;

    x4 <= '0';
    x1 <= '1';
    x3 <= '0';
    x2 <= '1';
    wait for 20 ns;

    x4 <= '0';
    x1 <= '1';
    x3 <= '1';
    x2 <= '0';
    wait for 20 ns;

    x4 <= '0';
    x1 <= '1';
    x3 <= '1';
    x2 <= '1';
    wait for 20 ns;

    x4 <= '1';
    x1 <= '0';
    x3 <= '0';
    x2 <= '0';
    wait for 20 ns;

    x4 <= '1';
    x1 <= '0';
    x3 <= '0';
    x2 <= '1';
    wait for 20 ns;

    x4 <= '1';
    x1 <= '0';
    x3 <= '1';
    x2 <= '0';
    wait for 20 ns;

    x4 <= '1';
    x1 <= '0';
    x3 <= '1';
    x2 <= '1';
    wait for 20 ns;

    x4 <= '1';
    x1 <= '1';
    x3 <= '0';
    x2 <= '0';
    wait for 20 ns;

    x4 <= '1';
    x1 <= '1';
    x3 <= '0';
    x2 <= '1';
    wait for 20 ns;

    x4 <= '1';
    x1 <= '1';
    x3 <= '1';
    x2 <= '0';
    wait for 20 ns;

    x4 <= '1';
    x1 <= '1';
    x3 <= '1';
    x2 <= '1';
    wait for 20 ns;

    wait;
  end process;

  monitor_proc : process(x4, x1, x3, x2, y0, y1, y2)
  variable L : line;
begin
  write(L, now);
  write(L, string'(","));
  write(L, x4);
  write(L, string'(","));
  write(L, x1);
  write(L, string'(","));
  write(L, x3);
  write(L, string'(","));
  write(L, x2);
  write(L, string'(","));
  write(L, y0);
  write(L, string'(","));
  write(L, y1);
  write(L, string'(","));
  write(L, y2);
  writeline(activity_file, L);
end process;
end architecture sim;
