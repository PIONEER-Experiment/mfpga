----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    10:14:48 04/20/2014 
-- Design Name: 
-- Module Name:    DAQ_LINK - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.std_logic_misc.all;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
library UNISIM;
use UNISIM.VComponents.all;
Library UNIMACRO;
use UNIMACRO.vcomponents.all;

entity DAQ_LINK_Kintex is
		Generic (
-- REFCLK frequency, select one among 100, 125, 200 and 250
-- If your REFCLK frequency is not in the list, please contact wusx@bu.edu
					 F_REFCLK	: integer	:= 125;
					 SYSCLK_IN_period : integer := 10; -- unit is ns
-- If you do not use the trigger port, set it to false
					 USE_TRIGGER_PORT : boolean := true;
					 simulation : boolean := false);
    Port ( 
           reset : in  STD_LOGIC; -- asynchronous reset, assert reset until GTX REFCLK stable
-- GTX signals
           GTX_REFCLK : in  STD_LOGIC;
           GTX_RXN : in  STD_LOGIC;
           GTX_RXP : in  STD_LOGIC;
           GTX_TXN : out  STD_LOGIC;
           GTX_TXP : out  STD_LOGIC;
-- TRIGGER port
           TTCclk : in  STD_LOGIC;
           BcntRes : in  STD_LOGIC;
           trig : in  STD_LOGIC_VECTOR (7 downto 0);
-- TTS port
           TTSclk : in  STD_LOGIC; -- clock source which clocks TTS signals
           TTS : in  STD_LOGIC_VECTOR (3 downto 0);
-- SYSCLK_IN is required by the GTX ip core, you can connect any clock source(e.g. TTSclk, TTCclk or EventDataClk) as long as its period is in the range of 8-250ns
-- do not forget to specify its period in the generic port
           SYSCLK_IN : in  STD_LOGIC;
-- Data port
					 EventDataClk : in  STD_LOGIC;
           EventData_valid : in  STD_LOGIC; -- used as data write enable
           EventData_header : in  STD_LOGIC; -- first data word
           EventData_trailer : in  STD_LOGIC; -- last data word
           EventData : in  STD_LOGIC_VECTOR (63 downto 0);
           AlmostFull : out  STD_LOGIC; -- buffer almost full
           Ready : out  STD_LOGIC);
end DAQ_LINK_Kintex;

architecture Behavioral of DAQ_LINK_Kintex is
COMPONENT DAQ_Link_7S
		Generic (
					 simulation : boolean := false);
	PORT(
		reset : IN std_logic;
		USE_TRIGGER_PORT : boolean;
		UsrClk : IN std_logic;
		cplllock : IN std_logic;
		RxResetDone : IN std_logic;
		txfsmresetdone : IN std_logic;
		RXNOTINTABLE : IN std_logic_vector(1 downto 0);
		RXCHARISCOMMA : IN std_logic_vector(1 downto 0);
		RXCHARISK : IN std_logic_vector(1 downto 0);
		RXDATA : IN std_logic_vector(15 downto 0);
		TTCclk : IN std_logic;
		BcntRes : IN std_logic;
		trig : IN std_logic_vector(7 downto 0);
		TTSclk : IN std_logic;
		TTS : IN std_logic_vector(3 downto 0);
		EventDataClk : IN std_logic;
		EventData_valid : IN std_logic;
		EventData_header : IN std_logic;
		EventData_trailer : IN std_logic;
		EventData : IN std_logic_vector(63 downto 0);          
		TXCHARISK : OUT std_logic_vector(1 downto 0);
		TXDATA : OUT std_logic_vector(15 downto 0);
		AlmostFull : OUT std_logic;
		Ready : OUT std_logic;
		sysclk : in  STD_LOGIC;
		L1A_DATA_we : out  STD_LOGIC; -- last data word
		L1A_DATA : out  STD_LOGIC_VECTOR (15 downto 0)
		);
