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

entity DAQ_LINK is
		Generic (
-- REFCLK frequency, select one among 100, 125, 200 and 250
-- If your REFCLK frequency is not in the list, please contact wusx@bu.edu
					 F_REFCLK	: integer	:= 250;
					 DRPclk_period : integer := 20; -- unit is ns
-- If you do not use the trigger port, set it to false
--					 USE_TRIGGER_PORT : boolean := true;
					 simulation : boolean := false);
    Port ( sysclk : in  STD_LOGIC;
           DRPclk : in  STD_LOGIC;
           fake_clk : in  STD_LOGIC;
           EventDataClk : in  STD_LOGIC;
           reset : in  STD_LOGIC;
					 USE_TRIGGER_PORT : boolean;
           test : in  STD_LOGIC;
					 ovfl_warning : IN  std_logic;
           ForceError : in  STD_LOGIC_VECTOR (3 downto 0);
           fake_lengthA : in  STD_LOGIC_VECTOR (17 downto 0);
           fake_lengthB : in  STD_LOGIC_VECTOR (17 downto 0);
           fake_seed : in  STD_LOGIC_VECTOR (16 downto 0);
					 event_number_avl : in std_logic;
					 event_number : in std_logic_vector(59 downto 0);
					 board_ID	: in   std_logic_vector(15 downto 0);
					 status : out std_logic_vector(31 downto 0);
           AMC_REFCLK_N : in  STD_LOGIC;
           AMC_REFCLK_P : in  STD_LOGIC;
           AMC_RXN : in  STD_LOGIC;
           AMC_RXP : in  STD_LOGIC;
           AMC_TXN : out  STD_LOGIC;
           AMC_TXP : out  STD_LOGIC;
-- TRIGGER port
           TTCclk : in  STD_LOGIC;
-- TTS port
           TTSclk : in  STD_LOGIC; -- clock source which clocks TTS signals
           TTS : in  STD_LOGIC_VECTOR (3 downto 0)
					 );
end DAQ_LINK;

architecture Behavioral of DAQ_LINK is
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
COMPONENT fake_event
    PORT(
         sysclk : IN  std_logic;
         UsrClk : IN  std_logic;
         reset : IN  std_logic;
				 fifo_rst : IN std_logic;
				 fifo_en : IN std_logic;
         fake_en : IN  std_logic;
         sync : IN  std_logic;
         ovfl_warning : IN  std_logic;
         fake_length : IN  std_logic_vector(17 downto 0);
         LinkFull : IN  std_logic;
				 board_ID	: in   std_logic_vector(15 downto 0);
         L1A_DATA : IN  std_logic_vector(15 downto 0);
         L1A_WrEn : IN  std_logic;
         fake_header : OUT  std_logic;
         fake_CRC : OUT  std_logic;
         empty_event_flag : OUT  std_logic;
         fake_DATA : OUT  std_logic_vector(15 downto 0);
         fake_WrEn : OUT  std_logic
        );
