library IEEE;
use IEEE.STD_LOGIC_1164.all;

package emac_hostbus_decl is

	-- the signals going from master to slaves
	type emac_hostbus_in is
		record
			hostclk      : std_logic;
			hostopcode   : std_logic_vector( 1 downto 0);
			hostaddr     : std_logic_vector( 9 downto 0);
			hostwrdata   : std_logic_vector(31 downto 0);
			hostmiimsel  : std_logic;
			hostreq      : std_logic;
			hostemac1sel : std_logic;
		end record;
	 
	-- the signals going from slaves to master	 
	type emac_hostbus_out is
		record
			hostrddata  : std_logic_vector(31 downto 0);
			hostmiimrdy : std_logic;
		end record;

end emac_hostbus_decl;
