library ieee;
use ieee.std_logic_1164.all; 
use ieee.numeric_std.all;

library work;
use work.ipbus.all;
use work.axi.all;


entity ipbus_axi_stream is
  
  port (
    clk       : in  std_logic;          -- ipbus clock
    reset     : in  std_logic;          -- ipbus reset
    ipbus_in  : in  ipb_wbus;           -- fabric bus in
    ipbus_out : out ipb_rbus;          -- fabric bus out
    axi_str_in : in axi_stream;
    axi_str_in_tready: out std_logic;
    axi_str_out: out axi_stream;
    axi_str_out_tready: in std_logic
  );

end entity;

architecture rtl of ipbus_axi_stream is

  signal write_success: std_logic := '0';
  signal read_success: std_logic := '0';
  signal do_write: std_logic;
  signal do_read: std_logic;

begin  -- architecture ipbus_axi_stream

  do_write <= ipbus_in.ipb_strobe and ipbus_in.ipb_write;
  do_read <= ipbus_in.ipb_strobe and not ipbus_in.ipb_write;

  axi_str_out.tlast <= do_write;
  axi_str_out.tvalid <= do_write;
  axi_str_in_tready <= do_read;

  write_success <= do_write and axi_str_out_tready;
  read_success <= axi_str_in.tvalid and do_read;

  ipbus_out.ipb_rdata <= axi_str_in.tdata;
  axi_str_out.tdata <= ipbus_in.ipb_wdata;

  ipbus_out.ipb_ack <= write_success or read_success;

end architecture;
