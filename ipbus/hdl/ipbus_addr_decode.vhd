-- Address decode logic for IPbus fabric
--
-- This file has been AUTOGENERATED from the address table - do not hand edit
--
-- We assume the synthesis tool is clever enough to recognize exclusive conditions
-- in the if statement.
--
-- Dave Newbold, February 2011

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use ieee.numeric_std.all;
use work.ipbus.all;

package ipbus_addr_decode is

  function ipbus_addr_sel(signal addr : in std_logic_vector(31 downto 0)) return integer;

end ipbus_addr_decode;

package body ipbus_addr_decode is

  function ipbus_addr_sel(signal addr : in std_logic_vector(31 downto 0)) return integer is
    variable sel : integer;
  begin
		if    std_match(addr, "-------0---------00----10-------") then
			sel := 0; -- status_reg / base 00000100 / mask 0000001f
		elsif std_match(addr, "-------0---------00----01-------") then
			sel := 1; -- ctrl_reg / base 00000080 / mask 0000000f
		elsif std_match(addr, "-------0---------01-------------") then
			sel := 2; -- write_only_reg / base 00002000 / mask 00000001
		elsif std_match(addr, "-------0---------10-------------") then
			sel := 3; -- channel / base 00004000 / mask 0000000f
		elsif std_match(addr, "-------0---------11-------------") then
			sel := 4; -- ipbus_flash / base 00006000 / mask 000001ff
		elsif std_match(addr, "-------1------------------------") then
			sel := 5; -- ipbus_user / base 01000000 / mask 00ffffff
		else
			sel := 99;
		end if;
		return sel;
	end ipbus_addr_sel;
 
end ipbus_addr_decode;
