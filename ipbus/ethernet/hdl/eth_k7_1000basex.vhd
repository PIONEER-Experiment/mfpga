-- Contains the instantiation of the Xilinx MAC & 1000baseX pcs/pma & GTP transceiver cores
--
-- Do not change signal names in here without correspondig alteration to the timing contraints file
--
-- Dave Newbold, April 2011

-- Modified by Nic Eggert, Feb 2014
-- Use Mr. Wu's emac instead of Xilinx IP

--
-- $Id$

library ieee;
use ieee.std_logic_1164.all;

library unisim;
use unisim.VComponents.all;
use work.emac_hostbus_decl.all;

entity eth_k7_1000basex is
	port(
		gt_clkp, gt_clkn: in std_logic;
		gt_txp, gt_txn: out std_logic;
		gt_rxp, gt_rxn: in std_logic;
		sig_detn: in std_logic := '1';
		clk200_bufg_in: in std_logic;
		clk125_out: out std_logic;
		rsti: in std_logic;
		locked: out std_logic;
		tx_data: in std_logic_vector(7 downto 0);
		tx_valid: in std_logic;
		tx_last: in std_logic;
		tx_error: in std_logic;
		tx_ready: out std_logic;
		rx_data: out std_logic_vector(7 downto 0);
		rx_valid: out std_logic;
		rx_last: out std_logic;
		rx_error: out std_logic;
		hostbus_in: in emac_hostbus_in := ('0', "00", "0000000000", X"00000000", '0', '0', '0');
		hostbus_out: out emac_hostbus_out
	);

end eth_k7_1000basex;

architecture rtl of eth_k7_1000basex is

	COMPONENT soft_emac
	Port ( reset : in  STD_LOGIC;
           emacphytxd : out  STD_LOGIC_VECTOR (7 downto 0);
           emacphytxen : out  STD_LOGIC;
           emacphytxer : out  STD_LOGIC;
           phyemacrxd : in  STD_LOGIC_VECTOR (7 downto 0);
           phyemacrxdv : in  STD_LOGIC;
           phyemacrxer : in  STD_LOGIC;
           clientemactxd : in  STD_LOGIC_VECTOR (7 downto 0);
           clientemactxdvld : in  STD_LOGIC;
           clientemactxdlast : in  STD_LOGIC;
    	   clientemactxerr: in std_logic;
    	   emacclienttxready: out std_logic;
    	   emacclientrxd: out std_logic_vector(7 downto 0);
    	   emacclientrxdvld: out std_logic;
    	   emacclientrxdlast: out std_logic;
    	   emacclientrxerr: out std_logic;
    	   txgmiimiiclk: in std_logic;
    	   rxgmiimiiclk: in std_logic
          );
	END COMPONENT;
	
	COMPONENT gig_ethernet_pcs_pma_0
  PORT (
    gtrefclk_p : IN STD_LOGIC;
    gtrefclk_n : IN STD_LOGIC;
    gtrefclk_out : OUT STD_LOGIC;
    txn : OUT STD_LOGIC;
    txp : OUT STD_LOGIC;
    rxn : IN STD_LOGIC;
    rxp : IN STD_LOGIC;
    independent_clock_bufg : IN STD_LOGIC;
    userclk_out : OUT STD_LOGIC;
    userclk2_out : OUT STD_LOGIC;
    rxuserclk_out : OUT STD_LOGIC;
    rxuserclk2_out : OUT STD_LOGIC;
    resetdone : OUT STD_LOGIC;
    pma_reset_out : OUT STD_LOGIC;
    mmcm_locked_out : OUT STD_LOGIC;
    gmii_txd : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
    gmii_tx_en : IN STD_LOGIC;
    gmii_tx_er : IN STD_LOGIC;
    gmii_rxd : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
    gmii_rx_dv : OUT STD_LOGIC;
    gmii_rx_er : OUT STD_LOGIC;
    gmii_isolate : OUT STD_LOGIC;
    configuration_vector : IN STD_LOGIC_VECTOR(4 DOWNTO 0);
    status_vector : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
    reset : IN STD_LOGIC;
    signal_detect : IN STD_LOGIC;
    gt0_qplloutclk_out : OUT STD_LOGIC;
    gt0_qplloutrefclk_out : OUT STD_LOGIC
  );
