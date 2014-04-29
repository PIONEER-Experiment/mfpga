library ieee;
use ieee.std_logic_1164.all; 
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;

library work;
use work.ipbus.all;
use work.axi.all;


entity ipbus_amc13_daq_link is
  port (
    clk       : in  std_logic;          -- ipbus clock
    reset     : in  std_logic;          -- ipbus reset
    ipbus_in  : in  ipb_wbus;           -- fabric bus in
    ipbus_out : out ipb_rbus;          -- fabric bus out
    daq_valid : out std_logic;
    daq_header : out std_logic;
    daq_trailer : out std_logic;
    daq_data : out std_logic_vector(63 downto 0);
    daq_ready : in std_logic
  );

end entity;

architecture rtl of ipbus_amc13_daq_link is

  signal write_success: std_logic := '0';
  signal write_header: std_logic := '0';
  signal write_trailer: std_logic := '0';
  signal write_data: std_logic := '0';

  signal do_write: std_logic;
  signal ack: std_logic;
  signal sel: integer;
  signal header, trailer, data : std_logic;

begin  -- architecture ipbus_amc13_daq_link

  sel <= to_integer(unsigned(ipbus_in.ipb_addr(1 downto 0)));
  do_write <= ipbus_in.ipb_strobe and ipbus_in.ipb_write;

  header <= '1' when sel = 0 else '0';
  data <= '1' when sel = 1 else '0';
  trailer <= '1' when sel = 2 else '0';

  write_header <= do_write and header;
  write_data <= do_write and data;
  write_trailer <= do_write and trailer;

  write_success <= do_write and daq_ready;

  daq_header <= write_header;
  daq_valid <= write_data;
  daq_trailer <= write_trailer;

  daq_data <= X"00000000" & ipbus_in.ipb_wdata;

  ack <= write_success;
  ipbus_out.ipb_ack <= ack;
  ipbus_out.ipb_err <= '0';


end architecture;
