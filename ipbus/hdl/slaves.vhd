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

		debug: out std_logic_vector(7 downto 0);

		-- counters
		pkt_rx: in std_logic := '0';
		pkt_tx: in std_logic := '0';
		eth_phy_rudi_invalid: in std_logic := '0';
		eth_phy_rxdisperr: in std_logic := '0';
		eth_phy_rxnotintable: in std_logic := '0';
		amc13_almost_full: in std_logic := '0';

		-- status registers
	    axi_stream_in: in axi_stream;
	    axi_stream_in_tready: out std_logic;

	    axi_stream_out: out axi_stream;
	    axi_stream_out_tready: in std_logic;

	    -- DAQ Link
	    daq_valid       : out std_logic;
	    daq_header      : out std_logic;
	    daq_trailer     : out std_logic;
	    daq_data        : out std_logic_vector(63 downto 0);
	    daq_ready       : in  std_logic;
	    daq_almost_full : in  std_logic;

	    trigger_out        : out std_logic;
	    chan_done_out      : out std_logic_vector(4 downto 0);
	    chan_en_out        : out std_logic_vector(4 downto 0);
	    prog_chan_out      : out std_logic;
	    reprog_trigger_out : out std_logic_vector(1 downto 0);
        trig_delay_out     : out std_logic_vector(3 downto 0);
        endianness_out     : out std_logic;
        trig_settings_out  : out std_logic_vector(7 downto 0);
        trig_sel_out       : out std_logic_vector(1 downto 0);

	    -- channel user interface
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

		-- counter input ports
		frame_err        : in std_logic := '0';
		hard_err         : in std_logic := '0';
		soft_err         : in std_logic := '0';
		channel_up       : in std_logic := '0';
		lane_up          : in std_logic := '0';
		pll_not_locked   : in std_logic := '0';
		tx_resetdone_out : in std_logic := '0';
		rx_resetdone_out : in std_logic := '0';
		link_reset_out   : in std_logic := '0';

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

	constant NSLV: positive := 9;
	signal ipbw: ipb_wbus_array(NSLV-1 downto 0);
	signal ipbr, ipbr_d: ipb_rbus_array(NSLV-1 downto 0);
	signal ctrl_reg: std_logic_vector(31 downto 0);
	signal wo_reg: std_logic_vector(31 downto 0);
	signal count: std_logic_vector(15 downto 0);
	signal trigger: std_logic;

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
			reg11 => status_reg11
		);
		
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

		chan_done_out(0) <= ctrl_reg(1);
		chan_done_out(1) <= ctrl_reg(2);
		chan_done_out(2) <= ctrl_reg(3);
		chan_done_out(3) <= ctrl_reg(4);
		chan_done_out(4) <= ctrl_reg(5);

		chan_en_out(0) <= ctrl_reg(6);
		chan_en_out(1) <= ctrl_reg(7);
		chan_en_out(2) <= ctrl_reg(8);
		chan_en_out(3) <= ctrl_reg(9);
		chan_en_out(4) <= ctrl_reg(10);

		prog_chan_out <= ctrl_reg(11);
		reprog_trigger_out(0) <= ctrl_reg(12);
		reprog_trigger_out(1) <= ctrl_reg(13);

        trig_delay_out(0) <= ctrl_reg(14);
        trig_delay_out(1) <= ctrl_reg(15);
        trig_delay_out(2) <= ctrl_reg(16);
        trig_delay_out(3) <= ctrl_reg(17);

        endianness_out <= ctrl_reg(18);

        trig_settings_out(0) <= ctrl_reg(19);
        trig_settings_out(1) <= ctrl_reg(20);
        trig_settings_out(2) <= ctrl_reg(21);
        trig_settings_out(3) <= ctrl_reg(22);
        trig_settings_out(4) <= ctrl_reg(23);
        trig_settings_out(5) <= ctrl_reg(24);
        trig_settings_out(6) <= ctrl_reg(25);
        trig_settings_out(7) <= ctrl_reg(26);

        trig_sel_out(0) <= ctrl_reg(27);
        trig_sel_out(1) <= ctrl_reg(28);

-- Slave 2: 1kword RAM

	slave2: entity work.ipbus_ram
		generic map(addr_width => 10)
		port map(
			clk => ipb_clk,
			reset => ipb_rst,
			ipbus_in => ipbw(2),
			ipbus_out => ipbr(2)
		);

-- Slave 3: Write-only register

	slave3: entity work.ipbus_write_only_reg
		generic map(addr_width => 0)
		port map(
			clk => ipb_clk,
			reset => ipb_rst,
			ipbus_in => ipbw(3),
			ipbus_out => ipbr(3),
			q => wo_reg
		);

		trigger <= wo_reg(0);
		trigger_out <= trigger;

-- Slave 4: packet counters

	slave4: entity work.ipbus_counters
		generic map(addr_width => 4)
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
		count(5) <= daq_almost_full;
		count(6) <= trigger;
		count(7) <= frame_err;
		count(8) <= hard_err;
		count(9) <= soft_err;
		count(10) <= channel_up;
		count(11) <= lane_up;
		count(12) <= pll_not_locked;
		count(13) <= tx_resetdone_out;
		count(14) <= rx_resetdone_out;
		count(15) <= link_reset_out;

-- Slave 5: AXI4-stream interface to Aurora IP

	  slave5: entity work.ipbus_axi_stream
	  generic map(
	    id => 0,
	    addr_width => 4
            -- addr bits (3 downto 1) used to select one of the five channels (via tdest)
            -- addr bit 0 has unknown purpose; we get ipbus errors if we try to use an odd address
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

-- Slave 6

    slave6: entity work.ipbus_amc13_daq_link
	  port map(
	    clk => ipb_clk,
	    reset => ipb_rst,
	    ipbus_in => ipbw(6),
	    ipbus_out => ipbr(6),
	    daq_valid => daq_valid,
	    daq_header => daq_header,
	    daq_trailer => daq_trailer,
	    daq_data => daq_data,
	    daq_ready => daq_ready,
	    debug => debug
	  );

-- Slave 7: flash

	slave7: entity work.ipbus_flash
		generic map(addr_width => 9)
		port map(
			clk => ipb_clk,
			reset => ipb_rst,
			ipbus_in => ipbw(7),
			ipbus_out => ipbr(7),
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

-- Slave 8: 24 Mbyte user space

	slave8: entity work.ipbus_user
		generic map(addr_width => 24)
		port map(
			clk => ipb_clk,
			reset => ipb_rst,
			ipbus_in => ipbw(8),
            ipbus_out => ipbr(8),
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
