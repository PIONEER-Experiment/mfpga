-- Generic ipbus slave config register for testing
--
-- generic addr_width defines number of significant address bits
--
-- We use one cycle of read / write latency to ease timing (probably not necessary)
-- The q outputs change immediately on write (no latency)

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;
use work.ipbus.all;

entity ipbus_reg is
generic (addr_width: natural := 0);
port (
	clk           : in  std_logic; -- ipbus clock
	reset         : in  std_logic; -- ipbus reset
	ipbus_in      : in  ipb_wbus;  -- fabric bus in
	ipbus_out     : out ipb_rbus;  -- fabric bus out
	async_mode_in : in  std_logic;
   cbuf_mode_in  : in  std_logic;
	-- output registers
	reg0 : out STD_LOGIC_VECTOR(31 downto 0);
	reg1 : out STD_LOGIC_VECTOR(31 downto 0);
	reg2 : out STD_LOGIC_VECTOR(31 downto 0);
	reg3 : out STD_LOGIC_VECTOR(31 downto 0);
	reg4 : out STD_LOGIC_VECTOR(31 downto 0)
);
end ipbus_reg;

architecture rtl of ipbus_reg is

	type reg_array is array(4 downto 0) of std_logic_vector(31 downto 0);

	signal reg : reg_array;
	signal sel : integer;
	signal ack : std_logic;

begin

	sel <= to_integer(unsigned(ipbus_in.ipb_addr(addr_width - 1 downto 0))) when addr_width > 0 else 0;

	process(clk)
	begin
		if rising_edge(clk) then
			if reset = '1' then
				reg <= (others => (others => '0'));

				-- defaults
				reg(0)( 1) <= async_mode_in; -- never reset asynchronous mode
				reg(0)( 5) <= '1';           -- Channel 0 enabled
				reg(0)( 6) <= '1';           -- Channel 1 enabled
				reg(0)( 7) <= '1';           -- Channel 2 enabled
				reg(0)( 8) <= '1';           -- Channel 3 enabled
				reg(0)( 9) <= '1';           -- Channel 4 enabled
				reg(0)(10) <= '1';           -- Little-endian format for ADC samples
				reg(0)(11) <= '1';           -- enable muon fill trigger type
				reg(0)(12) <= '1';           -- enable laser trigger type
				reg(0)(13) <= '1';           -- enable pedestal trigger type
				reg(0)(19) <= '1';           -- disable EEPROM temperature polling
            reg(0)(25) <= cbuf_mode_in;  -- never reset circular buffer mode
				reg(1)     <= x"0000000a";   -- 10 threshold for data corruption
				reg(2)     <= x"0000000a";   -- 10 threshold for unknown TTC broadcast commands
				reg(3)     <= x"00733334";   -- 7,549,747 (90% full) threshold for DDR3 overflow warning
				reg(4)     <= x"00000000";   -- no trigger delay
			elsif ipbus_in.ipb_strobe = '1' and ipbus_in.ipb_write = '1' then
				reg(sel) <= ipbus_in.ipb_wdata;
			end if;

			ipbus_out.ipb_rdata <= reg(sel);
			ack <= ipbus_in.ipb_strobe and not ack;
		end if;
	end process;
	
	ipbus_out.ipb_ack <= ack;
	ipbus_out.ipb_err <= '0';

	-- assign registers to array
	reg0 <= reg(0);
	reg1 <= reg(1);
	reg2 <= reg(2);
	reg3 <= reg(3);
	reg4 <= reg(4);

end rtl;
