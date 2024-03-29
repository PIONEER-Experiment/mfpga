-- Address decode logic for ipbus fabric
--
-- This file has been AUTOGENERATED from the address table - do not hand edit
--
-- We assume the synthesis tool is clever enough to recognise exclusive conditions
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
		if    std_match(addr, "-------0---------001------------") then
			sel := 0; -- status_reg / base 00001000 / mask 0000001f
		elsif std_match(addr, "-------0---------000-----------1") then
			sel := 1; -- ctrl_reg / base 00000001 / mask 00000000
		elsif std_match(addr, "-------0---------001------------") then
			sel := 2; -- ram / base 00001000 / mask 000003ff
		elsif std_match(addr, "-------0---------010------------") then
			sel := 3; -- write_only_reg / base 00002000 / mask 00000001
		elsif std_match(addr, "-------0---------011------------") then
			sel := 4; -- counters / base 00003000 / mask 0000000f
		elsif std_match(addr, "-------0---------100------------") then
			sel := 5; -- channel / base 00004000 / mask 0000000f
		elsif std_match(addr, "-------0---------101------------") then
			sel := 6; -- daq_link / base 00005000 / mask 00000003
		elsif std_match(addr, "-------0---------110------------") then
			sel := 7; -- ipbus_flash / base 00006000 / mask 000001ff
		elsif std_match(addr, "-------1------------------------") then
			sel := 8; -- ipbus_user / base 01000000 / mask 00ffffff
		else
			sel := 99;
		end if;
		return sel;
	end ipbus_addr_sel;
 
end ipbus_addr_decode;
