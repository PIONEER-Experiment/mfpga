-- generate synchronous resets in all clock domains from 
-- one in the clk_ipb domain.
-- resets other than rst_ipb are delayed so that ipbus
-- resets before everything else

library ieee;
use ieee.std_logic_1164.all;

entity ipbus_reset is 
	port(
		clk_ipb: in std_logic;
		clk_125: in std_logic;
		clk_200: in std_logic;
		rst_in: in std_logic;
		rst_ipb: out std_logic;
		rst_125: out std_logic;
		rst_200: out std_logic
		);
end ipbus_reset;

architecture rtl of ipbus_reset is

signal rst_sr: std_logic_vector(3 downto 0);

begin
	rst_ipb <= rst_in;

	ipb: process(clk_ipb)
	begin
		if rising_edge(clk_ipb) then
			rst_sr(3) <= rst_in;
			rst_sr(2) <= rst_sr(3);
			rst_sr(1) <= rst_sr(2);
			rst_sr(0) <= rst_sr(1);
		end if;
	end process;

	c125: process(clk_125)
	begin
		if rising_edge(clk_125) then
			rst_125 <= rst_sr(0);
		end if;
	end process;

	c200: process(clk_200)
	begin
		if rising_edge(clk_200) then
			rst_200 <= rst_sr(0);
		end if;
	end process;
end rtl;