end COMPONENT;
COMPONENT DAQLINK_7S_init
generic
(
    EXAMPLE_SIM_GTRESET_SPEEDUP             : string    := "TRUE";          -- simulation setting for GT SecureIP model
    EXAMPLE_SIMULATION                      : integer   := 0;               -- Set to 1 for simulation
    STABLE_CLOCK_PERIOD                     : integer   := 16;               --Period of the stable clock driving this state-machine, unit is [ns]
    EXAMPLE_USE_CHIPSCOPE                   : integer   := 0;                -- Set to 1 to use Chipscope to drive resets
		-- REFCLK frequency, select one among 100, 125, 200 and 250 If your REFCLK frequency is not in the list, please contact wusx@bu.edu
		F_REFCLK																: integer		 := 125

);
	PORT(
		SYSCLK_IN : IN std_logic;
		SOFT_RESET_IN : IN std_logic;
		DONT_RESET_ON_DATA_ERROR_IN : IN std_logic;
		GT0_DATA_VALID_IN : IN std_logic;
		GT0_CPLLLOCKDETCLK_IN : IN std_logic;
		GT0_CPLLRESET_IN : IN std_logic;
		GT0_GTREFCLK0_IN : IN std_logic;
		GT0_DRPADDR_IN : IN std_logic_vector(8 downto 0);
		GT0_DRPCLK_IN : IN std_logic;
		GT0_DRPDI_IN : IN std_logic_vector(15 downto 0);
		GT0_DRPEN_IN : IN std_logic;
		GT0_DRPWE_IN : IN std_logic;
		GT0_LOOPBACK_IN : IN std_logic_vector(2 downto 0);
		GT0_RXUSERRDY_IN : IN std_logic;
		GT0_RXUSRCLK_IN : IN std_logic;
		GT0_RXUSRCLK2_IN : IN std_logic;
		GT0_RXPRBSSEL_IN : IN std_logic_vector(2 downto 0);
		GT0_RXPRBSCNTRESET_IN : IN std_logic;
		GT0_GTXRXP_IN : IN std_logic;
		GT0_GTXRXN_IN : IN std_logic;
		GT0_RXMCOMMAALIGNEN_IN : IN std_logic;
		GT0_RXPCOMMAALIGNEN_IN : IN std_logic;
		GT0_GTRXRESET_IN : IN std_logic;
		GT0_RXPMARESET_IN : IN std_logic;
		GT0_GTTXRESET_IN : IN std_logic;
		GT0_TXUSERRDY_IN : IN std_logic;
		GT0_TXUSRCLK_IN : IN std_logic;
		GT0_TXUSRCLK2_IN : IN std_logic;
		GT0_TXDIFFCTRL_IN : IN std_logic_vector(3 downto 0);
		GT0_TXDATA_IN : IN std_logic_vector(15 downto 0);
		GT0_TXCHARISK_IN : IN std_logic_vector(1 downto 0);
		GT0_TXPRBSSEL_IN : IN std_logic_vector(2 downto 0);
		GT0_GTREFCLK0_COMMON_IN : IN std_logic;
		GT0_QPLLLOCKDETCLK_IN : IN std_logic;
		GT0_QPLLRESET_IN : IN std_logic;          
		GT0_TX_FSM_RESET_DONE_OUT : OUT std_logic;
		GT0_RX_FSM_RESET_DONE_OUT : OUT std_logic;
		GT0_CPLLFBCLKLOST_OUT : OUT std_logic;
		GT0_CPLLLOCK_OUT : OUT std_logic;
		GT0_DRPDO_OUT : OUT std_logic_vector(15 downto 0);
		GT0_DRPRDY_OUT : OUT std_logic;
		GT0_EYESCANDATAERROR_OUT : OUT std_logic;
		GT0_RXCDRLOCK_OUT : OUT std_logic;
		GT0_RXCLKCORCNT_OUT : OUT std_logic_vector(1 downto 0);
		GT0_RXDATA_OUT : OUT std_logic_vector(15 downto 0);
		GT0_RXPRBSERR_OUT : OUT std_logic;
		GT0_RXDISPERR_OUT : OUT std_logic_vector(1 downto 0);
		GT0_RXNOTINTABLE_OUT : OUT std_logic_vector(1 downto 0);
		GT0_RXCHARISCOMMA_OUT : OUT std_logic_vector(1 downto 0);
		GT0_RXCHARISK_OUT : OUT std_logic_vector(1 downto 0);
		GT0_RXRESETDONE_OUT : OUT std_logic;
		GT0_GTXTXN_OUT : OUT std_logic;
		GT0_GTXTXP_OUT : OUT std_logic;
		GT0_TXOUTCLK_OUT : OUT std_logic;
		GT0_TXOUTCLKFABRIC_OUT : OUT std_logic;
		GT0_TXOUTCLKPCS_OUT : OUT std_logic;
		GT0_TXRESETDONE_OUT : OUT std_logic;
		GT0_QPLLLOCK_OUT : OUT std_logic
		);
