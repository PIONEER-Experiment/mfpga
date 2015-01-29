-- ipbus slave connected to SPI flash WBUF and RBUF block RAMs
-- also has one address for sending commands to initiate communication w/ flash
--
-- Robin Bjorkquist, January 2015

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;
use work.ipbus.all;

entity ipbus_flash is
	generic(addr_width : positive);
	port(
		clk: in std_logic;
		reset: in std_logic;
		ipbus_in: in ipb_wbus;
		ipbus_out: out ipb_rbus;
		flash_rbuf_en   : out std_logic;
		flash_rbuf_addr : out std_logic_vector(6 downto 0);
		flash_rbuf_data : in  std_logic_vector(31 downto 0);
		flash_wbuf_en   : out std_logic;
		flash_wbuf_addr : out std_logic_vector(6 downto 0);
		flash_wbuf_data : out std_logic_vector(31 downto 0)
	);

end ipbus_flash;

architecture rtl of ipbus_flash is

	signal ack: std_logic;
	signal ack_delay: std_logic_vector(1 downto 0);

begin

	process(clk)
	begin

		if rising_edge(clk) then

			if ipbus_in.ipb_addr(8)='1' then
			-- FLASH.CMD

				flash_rbuf_en <= '0';
				flash_wbuf_en <= '0';

			elsif ipbus_in.ipb_addr(7)='1' then
			-- FLASH.RBUF

				flash_rbuf_en <= ipbus_in.ipb_strobe;
				flash_rbuf_addr <= ipbus_in.ipb_addr(6 downto 0);
				ipbus_out.ipb_rdata <= flash_rbuf_data;
				flash_wbuf_en <= '0';

			else
			-- FLASH.WBUF

				flash_wbuf_en <= ipbus_in.ipb_strobe and ipbus_in.ipb_write;
				flash_wbuf_addr <= ipbus_in.ipb_addr(6 downto 0);
				flash_wbuf_data <= ipbus_in.ipb_wdata;
				ipbus_out.ipb_rdata <= ipbus_in.ipb_wdata;
				flash_rbuf_en <= '0';

			end if;

			ack_delay(0) <= ipbus_in.ipb_strobe and not ack;
			ack_delay(1) <= ack_delay(0) and not ack;
			ack <= ack_delay(1) and not ack;

		end if;

		ipbus_out.ipb_ack <= ack;
		ipbus_out.ipb_err <= '0';

	end process;

end rtl;
