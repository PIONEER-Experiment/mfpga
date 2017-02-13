-- IPbus slave for read-only status registers
--
-- We use one cycle of read latency to ease timing (probably not necessary).

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;
use work.ipbus.all;

entity ipbus_status_reg is
generic(addr_width : natural := 0);
port(
	clk       : in std_logic; -- ipbus clock
	reset     : in std_logic; -- ipbus reset
	ipbus_in  : in ipb_wbus;  -- fabric bus in
	ipbus_out : out ipb_rbus; -- fabric bus out
	-- status registers
	reg00 : in STD_LOGIC_VECTOR(31 downto 0);
	reg01 : in STD_LOGIC_VECTOR(31 downto 0);
	reg02 : in STD_LOGIC_VECTOR(31 downto 0);
	reg03 : in STD_LOGIC_VECTOR(31 downto 0);
	reg04 : in STD_LOGIC_VECTOR(31 downto 0);
	reg05 : in STD_LOGIC_VECTOR(31 downto 0);
	reg06 : in STD_LOGIC_VECTOR(31 downto 0);
	reg07 : in STD_LOGIC_VECTOR(31 downto 0);
	reg08 : in STD_LOGIC_VECTOR(31 downto 0);
	reg09 : in STD_LOGIC_VECTOR(31 downto 0);
	reg10 : in STD_LOGIC_VECTOR(31 downto 0);
	reg11 : in STD_LOGIC_VECTOR(31 downto 0);
	reg12 : in STD_LOGIC_VECTOR(31 downto 0);
	reg13 : in STD_LOGIC_VECTOR(31 downto 0);
	reg14 : in STD_LOGIC_VECTOR(31 downto 0);
	reg15 : in STD_LOGIC_VECTOR(31 downto 0);
	reg16 : in STD_LOGIC_VECTOR(31 downto 0);
	reg17 : in STD_LOGIC_VECTOR(31 downto 0);
	reg18 : in STD_LOGIC_VECTOR(31 downto 0);
	reg19 : in STD_LOGIC_VECTOR(31 downto 0);
	reg20 : in STD_LOGIC_VECTOR(31 downto 0);
	reg21 : in STD_LOGIC_VECTOR(31 downto 0);
	reg22 : in STD_LOGIC_VECTOR(31 downto 0);
	reg23 : in STD_LOGIC_VECTOR(31 downto 0);
	reg24 : in STD_LOGIC_VECTOR(31 downto 0);
	reg25 : in STD_LOGIC_VECTOR(31 downto 0);
	reg26 : in STD_LOGIC_VECTOR(31 downto 0);
	reg27 : in STD_LOGIC_VECTOR(31 downto 0);
	reg28 : in STD_LOGIC_VECTOR(31 downto 0)
);
end ipbus_status_reg;

architecture rtl of ipbus_status_reg is

	type reg_array is array(28 downto 0) of std_logic_vector(31 downto 0);

	signal reg : reg_array;
	signal sel : integer;
	signal ack : std_logic;
	signal err : std_logic;

begin

	sel <= to_integer(unsigned(ipbus_in.ipb_addr(addr_width - 1 downto 0)));

	process(clk)
	begin
		if rising_edge(clk) then
			-- throw error if attempting to write
			if ipbus_in.ipb_strobe = '1' and ipbus_in.ipb_write = '1' then
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
	reg( 0) <= reg00;
	reg( 1) <= reg01;
	reg( 2) <= reg02;
	reg( 3) <= reg03;
	reg( 4) <= reg04;
	reg( 5) <= reg05;
	reg( 6) <= reg06;
	reg( 7) <= reg07;
	reg( 8) <= reg08;
	reg( 9) <= reg09;
	reg(10) <= reg10;
	reg(11) <= reg11;
	reg(12) <= reg12;
	reg(13) <= reg13;
	reg(14) <= reg14;
	reg(15) <= reg15;
	reg(16) <= reg16;
	reg(17) <= reg17;
	reg(18) <= reg18;
	reg(19) <= reg19;
	reg(20) <= reg20;
	reg(21) <= reg21;
	reg(22) <= reg22;
	reg(23) <= reg23;
	reg(24) <= reg24;
	reg(25) <= reg25;
	reg(26) <= reg26;
	reg(27) <= reg27;
	reg(28) <= reg28;

end rtl;
