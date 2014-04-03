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
  signal out_valid: std_logic;
  signal in_ready: std_logic;

begin  -- architecture ipbus_axi_stream

  do_write <= ipbus_in.ipb_strobe and ipbus_in.ipb_write;
  do_read <= ipbus_in.ipb_strobe and not ipbus_in.ipb_write;

  axi_str_out.tlast <= out_valid;
  axi_str_out.tvalid <= out_valid;
  axi_str_in_tready <= in_ready;

  process(clk)
    begin
      if rising_edge(clk) then
        if reset='1' then
          out_valid <= '0';
          in_ready <= '0';
        else
          if do_write='1' then
            axi_str_out.tdata <= ipbus_in.ipb_wdata;
            out_valid <= '1';
          elsif do_read='1' then
            in_ready <= '1';
          end if;
          
          if write_success='1' then
            out_valid <= '0';
          end if;

          if read_success='1' and do_read='0' then
            -- finished reading, no new read
            in_ready <= '0';
          end if;
        end if; -- reset
      end if; -- rising_edge(clk)
    end process;

  write_success <= out_valid and axi_str_out_tready;
  read_success <= axi_str_in.tvalid and in_ready;

  ipbus_out.ipb_rdata <= axi_str_in.tdata;

  ipbus_out.ipb_ack <= write_success or read_success;

end architecture;
