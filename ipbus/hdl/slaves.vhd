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
		ipb_clk : in  std_logic;
		ipb_rst : in  std_logic;
		ipb_in  : in  ipb_wbus;
		ipb_out : out ipb_rbus;
		rst_out : out std_logic;

		-- debug ports
		debug : out std_logic_vector(7 downto 0);

		-- AXI4-stream interface
	    axi_stream_in         : in  axi_stream;
	    axi_stream_in_tready  : out std_logic;
	    axi_stream_out        : out axi_stream;
	    axi_stream_out_tready : in  std_logic;

	    -- control signals
	    trigger_out        : out std_logic;
	    ip_addr_rst_out    : out std_logic;
	    chan_done_out      : out std_logic_vector(4 downto 0);
	    chan_en_out        : out std_logic_vector(4 downto 0);
	    prog_chan_out      : out std_logic;
	    reprog_trigger_out : out std_logic_vector(1 downto 0);
        trig_delay_out     : out std_logic_vector(3 downto 0);
        endianness_out     : out std_logic;
        trig_settings_out  : out std_logic_vector(7 downto 0);
        trig_sel_out       : out std_logic_vector(1 downto 0);
        ttc_loopback_out   : out std_logic;

        -- threshold registers
        thres_data_corrupt  : out std_logic_vector(31 downto 0); -- data corruption
        thres_unknown_ttc   : out std_logic_vector(31 downto 0); -- unknown TTC broadcast command
        thres_ddr3_overflow : out std_logic_vector(31 downto 0); -- DDR3 overflow

	    -- channel user space interface
        user_ipb_clk    : out std_logic;                     -- programming clock
        user_ipb_strobe : out std_logic;                     -- this ipb space is selected for an I/O operation 
        user_ipb_addr   : out std_logic_vector(31 downto 0); -- slave address, memory or register
        user_ipb_write  : out std_logic;		             -- this is a write operation
        user_ipb_wdata  : out std_logic_vector(31 downto 0); -- data to write for write operations
        user_ipb_rdata  : in  std_logic_vector(31 downto 0); -- data returned for read operations
        user_ipb_ack    : in  std_logic;			         -- 'write' data has been stored, 'read' data is ready
        user_ipb_err    : in  std_logic;			         -- '1' if error, '0' if OK?

		-- status registers
		status_reg0  : in std_logic_vector(31 downto 0);
		status_reg1  : in std_logic_vector(31 downto 0);
		status_reg2  : in std_logic_vector(31 downto 0);
		status_reg3  : in std_logic_vector(31 downto 0);
		status_reg4  : in std_logic_vector(31 downto 0);
		status_reg5  : in std_logic_vector(31 downto 0);
		status_reg6  : in std_logic_vector(31 downto 0);
		status_reg7  : in std_logic_vector(31 downto 0);
		status_reg8  : in std_logic_vector(31 downto 0);
		status_reg9  : in std_logic_vector(31 downto 0);
		status_reg10 : in std_logic_vector(31 downto 0);
		status_reg11 : in std_logic_vector(31 downto 0);
		status_reg12 : in std_logic_vector(31 downto 0);
		status_reg13 : in std_logic_vector(31 downto 0);
		status_reg14 : in std_logic_vector(31 downto 0);
		status_reg15 : in std_logic_vector(31 downto 0);
		status_reg16 : in std_logic_vector(31 downto 0);
		status_reg17 : in std_logic_vector(31 downto 0);
		status_reg18 : in std_logic_vector(31 downto 0);

		-- flash interface ports
		flash_wr_nBytes  : out std_logic_vector(8 downto 0);
		flash_rd_nBytes  : out std_logic_vector(8 downto 0);
		flash_cmd_strobe : out std_logic;
		flash_rbuf_en    : out std_logic;
		flash_rbuf_addr  : out std_logic_vector(6 downto 0);
		flash_rbuf_data  : in  std_logic_vector(31 downto 0);
		flash_wbuf_en    : out std_logic;
		flash_wbuf_addr  : out std_logic_vector(6 downto 0);
		flash_wbuf_data  : out std_logic_vector(31 downto 0)
	);

end slaves;

architecture rtl of slaves is

	constant NSLV : positive := 6;

	signal ipbw         : ipb_wbus_array(NSLV-1 downto 0);
	signal ipbr, ipbr_d : ipb_rbus_array(NSLV-1 downto 0);
	signal ctrl_reg     : std_logic_vector(31 downto 0);
	signal wo_reg       : std_logic_vector(31 downto 0);
	signal trigger      : std_logic;
	signal ip_addr_rst  : std_logic;

begin

  fabric: entity work.ipbus_fabric
    generic map(NSLV => NSLV)
    port map(
      ipb_in => ipb_in,
      ipb_out => ipb_out,
      ipb_to_slaves => ipbw,
      ipb_from_slaves => ipbr
    );

