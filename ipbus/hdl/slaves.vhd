-- The ipbus slaves live in this entity - modify according to requirements
--
-- Ports can be added to give ipbus slaves access to the chip top level.
--
-- Dave Newbold, February 2011

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use work.ipbus.ALL;
use work.axi.all;

entity slaves is
	port(
		ipb_clk: in std_logic;
		ipb_rst: in std_logic;
		ipb_in: in ipb_wbus;
		ipb_out: out ipb_rbus;
		rst_out: out std_logic;

		-- counters
		pkt_rx: in std_logic := '0';
		pkt_tx: in std_logic := '0';
		eth_phy_rudi_invalid: in std_logic := '0';
		eth_phy_rxdisperr: in std_logic := '0';
		eth_phy_rxnotintable: in std_logic := '0';

		-- status registers

	    axi_stream_in: in axi_stream;
	    axi_stream_in_tready: out std_logic;
	    axi_stream_out: out axi_stream;
	    axi_stream_out_tready: in std_logic
	);

end slaves;

architecture rtl of slaves is

	constant NSLV: positive := 6;
	signal ipbw: ipb_wbus_array(NSLV-1 downto 0);
	signal ipbr, ipbr_d: ipb_rbus_array(NSLV-1 downto 0);
	signal ctrl_reg: std_logic_vector(31 downto 0);
	signal stat_reg: std_logic_vector(31 downto 0);
	signal count: std_logic_vector(7 downto 0);

begin

  fabric: entity work.ipbus_fabric
    generic map(NSLV => NSLV)
    port map(
      ipb_in => ipb_in,
      ipb_out => ipb_out,
      ipb_to_slaves => ipbw,
      ipb_from_slaves => ipbr
    );

-- Slave 0: status register

	slave0: entity work.ipbus_status_reg
		generic map(addr_width => 0)
		port map(
			clk => ipb_clk,
			reset => ipb_rst,
			ipbus_in => ipbw(0),
			ipbus_out => ipbr(0),
			d => stat_reg
		);

		stat_reg <= X"DEADBEEF";
		

-- Slave 1: register

	slave1: entity work.ipbus_reg
		generic map(addr_width => 0)
		port map(
			clk => ipb_clk,
			reset => ipb_rst,
			ipbus_in => ipbw(1),
			ipbus_out => ipbr(1),
			q => ctrl_reg
		);

		rst_out <= ctrl_reg(0);

-- Slave 2: 1kword RAM

	slave2: entity work.ipbus_ram
		generic map(addr_width => 10)
		port map(
			clk => ipb_clk,
			reset => ipb_rst,
			ipbus_in => ipbw(2),
			ipbus_out => ipbr(2)
		);

-- Slave 3: peephole RAM

	slave3: entity work.ipbus_peephole_ram
		generic map(addr_width => 10)
		port map(
			clk => ipb_clk,
			reset => ipb_rst,
			ipbus_in => ipbw(3),
			ipbus_out => ipbr(3)
		);

-- Slave 4: packet counters

	slave4: entity work.ipbus_counters
		generic map(addr_width => 3)
		port map(
			clk => ipb_clk,
			reset => ipb_rst,
			ipbus_in => ipbw(4),
			ipbus_out => ipbr(4),
			count => count
		);

	count(0) <= pkt_tx;
	count(1) <= pkt_rx;
	count(2) <= eth_phy_rudi_invalid;
	count(3) <= eth_phy_rxdisperr;
	count(4) <= eth_phy_rxnotintable;
	count_gen: for i in 7 downto 5 generate
		count(i) <= '0';
	end generate;

-- slave 5: AXI4-stream interface to Aurora IP
	  slave5: entity work.ipbus_axi_stream
	  generic map(
	    id => 0,
	    dest => 0
	  )
	  port map(
	    clk => ipb_clk,
	    reset => ipb_rst,
	    ipbus_in => ipbw(5),
	    ipbus_out => ipbr(5),
	    axi_str_in => axi_stream_in,
	    axi_str_in_tready => axi_stream_in_tready,
	    axi_str_out => axi_stream_out,
	    axi_str_out_tready => axi_stream_out_tready
	  );

end rtl;