END COMPONENT;
function GTXRESET_SPEEDUP(is_sim : boolean) return string is
	begin
		if(is_sim)then
			return "TRUE";
		else
			return "FALSE";
		end if;
	end function;
signal UsrClk : std_logic := '0';
signal cplllock : std_logic := '0';
signal TXOUTCLK : std_logic := '0';
signal RxResetDone : std_logic := '0';
signal txfsmresetdone : std_logic := '0';
signal LoopBack : std_logic_vector(2 downto 0) := (others => '0');
signal K_Cntr : std_logic_vector(7 downto 0) := (others => '0');
signal reset_SyncRegs : std_logic_vector(3 downto 0) := (others => '0');
signal RxResetDoneSyncRegs : std_logic_vector(2 downto 0) := (others => '0');
signal DATA_VALID : std_logic := '0';
signal RXNOTINTABLE : std_logic_vector(1 downto 0) := (others => '0');
signal RXCHARISCOMMA : std_logic_vector(1 downto 0) := (others => '0');
signal RXCHARISK : std_logic_vector(1 downto 0) := (others => '0');
signal RXDATA : std_logic_vector(15 downto 0) := (others => '0');
signal TXDIFFCTRL : std_logic_vector(3 downto 0) := x"b"; -- 790mV drive
signal TXCHARISK : std_logic_vector(1 downto 0) := (others => '0');
signal TXDATA : std_logic_vector(15 downto 0) := (others => '0');
begin
i_DAQ_Link_7S : DAQ_Link_7S
		generic map(simulation => simulation)
		PORT MAP (
          reset => reset,
					USE_TRIGGER_PORT => USE_TRIGGER_PORT,
					UsrClk => UsrClk,
					cplllock => cplllock,
					RxResetDone => RxResetDone,
					txfsmresetdone => txfsmresetdone,
					RXNOTINTABLE => RXNOTINTABLE,
					RXCHARISCOMMA => RXCHARISCOMMA,
					RXCHARISK => RXCHARISK,
					RXDATA => RXDATA,
					TXCHARISK => TXCHARISK,
					TXDATA => TXDATA,
          TTCclk => TTCclk,
          BcntRes => BcntRes,
          trig => trig,
          TTSclk => TTSclk,
          TTS => TTS,
          EventDataClk => EventDataClk,
          EventData_valid => EventData_valid,
          EventData_header => EventData_header,
          EventData_trailer => EventData_trailer,
          EventData => EventData,
          AlmostFull => AlmostFull,
          Ready => Ready,
					sysclk => '0',
          L1A_DATA => open,
          L1A_DATA_we => open
        );