-- Slave 0: Status register

	slave0: entity work.ipbus_status_reg
		generic map(addr_width => 5)
		port map(
			clk => ipb_clk,
			reset => ipb_rst,
			ipbus_in => ipbw(0),
			ipbus_out => ipbr(0),
			-- status registers
			reg0 => status_reg0,
			reg1 => status_reg1,
			reg2 => status_reg2,
			reg3 => status_reg3,
			reg4 => status_reg4,
			reg5 => status_reg5,
			reg6 => status_reg6,
			reg7 => status_reg7,
			reg8 => status_reg8,
			reg9 => status_reg9,
			reg10 => status_reg10,
			reg11 => status_reg11,
			reg12 => status_reg12,
			reg13 => status_reg13,
			reg14 => status_reg14,
			reg15 => status_reg15,
			reg16 => status_reg16,
			reg17 => status_reg17,
			reg18 => status_reg18
		);
		
-- Slave 1: Control register

	slave1: entity work.ipbus_reg
		generic map(addr_width => 4)
		port map(
			clk => ipb_clk,
			reset => ipb_rst,
			ipbus_in => ipbw(1),
			ipbus_out => ipbr(1),
			-- output registers
			reg0 => ctrl_reg,
			reg1 => thres_data_corrupt,
			reg2 => thres_unknown_ttc,
			reg3 => thres_ddr3_overflow
		);

		-- control register
		rst_out               <= ctrl_reg( 0);
		-- async_mode_out        <= ctrl_reg( 1);
		prog_chan_out         <= ctrl_reg( 2);
		reprog_trigger_out(0) <= ctrl_reg( 3);
		reprog_trigger_out(1) <= ctrl_reg( 4);
		chan_en_out(0)        <= ctrl_reg( 5);
		chan_en_out(1)        <= ctrl_reg( 6);
		chan_en_out(2)        <= ctrl_reg( 7);
		chan_en_out(3)        <= ctrl_reg( 8);
		chan_en_out(4)        <= ctrl_reg( 9);
        endianness_out        <= ctrl_reg(10);
        trig_settings_out(0)  <= ctrl_reg(11);
        trig_settings_out(1)  <= ctrl_reg(12);
        trig_settings_out(2)  <= ctrl_reg(13);
        ttc_loopback_out      <= ctrl_reg(14);
        -- ext_trig_pulse_en_out <= ctrl_reg(15);
        -- async_trig_type_out   <= ctrl_reg(16);
    	-- accept_pulse_trig_out <= ctrl_reg(17);

-- Slave 2: Write-only register

	slave2: entity work.ipbus_write_only_reg
		generic map(addr_width => 0)
		port map(
			clk => ipb_clk,
			reset => ipb_rst,
			ipbus_in => ipbw(2),
			ipbus_out => ipbr(2),
			q => wo_reg
		);

		trigger     <= wo_reg(0);
		trigger_out <= trigger;

		ip_addr_rst     <= wo_reg(1);
		ip_addr_rst_out <= ip_addr_rst;

-- Slave 3: AXI4-stream interface to Aurora IP

	  slave3: entity work.ipbus_axi_stream
	  generic map(
	    id => 0,
	    addr_width => 4
            -- addr bits (3 downto 1) used to select one of the five channels (via tdest)
            -- addr bit 0 has unknown purpose; we get ipbus errors if we try to use an odd address
	  )
	  port map(
	    clk => ipb_clk,
	    reset => ipb_rst,
	    ipbus_in => ipbw(3),
	    ipbus_out => ipbr(3),
	    axi_str_in => axi_stream_in,
	    axi_str_in_tready => axi_stream_in_tready,
	    axi_str_out => axi_stream_out,
	    axi_str_out_tready => axi_stream_out_tready
	  );

-- Slave 4: Flash

	slave4: entity work.ipbus_flash
		generic map(addr_width => 9)
		port map(
			clk => ipb_clk,
			reset => ipb_rst,
			ipbus_in => ipbw(4),
			ipbus_out => ipbr(4),
			-- flash interface
			flash_wr_nBytes => flash_wr_nBytes,
			flash_rd_nBytes => flash_rd_nBytes,
			flash_cmd_strobe => flash_cmd_strobe,
			flash_rbuf_en => flash_rbuf_en,
			flash_rbuf_addr => flash_rbuf_addr,
			flash_rbuf_data => flash_rbuf_data,
			flash_wbuf_en => flash_wbuf_en,
			flash_wbuf_addr => flash_wbuf_addr,
			flash_wbuf_data => flash_wbuf_data
		);

-- Slave 5: 24-MB user space

	slave5: entity work.ipbus_user
		generic map(addr_width => 24)
		port map(
			clk => ipb_clk,
			reset => ipb_rst,
			ipbus_in => ipbw(5),
            ipbus_out => ipbr(5),
			-- user interface
            user_ipb_clk => user_ipb_clk,       -- programming clock
            user_ipb_strobe => user_ipb_strobe, -- this ipb space is selected for an I/O operation 
            user_ipb_addr => user_ipb_addr,     -- slave address, memory or register
            user_ipb_write => user_ipb_write,   -- this is a write operation
            user_ipb_wdata => user_ipb_wdata,   -- data to write for write operations
            user_ipb_rdata => user_ipb_rdata,   -- data returned for read operations
            user_ipb_ack => user_ipb_ack,       -- 'write' data has been stored, 'read' data is ready
            user_ipb_err => user_ipb_err        -- '1' if error, '0' if OK?
		);

end rtl;
