library ieee;
use ieee.std_logic_1164.all;
use work.ipbus.all;

type axi_stream is record               -- Master-contolled lines in AXI4-Stream protocol
                     tvalid : std_logic;
                     tdata  : std_logic_vector(31 downto 0);
                     tstrb  : std_logic_vector(3 downto 0);
                     tkeep  : std_logic_vector(3 downto 0);
                     tlast  : std_logic;
                     tid    : std_logic_vector(3 downto 0);  -- Source ID
                     tdest  : std_logic_vector(3 downto 0);  -- Destination ID
                   end record axi_stream;


entity ipbus_axi_stream is
  
  port (
    clk       : in  std_logic;          -- ipbus clock
    reset     : in  std_logic;          -- ipbus reset
    ipbus_in  : in  ipb_wbus;           -- fabric bus in
    ipbus_out : out ipb_rbus;          -- fabric bus out
    axi_str_in : in axi_stream;
    axi_str_in_tready: out std_logic;
    axi_str_out: out axi_stream;
    ax_str_out_tready: in std_logic;
  )

end entity ipbus_axi_stream;

architecture ipbus_axi_stream of ipbus_axi_stream is

  signal write_success: std_logic := '0';
  signal do_write: std_logic;
  signal do_read: std_logic;

begin  -- architecture ipbus_axi_stream

  do_write <= ipbus_in.ipb_strobe='1' and ipbus_in.ipb_write='1';
  do_read <= ipbus_in.ipb_strobe='1' and ipbus_in.ipb_write='0';

  axi_str_out.tlast <= axi_str_out.tvalid;

  process(clk)
    begin
      if rising_edge(clk) then
        if reset='1' then
          axi_str_out.tvalid <= '0';
          axi_str_in_tready <= '0';
        else
          if do_write='1' then
            axi_str_out.tdata <= ipbus_in.ipb_wdata;
            axi_str_out.tvalid <= '1';
          elsif do_read='1' then
            axi_str_in_tready <= '1';
          end if;
          
          if write_success='1' and do_write='0' then
            -- finished writing, no new write
            axi_str_out.tvalid <= '0';
          end if;

          if read_success='1' and do_read='0' then
            -- finished reading, no new read
            axi_str_in_tready <= '0';
          end if;
        end if; -- reset
        
    end process;

    write_success <= axi_str_out.tvalid and axi_str_out_tready;
    read_success <= axi_str_in.tvalid and axi_str_in_tready;

    ipbus_out.ipb_rdata <= axi_str_in.tdata;

    ipbus_out.ipb_ack <= write_success or read_success;

end architecture ipbus_axi_stream;
