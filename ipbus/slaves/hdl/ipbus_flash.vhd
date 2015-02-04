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
		flash_wr_nBytes   : out std_logic_vector(8 downto 0);
		flash_rd_nBytes   : out std_logic_vector(8 downto 0);
		flash_cmd_strobe  : out std_logic;
		flash_cmd_ack     : in  std_logic; -- not currently using this signal
		flash_rbuf_en     : out std_logic;
		flash_rbuf_addr   : out std_logic_vector(6 downto 0);
		flash_rbuf_data   : in  std_logic_vector(31 downto 0);
		flash_wbuf_en     : out std_logic;
		flash_wbuf_addr   : out std_logic_vector(6 downto 0);
		flash_wbuf_data   : out std_logic_vector(31 downto 0)
	);

end ipbus_flash;

architecture rtl of ipbus_flash is

	signal ack: std_logic;
	signal ack_delay: std_logic_vector(1 downto 0);
	signal strobe : std_logic;
	signal prev_strobe : std_logic;

	signal addr : std_logic_vector(31 downto 0);
	signal wdata : std_logic_vector(31 downto 0);
	signal rdata : std_logic_vector(31 downto 0);

	attribute mark_debug : string;
	attribute mark_debug of ack : signal is "true";
	attribute mark_debug of strobe : signal is "true";
	attribute mark_debug of prev_strobe : signal is "true";
	attribute mark_debug of addr : signal is "true";
	attribute mark_debug of wdata : signal is "true";
	attribute mark_debug of rdata : signal is "true";

begin

	process(clk)
	begin

		if rising_edge(clk) then

			prev_strobe <= strobe;
			strobe <= ipbus_in.ipb_strobe;

			addr <= ipbus_in.ipb_addr;
			wdata <= ipbus_in.ipb_wdata;

			if ipbus_in.ipb_addr(8)='1' then
			-- FLASH.CMD

				-- capture the command when the strobe turns on
				--     (there will only ever be one command per strobe)
				if (prev_strobe = '0' and strobe = '1') then
					flash_wr_nBytes <= ipbus_in.ipb_wdata(24 downto 16);
					flash_rd_nBytes <= ipbus_in.ipb_wdata(8 downto 0);
				end if;
				
				flash_cmd_strobe <= ipbus_in.ipb_strobe and ipbus_in.ipb_write;
				flash_rbuf_en <= '0';
				flash_wbuf_en <= '0';

			elsif ipbus_in.ipb_addr(7)='1' then
			-- FLASH.RBUF

				flash_rbuf_en <= ipbus_in.ipb_strobe;
				flash_rbuf_addr <= ipbus_in.ipb_addr(6 downto 0);
				ipbus_out.ipb_rdata <= flash_rbuf_data;
				rdata <= flash_rbuf_data;
				flash_wbuf_en <= '0';
				flash_cmd_strobe <= '0';

			else
			-- FLASH.WBUF

				flash_wbuf_en <= ipbus_in.ipb_strobe and ipbus_in.ipb_write;
				flash_wbuf_addr <= ipbus_in.ipb_addr(6 downto 0);
				flash_wbuf_data <= ipbus_in.ipb_wdata;
				ipbus_out.ipb_rdata <= ipbus_in.ipb_wdata;
				flash_rbuf_en <= '0';
				flash_cmd_strobe <= '0';

			end if;

		ack_delay(0) <= ipbus_in.ipb_strobe and not ack;
		ack_delay(1) <= ack_delay(0) and not ack;
		ack <= ack_delay(1) and not ack;

		end if;

	end process;

	ipbus_out.ipb_ack <= ack;
	ipbus_out.ipb_err <= '0';

end rtl;
