library ieee;
use ieee.std_logic_1164.all;

use work.ipbus.all; -- for type_ipbus_buffer
use work.axi.all;

package axi_simulation is

	procedure axi_read( signal clk: in std_logic;
						signal axi_in: axi_stream;
						signal axi_in_tready: out std_logic := 0;
						data: out type_ipbus_buffer
					  );
end package;

package body axi_simulation is
	
	procedure axi_read( signal clk: in std_logic;
						signal axi_in: axi_stream;
						signal axi_in_tready: out std_logic := 0;
						data: out type_ipbus_buffer
					  ) is

		variable reading: boolean := false;
		variable i: natural := 0;

	begin
		reading := true;
		while reading loop
			wait until rising_edge(clk);
			axi_in_tready <= '1';
			if axi_in.tvalid = '1' then
				data(i) := axi_in.tdata;
				i := i + 1;
				if axi_in.tlast = '1' then
					reading := false;
				end if;
			end if;
		end loop;
		axi_in_tready <= '0';
    end procedure;

end axi_simulation;