END COMPONENT;
--ATTRIBUTE SYN_BLACK_BOX : BOOLEAN;
--ATTRIBUTE SYN_BLACK_BOX OF gig_ethernet_pcs_pma_0 : COMPONENT IS TRUE;
--ATTRIBUTE BLACK_BOX_PAD_PIN : STRING;
--ATTRIBUTE BLACK_BOX_PAD_PIN OF gig_ethernet_pcs_pma_0 : COMPONENT IS "gtrefclk_p,gtrefclk_n,gtrefclk_out,txn,txp,rxn,rxp,independent_clock_bufg,userclk_out,userclk2_out,rxuserclk_out,rxuserclk2_out,resetdone,pma_reset_out,mmcm_locked_out,gmii_txd[7:0],gmii_tx_en,gmii_tx_er,gmii_rxd[7:0],gmii_rx_dv,gmii_rx_er,gmii_isolate,configuration_vector[4:0],status_vector[15:0],reset,signal_detect,gt0_qplloutclk_out,gt0_qplloutrefclk_out";
	
	signal gmii_txd, gmii_rxd: std_logic_vector(7 downto 0);
	signal gmii_tx_en, gmii_tx_er, gmii_rx_dv, gmii_rx_er: std_logic;
	signal clk125: std_logic;
	signal mac_rst, phy_done, mmcm_locked, locked_int, sig_det: std_logic;
	signal status: std_logic_vector(15 downto 0);

begin

	clk125_out <= clk125;

	locked_int <= mmcm_locked and phy_done;

	locked <= locked_int;
	mac_rst <= (not locked_int) or rsti;

	mac: soft_emac
		port map(
			reset => mac_rst,
			rxgmiimiiclk => clk125,
			emacclientrxd => rx_data,
			emacclientrxdvld => rx_valid,
			emacclientrxdlast => rx_last,
			emacclientrxerr => rx_error,
			txgmiimiiclk => clk125,
			clientemactxd => tx_data,
			clientemactxdvld => tx_valid,
			clientemactxdlast => tx_last,
			clientemactxerr => tx_error,
			emacclienttxready => tx_ready,
			emacphytxd => gmii_txd,
			emacphytxen => gmii_tx_en,
			emacphytxer => gmii_tx_er,
			phyemacrxd => gmii_rxd,
			phyemacrxdv => gmii_rx_dv,
			phyemacrxer => gmii_rx_er
		);

	hostbus_out.hostrddata <= (others => '0');
	hostbus_out.hostmiimrdy <= '0';

	sig_det <= not sig_detn;

	phy: gig_ethernet_pcs_pma_0
		port map(
			gtrefclk_p => gt_clkp,
			gtrefclk_n => gt_clkn,
			gtrefclk_out => open,
			txp => gt_txp,
			txn => gt_txn,
			rxp => gt_rxp,
			rxn => gt_rxn,
			independent_clock_bufg => clk200_bufg_in,
			userclk_out => open,
			userclk2_out => clk125,
			rxuserclk_out => open,
			rxuserclk2_out => open,
			resetdone => phy_done,
			pma_reset_out => open,
			mmcm_locked_out => mmcm_locked,
			gmii_txd => gmii_txd,
			gmii_tx_en => gmii_tx_en,
			gmii_tx_er => gmii_tx_er,
			gmii_rxd => gmii_rxd,
			gmii_rx_dv => gmii_rx_dv,
			gmii_rx_er => gmii_rx_er,
			gmii_isolate => open,
			configuration_vector => "00010",
			status_vector => status,
			reset => rsti,
			signal_detect => sig_det
		);

end rtl;