END COMPONENT;
COMPONENT FIFO_RESET_7S
	PORT(
		reset : IN std_logic;
		clk : IN std_logic;          
		fifo_rst : OUT std_logic;
		fifo_en : OUT std_logic
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
signal EventData_valid : std_logic := '0';
signal EventData_header : std_logic := '0';
signal EventData_trailer : std_logic := '0';
signal EventData : std_logic_vector(63 downto 0) := (others => '0');
signal EventDatap : std_logic_vector(63 downto 0) := (others => '0');
signal AlmostFull : std_logic;
signal fakereset : std_logic;
signal Ready : std_logic;
signal AMC_REFCLK : std_logic := '0';
signal toggle : std_logic := '0';
signal toggle_r : std_logic_vector(4 downto 0) := (others => '0');
signal fake_header : std_logic;
signal fake_header_q : std_logic;
signal fake_CRC : std_logic;
signal fake_length : std_logic_vector(17 downto 0);
signal fake_DATA : std_logic_vector(15 downto 0);
signal fake_WrEn : std_logic;
signal sync : std_logic := '1';
signal LinkFull : std_logic := '0';
signal L1A_DATA : std_logic_vector(15 downto 0) := (others => '0');
signal L1A_DATAp : std_logic_vector(15 downto 0) := (others => '0');
signal L1A_DATA_wa : std_logic_vector(3 downto 0) := (others => '0');
signal L1A_DATA_we : std_logic := '0';
signal L1A_WrEn : std_logic := '0';
signal ec_byte_cnt : std_logic := '0';
signal byte_cnt : std_logic_vector(1 downto 0) := (others => '0');
signal ld_data : std_logic := '1';
signal fake_CRC_q : std_logic_vector(1 downto 0) := (others => '0');
signal fifo_rst : std_logic := '0';
signal fifo_en : std_logic := '0';
signal BcntRes : std_logic := '0';
signal trig : std_logic_vector(7 downto 0) := (others => '0');
signal bcnt : std_logic_vector(11 downto 0) := (others => '0');
signal ec_FIFO_RA : std_logic := '0';
signal FIFO_DI : std_logic_vector(17 downto 0) := (others => '0');
signal FIFO_DO : std_logic_vector(71 downto 0) := (others => '0');
signal FIFO_WA : std_logic_vector(10 downto 0) := (others => '0');
signal FIFO_RA : std_logic_vector(8 downto 0) := (others => '0');
signal FIFO_WC : std_logic_vector(8 downto 0) := (others => '0');
signal A : std_logic_vector(29 downto 0) := (others => '0');
signal C : std_logic_vector(47 downto 0) := (others => '0');
signal D : std_logic_vector(24 downto 0) := (others => '0');
signal P : std_logic_vector(47 downto 0) := (others => '0');
signal lfsr : std_logic_vector(17 downto 0) := (others => '0');
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
					sysclk => sysclk,
          L1A_DATA => L1A_DATA,
          L1A_DATA_we => L1A_DATA_we
        );
