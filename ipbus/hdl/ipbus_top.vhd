-- Top-level design for ipbus demo
--
-- You must edit this file to set the IP and MAC addresses
--
-- Dave Newbold, 16/7/12

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use work.ipbus.ALL;
use work.axi.all;

library unisim;
use unisim.VComponents.all;

entity ipbus_top is port(
	gt_clkp, gt_clkn: in std_logic;
	gt_txp, gt_txn: out std_logic;
	gt_rxp, gt_rxn: in std_logic;
	sfp_los: in std_logic;
	rst_out: out std_logic;
	eth_link_status: out std_logic;

	-- "user_ipb" interface
    user_ipb_clk           : out std_logic;                       -- programming clock
    user_ipb_strobe     : out std_logic;                       -- this ipb space is selected for an I/O operation 
    user_ipb_addr   : out std_logic_vector(31 downto 0);   -- slave address, memory or register
    user_ipb_write       : out std_logic;		                -- this is a write operation
    user_ipb_wdata : out std_logic_vector(31 downto 0);	-- data to write for write operations
    user_ipb_rdata : in std_logic_vector(31 downto 0);	-- data returned for read operations
    user_ipb_ack          : in std_logic;			            -- 'write' data has been stored, 'read' data is ready
    user_ipb_err           : in std_logic;			            -- '1' if error, '0' if OK?	
        
    axi_stream_in_tvalid : in std_logic;
    axi_stream_in_tdata : in std_logic_vector(31 downto 0);
    axi_stream_in_tstrb  : in std_logic_vector(3 downto 0);
    axi_stream_in_tkeep  : in std_logic_vector(3 downto 0);
    axi_stream_in_tlast  : in std_logic;
    axi_stream_in_tid    : in std_logic_vector(3 downto 0);
    axi_stream_in_tdest  : in std_logic_vector(3 downto 0);
    axi_stream_in_tready : out std_logic;

    axi_stream_out_tvalid : out std_logic;
    axi_stream_out_tdata : out std_logic_vector(31 downto 0);
    axi_stream_out_tstrb  : out std_logic_vector(3 downto 0);
    axi_stream_out_tkeep  : out std_logic_vector(3 downto 0);
    axi_stream_out_tlast  : out std_logic;
    axi_stream_out_tid    : out std_logic_vector(3 downto 0);
    axi_stream_out_tdest  : out std_logic_vector(3 downto 0);
    axi_stream_out_tready : in std_logic;

    --DAQ Link
    daq_valid : out std_logic;
    daq_header : out std_logic;
    daq_trailer : out std_logic;
    daq_data : out std_logic_vector(63 downto 0);
    daq_ready : in std_logic;
    daq_almost_full : in std_logic;

    --trigger
    trigger_out : out std_logic;
	
	-- clocks
	clk_200: in std_logic;
	ipb_clk: in std_logic;
	clk_125: out std_logic; -- generated by tranceiver
	gtrefclk_out: out std_logic;

	debug: out std_logic_vector(7 downto 0)
	);

end ipbus_top;

architecture rtl of ipbus_top is

	signal clk_125_int: std_logic;
	signal rst_125, rst_ipb, rst_200: std_logic;
	signal mac_tx_data, mac_rx_data: std_logic_vector(7 downto 0);
	signal mac_tx_valid, mac_tx_last, mac_tx_error, mac_tx_ready, mac_rx_valid, mac_rx_last, mac_rx_error: std_logic;
	signal ipb_master_out : ipb_wbus;
	signal ipb_master_in : ipb_rbus;
	signal mac_addr: std_logic_vector(47 downto 0);
	signal ip_addr: std_logic_vector(31 downto 0);
	signal pkt_rx, pkt_tx, pkt_rx_led, pkt_tx_led, sys_rst: std_logic;	
	signal eth_phy_status_vector: std_logic_vector(15 downto 0);
    signal axi_stream_in: axi_stream;
    signal axi_stream_out: axi_stream;

    signal eth_locked: std_logic;

begin

	-- propagate reset to the rest of the design
	rst: entity work.ipbus_reset
		port map(
			clk_ipb => ipb_clk,
			clk_125 => clk_125_int,
			clk_200 => clk_200,
			rst_in => sys_rst,
			rst_ipb => rst_ipb,
			rst_125 => rst_125,
			rst_200 => rst_200
			);

	rst_out <= rst_ipb;

	clk_125 <= clk_125_int;
	
	
