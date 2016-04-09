-- IPbus slave for read-only status registers
--
-- We use one cycle of read latency to ease timing (probably not necessary).

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;
use work.ipbus.all;

entity ipbus_status_reg is
	generic(addr_width: natural := 0);
	port(
		clk       : in std_logic; -- ipbus clock
		reset     : in std_logic; -- ipbus reset
		ipbus_in  : in ipb_wbus;  -- fabric bus in
		ipbus_out : out ipb_rbus; -- fabric bus out
		-- status registers
		reg0      : in STD_LOGIC_VECTOR(31 downto 0);
		reg1      : in STD_LOGIC_VECTOR(31 downto 0);
		reg2      : in STD_LOGIC_VECTOR(31 downto 0);
		reg3      : in STD_LOGIC_VECTOR(31 downto 0);
		reg4      : in STD_LOGIC_VECTOR(31 downto 0);
		reg5      : in STD_LOGIC_VECTOR(31 downto 0);
		reg6      : in STD_LOGIC_VECTOR(31 downto 0);
		reg7      : in STD_LOGIC_VECTOR(31 downto 0);
		reg8      : in STD_LOGIC_VECTOR(31 downto 0);
		reg9      : in STD_LOGIC_VECTOR(31 downto 0);
		reg10     : in STD_LOGIC_VECTOR(31 downto 0);
		reg11     : in STD_LOGIC_VECTOR(31 downto 0)
	);
	
end ipbus_status_reg;

architecture rtl of ipbus_status_reg is

	type reg_array is array(11 downto 0) of std_logic_vector(31 downto 0);
	signal reg: reg_array;
	signal sel: integer;
	signal ack: std_logic;
	signal err: std_logic;

begin

	sel <= to_integer(unsigned(ipbus_in.ipb_addr(addr_width - 1 downto 0)));

	process(clk)
	begin
		if rising_edge(clk) then
			-- throw error if attempting to write
			if ipbus_in.ipb_strobe='1' and ipbus_in.ipb_write='1' then
				err <= '1';
			else
				err <= '0';
			end if;

			ipbus_out.ipb_rdata <= reg(sel);
			ack <= ipbus_in.ipb_strobe and not ack;

		end if;
	end process;
	
	ipbus_out.ipb_ack <= ack;
	ipbus_out.ipb_err <= err;

	-- assign registers to array
	reg(0) <= reg0;
	reg(1) <= reg1;
	reg(2) <= reg2;
	reg(3) <= reg3;
	reg(4) <= reg4;
	reg(5) <= reg5;
	reg(6) <= reg6;
	reg(7) <= reg7;
	reg(8) <= reg8;
	reg(9) <= reg9;
	reg(10) <= reg10;
	reg(11) <= reg11;

end rtl;