status(31) <= Ready;
status(30) <= test;
status(29) <= AlmostFull;
status(28 downto 24) <= (others => '0');
status(23 downto 20) <= TTS;
status(19 downto 18) <= (others => '0');
status(17 downto 0) <= fake_length;
process(TTCclk)
begin
	if(TTCclk'event and TTCclk = '1')then
		if(BcntRes = '1')then
			Bcnt <= (others => '0');
		else
			Bcnt <= Bcnt + 1;
		end if;
		if(Bcnt = x"dea")then
			BcntRes <= '1';
		else
			BcntRes <= '0';
		end if;
		Trig <= Trig + 1;
	end if;
end process;
i_fakeFIFO : BRAM_SDP_MACRO
   generic map (
      BRAM_SIZE => "36Kb", -- Target BRAM, "18Kb" or "36Kb" 
      DEVICE => "7SERIES", -- Target device: "VIRTEX5", "VIRTEX6", "SPARTAN6" 
      WRITE_WIDTH => 18,    -- Valid values are 1-72 (37-72 only valid when BRAM_SIZE="36Kb")
      READ_WIDTH => 72)     -- Valid values are 1-72 (37-72 only valid when BRAM_SIZE="36Kb")
    port map (
      DO => FIFO_DO,         -- Output read data port, width defined by READ_WIDTH parameter
      DI => FIFO_DI,         -- Input write data port, width defined by WRITE_WIDTH parameter
      RDADDR => FIFO_RA, -- Input read address, width defined by read port depth
      RDCLK => EventDataClk,   -- 1-bit input read clock
      RDEN => '1',     -- 1-bit input read port enable
      REGCE => '1',   -- 1-bit input read output register enable
      RST => '0',       -- 1-bit input reset 
      WE => "11",         -- Input write enable, width defined by write port depth
      WRADDR => FIFO_WA, -- Input write address, width defined by write port depth
      WRCLK => fake_clk,   -- 1-bit input write clock
      WREN => fake_WrEn      -- 1-bit input write port enable
   );
FIFO_DI <= fake_crc & fake_header & fake_data;
EventData_trailer <= FIFO_DO(69);
EventData_header <= FIFO_DO(70);
EventData <= FIFO_DO(63 downto 0);
process(fake_clk,reset,ready)
begin
	if(reset = '1' or ready = '0')then
		FIFO_WA <= (others => '0');
		FIFO_WC <= (others => '0');
		linkfull <= '0';
	elsif(fake_clk'event and fake_clk = '1')then
		if(fake_WrEn = '1')then
			FIFO_WA <= FIFO_WA + 1;
		end if;
		FIFO_WC <= FIFO_WA(10 downto 2) - FIFO_RA;
		linkfull <= and_reduce(FIFO_WC(8 downto 4));
	end if;
end process;
process(EventDataClk,reset,Ready)
begin
	if(reset = '1' or ready = '0')then
		FIFO_RA <= (others => '0');
		ec_FIFO_RA <= '0';
		EventData_valid <= '0';
	elsif(EventDataClk'event and EventDataClk = '1')then
		if(ec_FIFO_RA = '1')then
			FIFO_RA <= FIFO_RA + 1;
		end if;
		if(almostfull = '1' or (FIFO_WC(8 downto 1) = x"00" and (FIFO_WC(0) = '0' or ec_FIFO_RA = '1')))then
			ec_FIFO_RA <= '0';
		else
			ec_FIFO_RA <= '1';
		end if;
		EventData_valid <= ec_FIFO_RA;
	end if;
end process;
process(sysclk,reset)
begin
	if(reset = '1')then
		L1A_DATA_wa <= x"0";
		L1A_WrEn <= '0';
	elsif(sysclk'event and sysclk = '1')then
		if(L1A_DATA_we = '1')then
			L1A_DATA_wa <= L1A_DATA_wa + 1;
		end if;
		L1A_WrEn <= L1A_DATA_we;
	end if;
end process;
process(sysclk)
begin
	if(sysclk'event and sysclk = '1')then
		if(ForceError(2 downto 0) /= "000")then
			case L1A_DATA_wa is
				when x"0" => L1A_DATAp(7) <= L1A_DATA(7) xor ForceError(0);
				when x"5" => L1A_DATAp(7) <= L1A_DATA(7) xor ForceError(1);
				when x"a" => L1A_DATAp(7) <= L1A_DATA(7) xor ForceError(1);
				when x"f" => L1A_DATAp(7) <= L1A_DATA(7) xor ForceError(2);
				when others => L1A_DATAp(7) <= L1A_DATA(7);
			end case;
			L1A_DATAp(6 downto 0) <= L1A_DATA(6 downto 0);
			L1A_DATAp(15 downto 8) <= L1A_DATA(15 downto 8);
		else
			L1A_DATAp <= L1A_DATA;
		end if;
	end if;
end process;
i_fake_event : fake_event PORT MAP (
          sysclk => sysclk,
          UsrClk => fake_clk,
          reset => fakereset,
					fifo_rst => fifo_rst,
					fifo_en => fifo_en,
          fake_en => test,
					sync => '1',
          ovfl_warning => ovfl_warning,
          fake_length => fake_length,
          LinkFull => LinkFull,
					board_ID => board_ID,
          L1A_DATA => L1A_DATAp,
          L1A_WrEn => L1A_WrEn,
          fake_header => fake_header,
          fake_CRC => fake_CRC,
          empty_event_flag => open,
          fake_DATA => fake_DATA,
          fake_WrEn => fake_WrEn
        );
i_FIFO_RESET_7S: FIFO_RESET_7S PORT MAP(
		reset => fakereset,
		clk => sysclk,
		fifo_rst => fifo_rst,
		fifo_en => fifo_en
	);
i_AMC_refclk: IBUFDS_GTE2
    port map
    (
        O                               => AMC_REFCLK,
        ODIV2                           => open,
        CEB                             => '0',
        I                               => AMC_REFCLK_P,  -- Connect to package pin AB6
        IB                              => AMC_REFCLK_N       -- Connect to package pin AB5
    );
fakereset <= reset or not ready;
process(fake_clk,reset)
begin
	if(reset = '1')then
		lfsr(16 downto 0) <= fake_seed;
	elsif(fake_clk'event and fake_clk = '1')then
		if(and_reduce(lfsr(16 downto 0)) = '1')then
			lfsr(16 downto 0) <= (others => '0');
		elsif(and_reduce(fake_seed) = '1' or (fake_header = '1' and fake_WrEn = '1'))then
			lfsr(16 downto 0) <= lfsr(15 downto 0) & (lfsr(16) xnor lfsr(13));
		end if;
	end if;
end process;
process(fake_lengthA,fake_lengthB)
begin
	if(fake_lengthA > fake_lengthB)then
		A(17 downto 0) <= fake_lengthB;
		C(34 downto 17) <= fake_lengthB;
		D(17 downto 0) <= fake_lengthA;
	else
		A(17 downto 0) <= fake_lengthA;
		C(34 downto 17) <= fake_lengthA;
		D(17 downto 0) <= fake_lengthB;
	end if;
end process;
fake_length <= P(34 downto 17);
DSP48E1_inst : DSP48E1
   generic map (
      -- Feature Control Attributes: Data Path Selection
      A_INPUT => "DIRECT",               -- Selects A input source, "DIRECT" (A port) or "CASCADE" (ACIN port)
      B_INPUT => "DIRECT",               -- Selects B input source, "DIRECT" (B port) or "CASCADE" (BCIN port)
      USE_DPORT => TRUE,                -- Select D port usage (TRUE or FALSE)
      USE_MULT => "MULTIPLY",            -- Select multiplier usage ("MULTIPLY", "DYNAMIC", or "NONE")
      -- Pattern Detector Attributes: Pattern Detection Configuration
      AUTORESET_PATDET => "NO_RESET",    -- "NO_RESET", "RESET_MATCH", "RESET_NOT_MATCH" 
      MASK => X"3fffffffffff",           -- 48-bit mask value for pattern detect (1=ignore)
      PATTERN => X"000000000000",        -- 48-bit pattern match for pattern detect
      SEL_MASK => "MASK",                -- "C", "MASK", "ROUNDING_MODE1", "ROUNDING_MODE2" 
      SEL_PATTERN => "PATTERN",          -- Select pattern value ("PATTERN" or "C")
      USE_PATTERN_DETECT => "NO_PATDET", -- Enable pattern detect ("PATDET" or "NO_PATDET")
      -- Register Control Attributes: Pipeline Register Configuration
      ACASCREG => 1,                     -- Number of pipeline stages between A/ACIN and ACOUT (0, 1 or 2)
      ADREG => 0,                        -- Number of pipeline stages for pre-adder (0 or 1)
      ALUMODEREG => 0,                   -- Number of pipeline stages for ALUMODE (0 or 1)
      AREG => 1,                         -- Number of pipeline stages for A (0, 1 or 2)
      BCASCREG => 1,                     -- Number of pipeline stages between B/BCIN and BCOUT (0, 1 or 2)
      BREG => 1,                         -- Number of pipeline stages for B (0, 1 or 2)
      CARRYINREG => 1,                   -- Number of pipeline stages for CARRYIN (0 or 1)
      CARRYINSELREG => 1,                -- Number of pipeline stages for CARRYINSEL (0 or 1)
      CREG => 1,                         -- Number of pipeline stages for C (0 or 1)
      DREG => 1,                         -- Number of pipeline stages for D (0 or 1)
      INMODEREG => 0,                    -- Number of pipeline stages for INMODE (0 or 1)
      MREG => 1,                         -- Number of multiplier pipeline stages (0 or 1)
      OPMODEREG => 0,                    -- Number of pipeline stages for OPMODE (0 or 1)
      PREG => 1,                         -- Number of pipeline stages for P (0 or 1)
      USE_SIMD => "ONE48"                -- SIMD selection ("ONE48", "TWO24", "FOUR12")
   )
   port map (
      -- Cascade: 30-bit (each) output: Cascade Ports
      ACOUT => open,                   -- 30-bit output: A port cascade output
      BCOUT => open,                   -- 18-bit output: B port cascade output
      CARRYCASCOUT => open,     -- 1-bit output: Cascade carry output
      MULTSIGNOUT => open,       -- 1-bit output: Multiplier sign cascade output
      PCOUT => open,                   -- 48-bit output: Cascade output
      -- Control: 1-bit (each) output: Control Inputs/Status Bits
      OVERFLOW => open,             -- 1-bit output: Overflow in add/acc output
      PATTERNBDETECT => open, -- 1-bit output: Pattern bar detect output
      PATTERNDETECT => open,   -- 1-bit output: Pattern detect output
      UNDERFLOW => open,           -- 1-bit output: Underflow in add/acc output
      -- Data: 4-bit (each) output: Data Ports
      CARRYOUT => open,             -- 4-bit output: Carry output
      P => P,                           -- 48-bit output: Primary data output
      -- Cascade: 30-bit (each) input: Cascade Ports
      ACIN => (others => '0'),                     -- 30-bit input: A cascade data input
      BCIN => (others => '0'),                     -- 18-bit input: B cascade input
      CARRYCASCIN => '0',       -- 1-bit input: Cascade carry input
      MULTSIGNIN => '0',         -- 1-bit input: Multiplier sign input
      PCIN => (others => '0'),                     -- 48-bit input: P cascade input
      -- Control: 4-bit (each) input: Control Inputs/Status Bits
      ALUMODE => x"0",               -- 4-bit input: ALU control input
      CARRYINSEL => (others => '0'),         -- 3-bit input: Carry select input
      CEINMODE => '1',             -- 1-bit input: Clock enable input for INMODEREG
      CLK => fake_clk,                       -- 1-bit input: Clock input
      INMODE => "11101",                 -- 5-bit input: INMODE control input
      OPMODE => "0110101",                 -- 7-bit input: Operation mode input
      RSTINMODE => '0',           -- 1-bit input: Reset input for INMODEREG
      -- Data: 30-bit (each) input: Data Ports
      A => A,                           -- 30-bit input: A data input
      B => lfsr,                           -- 18-bit input: B data input
      C => C,                           -- 48-bit input: C data input
      CARRYIN => '0',               -- 1-bit input: Carry input signal
      D => D,                           -- 25-bit input: D data input
      -- Reset/Clock Enable: 1-bit (each) input: Reset/Clock Enable Inputs
      CEA1 => '1',                     -- 1-bit input: Clock enable input for 1st stage AREG
      CEA2 => '1',                     -- 1-bit input: Clock enable input for 2nd stage AREG
      CEAD => '1',                     -- 1-bit input: Clock enable input for ADREG
      CEALUMODE => '1',           -- 1-bit input: Clock enable input for ALUMODERE
      CEB1 => fake_header,                     -- 1-bit input: Clock enable input for 1st stage BREG
      CEB2 => '1',                     -- 1-bit input: Clock enable input for 2nd stage BREG
      CEC => '1',                       -- 1-bit input: Clock enable input for CREG
      CECARRYIN => '1',           -- 1-bit input: Clock enable input for CARRYINREG
      CECTRL => '1',                 -- 1-bit input: Clock enable input for OPMODEREG and CARRYINSELREG
      CED => '1',                       -- 1-bit input: Clock enable input for DREG
      CEM => '1',                       -- 1-bit input: Clock enable input for MREG
      CEP => '1',                       -- 1-bit input: Clock enable input for PREG
      RSTA => '0',                     -- 1-bit input: Reset input for AREG
      RSTALLCARRYIN => '0',   -- 1-bit input: Reset input for CARRYINREG
      RSTALUMODE => '0',         -- 1-bit input: Reset input for ALUMODEREG
      RSTB => '0',                     -- 1-bit input: Reset input for BREG
      RSTC => '0',                     -- 1-bit input: Reset input for CREG
      RSTCTRL => '0',               -- 1-bit input: Reset input for OPMODEREG and CARRYINSELREG
      RSTD => '0',                     -- 1-bit input: Reset input for DREG and ADREG
      RSTM => '0',                     -- 1-bit input: Reset input for MREG
      RSTP => '0'                      -- 1-bit input: Reset input for PREG
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
        STABLE_CLOCK_PERIOD             =>      DRPclk_period,
        EXAMPLE_USE_CHIPSCOPE           =>      0,
				F_REFCLK												=>			F_REFCLK
    )
    port map
    (
        SYSCLK_IN                       =>      DRPclk,
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
        GT0_CPLLLOCKDETCLK_IN           =>      DRPclk,
        GT0_CPLLRESET_IN                =>      reset,
        -------------------------- Channel - Clocking Ports ------------------------
        GT0_GTREFCLK0_IN                =>      AMC_REFCLK,
        ---------------------------- Channel - DRP Ports  --------------------------
        GT0_DRPADDR_IN                  =>      (others => '0'),
        GT0_DRPCLK_IN                   =>      DRPclk,
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
        GT0_GTXRXP_IN                   =>      AMC_RXP,
        ------------------------ Receive Ports - RX AFE Ports ----------------------
        GT0_GTXRXN_IN                   =>      AMC_RXN,
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
        GT0_GTXTXN_OUT                  =>      AMC_TXN,
        GT0_GTXTXP_OUT                  =>      AMC_TXP,
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