-- Ethernet MAC core and PHY interface
	
	eth: entity work.eth_k7_1000basex
		port map(
			gt_clkp => gt_clkp,
			gt_clkn => gt_clkn,
			gt_txp => gt_txp,
			gt_txn => gt_txn,
			gt_rxp => gt_rxp,
			gt_rxn => gt_rxn,
			sig_detn => sfp_los,
			clk200_bufg_in => clk_200,
			gtrefclk_out => gtrefclk_out,
			clk125_out => clk_125_int,
			phy_rst => '0',
			mac_rst => rst_125,
			locked => eth_locked,
			tx_data => mac_tx_data,
			tx_valid => mac_tx_valid,
			tx_last => mac_tx_last,
			tx_error => mac_tx_error,
			tx_ready => mac_tx_ready,
			rx_data => mac_rx_data,
			rx_valid => mac_rx_valid,
			rx_last => mac_rx_last,
			rx_error => mac_rx_error,
			link_status => eth_link_status,
			phy_status_vector => eth_phy_status_vector
		);
	
-- ipbus control logic

	ipbus: entity work.ipbus_ctrl
		port map(
			mac_clk => clk_125_int,
			rst_macclk => rst_125,
			ipb_clk => ipb_clk,
			rst_ipb => rst_ipb,
			mac_rx_data => mac_rx_data,
			mac_rx_valid => mac_rx_valid,
			mac_rx_last => mac_rx_last,
			mac_rx_error => mac_rx_error,
			mac_tx_data => mac_tx_data,
			mac_tx_valid => mac_tx_valid,
			mac_tx_last => mac_tx_last,
			mac_tx_error => mac_tx_error,
			mac_tx_ready => mac_tx_ready,
			ipb_out => ipb_master_out,
			ipb_in => ipb_master_in,
			mac_addr => mac_addr,
			ip_addr => ip_addr,
			pkt_rx => pkt_rx,
			pkt_tx => pkt_tx,
			pkt_rx_led => pkt_rx_led,
			pkt_tx_led => pkt_tx_led
		);
		
	mac_addr <= X"020ddba11583"; -- Careful here, arbitrary addresses do not always work
	ip_addr <= X"c0a81a32"; -- 192.168.26.50

-- ipbus slaves live in the entity below, and can expose top-level ports
-- The ipbus fabric is instantiated within.

	slaves: entity work.slaves port map(
		ipb_clk => ipb_clk,
		ipb_rst => rst_ipb,
		ipb_in => ipb_master_out,
		ipb_out => ipb_master_in,
		rst_out => sys_rst,
		pkt_rx => pkt_rx,
		pkt_tx => pkt_tx,
		eth_phy_rudi_invalid => eth_phy_status_vector(4),
		eth_phy_rxdisperr => eth_phy_status_vector(5),
		eth_phy_rxnotintable => eth_phy_status_vector(6),
		-- "user_ipb" interface
        user_ipb_clk => user_ipb_clk,           -- programming clock
        user_ipb_strobe => user_ipb_strobe,     -- this ipb space is selected for an I/O operation 
        user_ipb_addr => user_ipb_addr,         -- slave address, memory or register
        user_ipb_write => user_ipb_write,       -- this is a write operation
        user_ipb_wdata => user_ipb_wdata,       -- data to write for write operations
        user_ipb_rdata => user_ipb_rdata,       -- data returned for read operations
        user_ipb_ack => user_ipb_ack,           -- 'write' data has been stored, 'read' data is ready
        user_ipb_err => user_ipb_err,           -- '1' if error, '0' if OK?
	    axi_stream_in => axi_stream_in,
	    axi_stream_in_tready => axi_stream_in_tready,
	    axi_stream_out => axi_stream_out,
	    axi_stream_out_tready => axi_stream_out_tready,
	    daq_valid => daq_valid,
	    daq_header => daq_header,
	    daq_trailer => daq_trailer,
	    daq_data => daq_data,
	    daq_ready => daq_ready,
	    daq_almost_full => daq_almost_full,
	    trigger_out => trigger_out,
	    debug => debug
	);

	-- break out axi signals
	axi_stream_in.tvalid  <= axi_stream_in_tvalid;
    axi_stream_in.tdata <=  axi_stream_in_tdata ;
    axi_stream_in.tstrb  <= axi_stream_in_tstrb ;
    axi_stream_in.tkeep  <= axi_stream_in_tkeep ;
    axi_stream_in.tlast  <= axi_stream_in_tlast ;
    axi_stream_in.tid  <= axi_stream_in_tid   ;
    axi_stream_in.tdest <=  axi_stream_in_tdest ;

    axi_stream_out_tvalid <= axi_stream_out.tvalid;
    axi_stream_out_tdata <= axi_stream_out.tdata;
    axi_stream_out_tstrb  <= axi_stream_out.tstrb;
    axi_stream_out_tkeep  <= axi_stream_out.tkeep;
    axi_stream_out_tlast  <= axi_stream_out.tlast;
    axi_stream_out_tid    <= axi_stream_out.tid;
    axi_stream_out_tdest  <= axi_stream_out.tdest;
end rtl;

