-- Top-level design for ipbus demo
--
-- You must edit this file to set the IP and MAC addresses
--
-- Dave Newbold, 16/7/12

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use work.ipbus.ALL;

library unisim;
use unisim.VComponents.all;

entity ipbus_top is port(
	gt_clkp, gt_clkn: in std_logic;
	gt_txp, gt_txn: out std_logic;
	gt_rxp, gt_rxn: in std_logic;
	sfp_los: in std_logic;
	rst_out: out std_logic;
	debug: out std_logic_vector(5 downto 0);
	
	-- clocks
	clk_200: in std_logic;
	ipb_clk: in std_logic;
	clk_125: out std_logic -- generated by tranceiver
	);

end ipbus_top;

architecture rtl of ipbus_top is

	signal clk_125_int: std_logic;
	signal eth_locked, eth_link: std_logic;
	signal eth_debug: std_logic_vector(2 downto 0);
	signal rst_125, rst_ipb, rst_eth: std_logic;
	signal mac_tx_data, mac_rx_data: std_logic_vector(7 downto 0);
	signal mac_tx_valid, mac_tx_last, mac_tx_error, mac_tx_ready, mac_rx_valid, mac_rx_last, mac_rx_error: std_logic;
	signal ipb_master_out : ipb_wbus;
	signal ipb_master_in : ipb_rbus;
	signal mac_addr: std_logic_vector(47 downto 0);
	signal ip_addr: std_logic_vector(31 downto 0);
	signal pkt_rx, pkt_tx, pkt_rx_led, pkt_tx_led, sys_rst: std_logic;	
	signal gtrefclk_out: std_logic;
	signal gtrefclk_buf: std_logic;

begin

	-- propagate reset to the rest of the design
	rst_out <= sys_rst;

	buf: BUFG
		port map(
			I => gtrefclk_out,
			O => gtrefclk_buf
		);

	-- debug ports
	debug(0) <= gtrefclk_buf;
	debug(1) <= eth_locked;
	debug(2) <= eth_link;
	debug(5 downto 3) <= eth_debug;

	rst_125 <= sys_rst;
	rst_ipb <= sys_rst;
	rst_eth <= sys_rst;

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
			rsti => rst_eth,
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
			link_status => eth_link,
			debug => eth_debug
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
	ip_addr <= X"c0a820b7"; -- 192.168.32.50

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
		debug => open
	);

end rtl;

