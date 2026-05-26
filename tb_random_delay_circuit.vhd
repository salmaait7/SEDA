library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_random_delay_circuit is
end entity tb_random_delay_circuit;

architecture sim of tb_random_delay_circuit is
  signal x0 : std_logic;
  signal x2 : std_logic;
  signal x1 : std_logic;
  signal x4 : std_logic;
  signal x3 : std_logic;
  signal y0 : std_logic;
  signal y1 : std_logic;
  signal y2 : std_logic;
begin
  dut : entity work.random_delay_circuit
  port map(
    x0 => x0,
    x2 => x2,
    x1 => x1,
    x4 => x4,
    x3 => x3,
    y0 => y0,
    y1 => y1,
    y2 => y2
  );

  stim_proc : process
  begin
    x0 <= '0';
    x2 <= '0';
    x1 <= '0';
    x4 <= '0';
    x3 <= '0';
    wait for 20 ns;

    x0 <= '0';
    x2 <= '0';
    x1 <= '0';
    x4 <= '0';
    x3 <= '1';
    wait for 20 ns;

    x0 <= '0';
    x2 <= '0';
    x1 <= '0';
    x4 <= '1';
    x3 <= '0';
    wait for 20 ns;

    x0 <= '0';
    x2 <= '0';
    x1 <= '0';
    x4 <= '1';
    x3 <= '1';
    wait for 20 ns;

    x0 <= '0';
    x2 <= '0';
    x1 <= '1';
    x4 <= '0';
    x3 <= '0';
    wait for 20 ns;

    x0 <= '0';
    x2 <= '0';
    x1 <= '1';
    x4 <= '0';
    x3 <= '1';
    wait for 20 ns;

    x0 <= '0';
    x2 <= '0';
    x1 <= '1';
    x4 <= '1';
    x3 <= '0';
    wait for 20 ns;

    x0 <= '0';
    x2 <= '0';
    x1 <= '1';
    x4 <= '1';
    x3 <= '1';
    wait for 20 ns;

    x0 <= '0';
    x2 <= '1';
    x1 <= '0';
    x4 <= '0';
    x3 <= '0';
    wait for 20 ns;

    x0 <= '0';
    x2 <= '1';
    x1 <= '0';
    x4 <= '0';
    x3 <= '1';
    wait for 20 ns;

    x0 <= '0';
    x2 <= '1';
    x1 <= '0';
    x4 <= '1';
    x3 <= '0';
    wait for 20 ns;

    x0 <= '0';
    x2 <= '1';
    x1 <= '0';
    x4 <= '1';
    x3 <= '1';
    wait for 20 ns;

    x0 <= '0';
    x2 <= '1';
    x1 <= '1';
    x4 <= '0';
    x3 <= '0';
    wait for 20 ns;

    x0 <= '0';
    x2 <= '1';
    x1 <= '1';
    x4 <= '0';
    x3 <= '1';
    wait for 20 ns;

    x0 <= '0';
    x2 <= '1';
    x1 <= '1';
    x4 <= '1';
    x3 <= '0';
    wait for 20 ns;

    x0 <= '0';
    x2 <= '1';
    x1 <= '1';
    x4 <= '1';
    x3 <= '1';
    wait for 20 ns;

    wait;
  end process;
end architecture sim;
