-- generate synchronous resets in all clock domains from 
-- one in the clk_ipb domain.
-- resets other than rst_ipb are delayed so that ipbus
-- resets before everything else
--
-- 6.7.1: the reset into the other clock domains is stretched and synchronised properly.
-- In this design clk_ipb is the master's PLL clk125 (from the 50 MHz input) and clk_125 is the
-- Gigabit Ethernet PHY's userclk2 (from the GT reference clock): two independent 125 MHz clocks.
-- rst_delayed is a single clk_ipb cycle (8 ns), and it was sampled by a two-stage chain in
-- clk_125 that Vivado packed into an SRL16E (report_cdc: CDC-13, critical, "1-bit CDC path on a
-- non-FD primitive", ipb/rst/rst_delayed_reg -> ipb/rst/sync_rst_125_reg[0]_srl2).  A one-cycle
-- pulse between two asynchronous clocks of the same frequency can be missed, and an SRL is not a
-- synchroniser.  If the pulse is missed, the IPbus side of ipbus_ctrl (rst_ipb) is reset and the
-- MAC side (udp_if, the soft EMAC: rst_125) is not, and the two halves of the packet-buffer
-- handshake can disagree.  This is the most likely cause of the intermittent "board deaf after
-- SYS.RST, no ping, until reconfigured" failure: it is the one defect found in the reset path, it
-- depends on the phase between the two clocks at the moment of the reset (random), and on the
-- routing delay of this one path (build dependent).
-- rst_ipb is unchanged (one clk_ipb cycle, as the rest of the design expects from rst_out); the
-- copy for the other domains is held for 16 clk_ipb cycles (128 ns) and synchronised by real
-- flip-flops marked ASYNC_REG, so every domain sees it whatever the phase.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

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

signal rst_delayed: std_logic := '0';
signal rst_xdom: std_logic := '0';                         -- stretched copy for the other clock domains
signal xdom_ctr: unsigned(3 downto 0) := (others => '0');
signal sync_rst_125: std_logic_vector(1 downto 0) := (others => '0');
signal sync_rst_200: std_logic_vector(1 downto 0) := (others => '0');

attribute ASYNC_REG : string;
attribute ASYNC_REG of sync_rst_125 : signal is "TRUE";
attribute ASYNC_REG of sync_rst_200 : signal is "TRUE";
attribute SHREG_EXTRACT : string;
attribute SHREG_EXTRACT of sync_rst_125 : signal is "NO";
attribute SHREG_EXTRACT of sync_rst_200 : signal is "NO";

signal rst_dly_ctr: unsigned(7 downto 0) := X"00";

begin

	ipb: process(clk_ipb)
	begin
		if rising_edge(clk_ipb) then
			if rst_delayed = '1' then
				rst_delayed <= '0';
			end if;
			if rst_in = '1' then
				if rst_dly_ctr = X"FF" then
					rst_dly_ctr <= X"00";
					rst_delayed <= '1';
				else
					rst_dly_ctr <= rst_dly_ctr + 1;
				end if;
			end if;
			rst_ipb <= rst_delayed;
			-- the stretched copy: starts with rst_delayed, held for 16 cycles
			if rst_delayed = '1' then
				xdom_ctr <= (others => '1');
				rst_xdom <= '1';
			elsif xdom_ctr /= 0 then
				xdom_ctr <= xdom_ctr - 1;
			else
				rst_xdom <= '0';
			end if;
		end if;
	end process;

	p125: process(clk_125)
	begin
		if rising_edge(clk_125) then
			sync_rst_125(1) <= rst_xdom;
			sync_rst_125(0) <= sync_rst_125(1);
			rst_125 <= sync_rst_125(0);
		end if;
	end process;

	p200: process(clk_200)
	begin
		if rising_edge(clk_200) then
			sync_rst_200(1) <= rst_xdom;
			sync_rst_200(0) <= sync_rst_200(1);
			rst_200 <= sync_rst_200(0);
		end if;
	end process;
end rtl;
