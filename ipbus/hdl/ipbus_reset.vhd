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

signal sync_rst_ipb: std_logic_vector(1 downto 0);
signal sync_rst_125: std_logic_vector(1 downto 0);
signal sync_rst_200: std_logic_vector(1 downto 0);


begin

	ipb: process(clk_ipb)
	begin
		if rising_edge(clk_ipb) then
			sync_rst_ipb(1) <= rst_in;
			sync_rst_ipb(0) <= sync_rst_ipb(1);
			rst_ipb <= sync_rst_ipb(0);
		end if;
	end process;

	p125: process(clk_125)
	begin
		if rising_edge(clk_125) then
			sync_rst_125(1) <= rst_in;
			sync_rst_125(0) <= sync_rst_125(1);
			rst_125 <= sync_rst_125(0);
		end if;
	end process;

	p200: process(clk_200)
	begin
		if rising_edge(clk_200) then
			sync_rst_200(1) <= rst_in;
			sync_rst_200(0) <= sync_rst_200(1);
			rst_200 <= sync_rst_200(0);
		end if;
	end process;
end rtl;