process(UsrClk,RxResetDone)
begin
	if(RxResetDone = '0')then
		RxResetDoneSyncRegs <= (others => '0');
	elsif(UsrClk'event and UsrClk = '1')then
		RxResetDoneSyncRegs <= RxResetDoneSyncRegs(1 downto 0) & '1';
	end if;
end process;
process(UsrClk,reset,RxResetDone,txfsmresetdone,cplllock)
begin
	if(reset = '1' or RXRESETDONE = '0' or txfsmresetdone = '0' or cplllock = '0')then
		reset_SyncRegs <= (others => '1');
	elsif(UsrClk'event and UsrClk = '1')then
		reset_SyncRegs <= reset_SyncRegs(2 downto 0) & '0';
	end if;
end process;
process(UsrClk)
begin
	if(UsrClk'event and UsrClk = '1')then
		if(RXCHARISK = "11" and RXDATA = x"3cbc")then
			DATA_VALID <= '1';
		elsif(RxResetDoneSyncRegs(2) = '0' or or_reduce(RXNOTINTABLE) = '1' or K_Cntr(7) = '1')then
			DATA_VALID <= '0';
		end if;
		if((RXCHARISK = "11" and RXDATA = x"3cbc"))then
			K_Cntr <= (others => '0');
		else
			K_Cntr <= K_Cntr + 1;
		end if;
	end if;
end process;
i_DAQLINK_7S_init : DAQLINK_7S_init
    generic map
    (
        EXAMPLE_SIM_GTRESET_SPEEDUP     =>      GTXRESET_SPEEDUP(simulation),
        EXAMPLE_SIMULATION              =>      0,
        STABLE_CLOCK_PERIOD             =>      sysclk_in_period,
        EXAMPLE_USE_CHIPSCOPE           =>      0,
				F_REFCLK												=>			F_REFCLK
    )
    port map
    (
        SYSCLK_IN                       =>      SYSCLK_IN,
        SOFT_RESET_IN                   =>      '0',
        DONT_RESET_ON_DATA_ERROR_IN     =>      '0',
        GT0_TX_FSM_RESET_DONE_OUT       =>      txfsmresetdone,
        GT0_RX_FSM_RESET_DONE_OUT       =>      open,
        GT0_DATA_VALID_IN               =>      DATA_VALID,

  
 
 
 
        --_____________________________________________________________________
        --_____________________________________________________________________
        --GT0  (X1Y0)

        --------------------------------- CPLL Ports -------------------------------
        GT0_CPLLFBCLKLOST_OUT           =>      open,
        GT0_CPLLLOCK_OUT                =>      cplllock,
        GT0_CPLLLOCKDETCLK_IN           =>      sysclk_in,
        GT0_CPLLRESET_IN                =>      reset,
        -------------------------- Channel - Clocking Ports ------------------------
        GT0_GTREFCLK0_IN                =>      GTX_REFCLK,
        ---------------------------- Channel - DRP Ports  --------------------------
        GT0_DRPADDR_IN                  =>      (others => '0'),
        GT0_DRPCLK_IN                   =>      sysclk_in,
        GT0_DRPDI_IN                    =>      (others => '0'),
        GT0_DRPDO_OUT                   =>      open,
        GT0_DRPEN_IN                    =>      '0',
        GT0_DRPRDY_OUT                  =>      open,
        GT0_DRPWE_IN                    =>      '0',
        ------------------------------- Loopback Ports -----------------------------
        GT0_LOOPBACK_IN                 =>      LOOPBACK,
        --------------------- RX Initialization and Reset Ports --------------------
        GT0_RXUSERRDY_IN                =>      '0',
        -------------------------- RX Margin Analysis Ports ------------------------
        GT0_EYESCANDATAERROR_OUT        =>      open,
        ------------------------- Receive Ports - CDR Ports ------------------------
        GT0_RXCDRLOCK_OUT               =>      open,
        ------------------ Receive Ports - FPGA RX Interface Ports -----------------
        GT0_RXUSRCLK_IN                 =>      UsRClk,
        GT0_RXUSRCLK2_IN                =>      UsRClk,
        ------------------ Receive Ports - FPGA RX interface Ports -----------------
        GT0_RXDATA_OUT                  =>      RXDATA,
        ------------------- Receive Ports - Pattern Checker Ports ------------------
        GT0_RXPRBSERR_OUT               =>      open,
        GT0_RXPRBSSEL_IN                =>      (others => '0'),
        ------------------- Receive Ports - Pattern Checker ports ------------------
        GT0_RXPRBSCNTRESET_IN           =>      '0',
        ------------------ Receive Ports - RX 8B/10B Decoder Ports -----------------
        GT0_RXDISPERR_OUT               =>      open,
        GT0_RXNOTINTABLE_OUT            =>      RXNOTINTABLE,
        --------------------------- Receive Ports - RX AFE -------------------------
        GT0_GTXRXP_IN                   =>      GTX_RXP,
        ------------------------ Receive Ports - RX AFE Ports ----------------------
        GT0_GTXRXN_IN                   =>      GTX_RXN,
        -------------- Receive Ports - RX Byte and Word Alignment Ports ------------
        GT0_RXMCOMMAALIGNEN_IN          =>      reset_SyncRegs(3),
        GT0_RXPCOMMAALIGNEN_IN          =>      reset_SyncRegs(3),
        ------------- Receive Ports - RX Initialization and Reset Ports ------------
        GT0_GTRXRESET_IN                =>      reset,
        GT0_RXPMARESET_IN               =>      '0',
        ------------------- Receive Ports - RX8B/10B Decoder Ports -----------------
        GT0_RXCHARISCOMMA_OUT           =>      RXCHARISCOMMA,
        GT0_RXCHARISK_OUT               =>      RXCHARISK,
        -------------- Receive Ports -RX Initialization and Reset Ports ------------
        GT0_RXRESETDONE_OUT             =>      RXRESETDONE,
        --------------------- TX Initialization and Reset Ports --------------------
        GT0_GTTXRESET_IN                =>      reset,
        GT0_TXUSERRDY_IN                =>      '0',
        ------------------ Transmit Ports - FPGA TX Interface Ports ----------------
        GT0_TXUSRCLK_IN                 =>      UsRClk,
        GT0_TXUSRCLK2_IN                =>      UsRClk,
        --------------- Transmit Ports - TX Configurable Driver Ports --------------
        GT0_TXDIFFCTRL_IN               =>      TXDIFFCTRL,
        ------------------ Transmit Ports - TX Data Path interface -----------------
        GT0_TXDATA_IN                   =>      TXDATA,
        ---------------- Transmit Ports - TX Driver and OOB signaling --------------
        GT0_GTXTXN_OUT                  =>      GTX_TXN,
        GT0_GTXTXP_OUT                  =>      GTX_TXP,
        ----------- Transmit Ports - TX Fabric Clock Output Control Ports ----------
        GT0_TXOUTCLK_OUT                =>      TXOUTCLK,
        GT0_TXOUTCLKFABRIC_OUT          =>      open,
        GT0_TXOUTCLKPCS_OUT             =>      open,
        --------------------- Transmit Ports - TX Gearbox Ports --------------------
        GT0_TXCHARISK_IN                =>      TXCHARISK,
        ------------- Transmit Ports - TX Initialization and Reset Ports -----------
        GT0_TXRESETDONE_OUT             =>      open,
        ------------------ Transmit Ports - pattern Generator Ports ----------------
        GT0_TXPRBSSEL_IN                =>      "000",




    --____________________________COMMON PORTS________________________________
        ---------------------- Common Block  - Ref Clock Ports ---------------------
        GT0_GTREFCLK0_COMMON_IN         =>      '0',
        ------------------------- Common Block - QPLL Ports ------------------------
        GT0_QPLLLOCK_OUT                =>      open,
        GT0_QPLLLOCKDETCLK_IN           =>      '0',
        GT0_QPLLRESET_IN                =>      '0'

    );
i_UsrClk : BUFG
   port map (
      O => UsrClk,     -- Clock buffer output
      I => TXOUTCLK      -- Clock buffer input
   );
end Behavioral;

