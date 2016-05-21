// Top-level module for g-2 WFD5 Master FPGA

// As a useful reference, here's the syntax to mark signals for debug:
// (* mark_debug = "true" *) 
//
// Note 1: The channels are also reset with the TTC trigger number reset command.

module wfd_top (
    input  wire clkin,                // 50 MHz clock
    input  wire gtx_clk0, gtx_clk0_N, // Bank 115 125 MHz GTX Transceiver refclk
    input  wire gtx_clk1, gtx_clk1_N, // Bank 116 125 MHz GTX Transceiver refclk
    output wire gige_tx,  gige_tx_N,  // Gigabit Ethernet TX
    input  wire gige_rx,  gige_rx_N,  // Gigabit Ethernet RX
    input  wire daq_rx,   daq_rx_N,   // AMC13 Link RX
    output wire daq_tx,   daq_tx_N,   // AMC13 Link TX
    input  wire c0_rx, c0_rx_N,       // Serial link to Channel 0 RX
    output wire c0_tx, c0_tx_N,       // Serial link to Channel 0 TX
    input  wire c1_rx, c1_rx_N,       // Serial link to Channel 1 RX
    output wire c1_tx, c1_tx_N,       // Serial link to Channel 1 TX
    input  wire c2_rx, c2_rx_N,       // Serial link to Channel 2 RX
    output wire c2_tx, c2_tx_N,       // Serial link to Channel 2 TX
    input  wire c3_rx, c3_rx_N,       // Serial link to Channel 3 RX
    output wire c3_tx, c3_tx_N,       // Serial link to Channel 3 TX
    input  wire c4_rx, c4_rx_N,       // Serial link to Channel 4 RX
    output wire c4_tx, c4_tx_N,       // Serial link to Channel 4 TX
    output wire debug0,               // debug header
    output wire debug1,               // debug header
    output wire debug2,               // debug header
    output wire debug3,               // debug header
    output wire debug4,               // debug header
    output wire debug5,               // debug header
    output wire debug6,               // debug header
    output wire debug7,               // debug header
    output wire [4:0] acq_trigs,      // triggers to channel FPGAs
    input  wire [4:0] acq_dones,      // done signals from channel FPGAs
    output wire master_led0,          // front panel LEDs for master status, led0 is green
    output wire master_led1,          // front panel LEDs for master status, led1 is red
    output wire clksynth_led0,        // front panel LEDs for clk synth status, led0 is green
    output wire clksynth_led1,        // front panel LEDs for clk synth status, led1 is red
    inout  wire bbus_scl,             // I2C bus clock, connected to Atmel Chip and to Channel FPGAs
    inout  wire bbus_sda,             // I2C bus data, connected to Atmel Chip and to Channel FPGAs
    input  wire ext_trig,             // front panel trigger
    input  wire [3:0] mmc_io,         // controls to/from the Atmel
    output wire [3:0] c0_io,          // utility signals to Channel 0
    output wire [3:0] c1_io,          // utility signals to Channel 1
    output wire [3:0] c2_io,          // utility signals to Channel 2
    output wire [3:0] c3_io,          // utility signals to Channel 3
    output wire [3:0] c4_io,          // utility signals to Channel 4
    output wire afe_dac_sclk,         // MB[0] on schematic, for AFE's DAC clock
    output wire afe_dac_sdi,          // MB[1] on schematic, for AFE's DAC data input
    output wire afe_dac_sync_n,       // MB[2] on schematic, for AFE's DAC \sync signal
    input  wire mezzb3,               // MB[3] on schematic, unused
    input  wire mezzb4,               // MB[4] on schematic, unused
    input  wire mezzb5,               // MB[5] on schematic, unused
    input  wire mmc_reset_m,          // reset line 
    input  wire adcclk_stat_ld,       // clock synth status, PLL lock detect
    input  wire adcclk_stat,          // clock synth status
    input  wire adcclk_clkin0_stat,   // clock synth status
    input  wire adcclk_clkin1_stat,   // clock synth status
    output wire adcclk_sync,          //
    output wire adcclk_dlen,          //
    output wire adcclk_ddat,          //
    output wire adcclk_dclk,          //
    output wire ext_clk_sel0,         //
    output wire ext_clk_sel1,         //
    output wire daq_clk_sel,          //
    output wire daq_clk_en,           //
    // TTC connections
    input  wire ttc_clkp, ttc_clkn,   // TTC diff clock
    input  wire ttc_rxp, ttc_rxn,     // data from TTC
    output wire ttc_txp, ttc_txn,     // data to TTC
    // Power Supply connections
    input  wire [1:0] wfdps,          //
    // Channel FPGA configuration connections
    output wire c_progb,              // to all channels FPGA Configuration
    output wire c_clk,                // to all channels FPGA Configuration
    output wire c_din,                // to all channels FPGA Configuration
    input  wire [4:0] initb,          // from each channel FPGA Configuration
    input  wire [4:0] prog_done,      // from each channel FPGA Configuration
    input  wire test,                 //
    input  wire spi_miso,             // serial data from SPI flash memory
    output wire spi_mosi,             // serial data (commands) to SPI flash memory
    output wire spi_ss,               // SPI flash memory chip select
    input  wire fp_sw_master          // front panel switch
);

    // ======== clock signals ========
    wire clk_10, clk10; // 10 MHz clock for AFE DAC interface
    wire clk50;
    wire clk_125, clk125;
    wire clk200;
    wire clkfb;
    wire gtrefclk0;
    wire pll_lock;
    wire ttc_clock; // 40 MHz output from TTC decoder module
    wire spi_clock;

    assign clk50 = clkin; // just to make the frequency explicit


    wire clk50_reset;


    // ======== startup reset signals ========
    wire startup_rst_clk50;
    wire startup_rst_clk125;

    // synchronous reset logic
    startup_reset startup_reset (
        .clk50(clk50),                     // 50 MHz buffered clock 
        .reset_clk50(startup_rst_clk50),   // active-high reset output, goes low after startup
        .clk125(clk125),                   // buffered clock, 125 MHz
        .reset_clk125(startup_rst_clk125), // active-high reset output, goes low after startup
        .ipb_reset(clk50_reset)
    );


    // ======== error signals ========
    // thresholds
    wire [31:0] thres_data_corrupt;  // data corruption
    wire [31:0] thres_unknown_ttc;   // unknown TTC broadcast command
    wire [31:0] thres_ddr3_overflow; // DDR3 overflow

    // soft error counts
    wire [31:0] unknown_cmd_count;
    wire [31:0] ddr3_overflow_count;
    wire [31:0] cs_mismatch_count;

    // hard errors
    wire error_data_corrupt;
    wire error_trig_num_from_tt;
    wire error_trig_type_from_tt;
    wire error_trig_num_from_cm;
    wire error_trig_type_from_cm;
    wire error_pll_unlock;
    wire error_trig_rate;
    wire error_unknown_ttc;

    // warnings
    wire ddr3_overflow_warning;

    // throw error if either PLL is unlocked for there is a loss-of-signal
    assign error_pll_unlock = ~adcclk_stat_ld | ~adcclk_stat | adcclk_clkin0_stat;

    wire [4:0] chan_error_rc;  // master received an error response code, one bit for each channel

    // ======== I/O lines to channel ========
    wire [9:0] acq_enable;
    wire [4:0] acq_readout_pause;

    assign c0_io[0] = acq_readout_pause[0];
    assign c1_io[0] = acq_readout_pause[1];
    assign c2_io[0] = acq_readout_pause[2];
    assign c3_io[0] = acq_readout_pause[3];
    assign c4_io[0] = acq_readout_pause[4];

    assign c0_io[2:1] = acq_enable[1:0];
    assign c1_io[2:1] = acq_enable[3:2];
    assign c2_io[2:1] = acq_enable[5:4];
    assign c3_io[2:1] = acq_enable[7:6];
    assign c4_io[2:1] = acq_enable[9:8];

    // ======== TTC signals ========
    wire ttc_ready;
    wire ttc_loopback;

    // ======== TTS signals ========
    wire [3:0] tts_state;


    // ======== front panel LED for master ========
    led_master_status led_master_status (
        .clk(clk50),
        .red_led(master_led1),
        .green_led(master_led0),
        // status input signals
        .ttc_ready(ttc_ready),
        .tts_state(tts_state)
    );

    // ======== front panel LED for clk synth ========
    led_clksynth_status led_clksynth_status (
        .clk(clk50),
        .red_led(clksynth_led1),
        .green_led(clksynth_led0),
        // status input signals
        .adcclk_ld(adcclk_stat_ld),
        .adcclk_stat(adcclk_stat),
        .adcclk_clkin0_stat(adcclk_clkin0_stat)
    );



    // dummy use of signals
    assign debug7 = spi_ss & spi_clk & spi_mosi & spi_miso & prog_done[4] & prog_done[3] & prog_done[2] & prog_done[1] & prog_done[0] & wfdps[0] & wfdps[1] & mmc_reset_m & mezzb3 & mezzb4 & mezzb5 & mmc_io[2] & mmc_io[3] & ext_trig_sync & trigger_from_ipbus_sync & initb[4] & initb[3] & initb[2] & initb[1] & initb[0];

    // active-high reset signal to channels
    assign c0_io[3] = rst_from_ipb | rst_trigger_num;
    assign c1_io[3] = rst_from_ipb | rst_trigger_num;
    assign c2_io[3] = rst_from_ipb | rst_trigger_num;
    assign c3_io[3] = rst_from_ipb | rst_trigger_num;
    assign c4_io[3] = rst_from_ipb | rst_trigger_num;

    // front panel clock: sel0 = 1'b1, sel1 = 1'b0
    assign ext_clk_sel0 = 1'b1;
    assign ext_clk_sel1 = 1'b0;

    // uTCA backplane clock: daq_clk_sel = 1'b0
    // front panel clock:    daq_clk_sel = 1'b1
    assign daq_clk_sel = 1'b0;
    assign daq_clk_en  = 1'b1;

    OBUFDS ttc_tx_buf(.I(ttc_rx), .O(ttc_txp), .OB(ttc_txn)); 

    // Generate clocks from the 50 MHz input clock
    // Most of the design is run from the 125 MHz clock (Don't confuse it with the 125 MHz GTREFCLK)
    // clk200 acts as the independent clock required by the Gigabit ethernet IP
    PLLE2_BASE #(
        .CLKFBOUT_MULT(20.0),
        .CLKIN1_PERIOD(20), // in ns, so 20 -> 50 MHz
        .CLKOUT0_DIVIDE(5),
        .CLKOUT1_DIVIDE(8),
        .CLKOUT2_DIVIDE(100)
    ) clk (
        .CLKIN1(clkin),
        .CLKOUT0(clk200),
        .CLKOUT1(clk_125),
        .CLKOUT2(clk_10),
        .CLKOUT3(),
        .CLKOUT4(),
        .CLKOUT5(),
        .LOCKED(pll_lock),
        .RST(0),
        .PWRDWN(0),
        .CLKFBOUT(clkfb),
        .CLKFBIN(clkfb)
    );

    // Added BUFG object to deal with a warning message that caused implementation to fail
    // "Clock net clk125 is not driven by a Clock Buffer and has more than 2000 loads."
    BUFG BUFG_clk125 (.I(clk_125), .O(clk125));

    BUFG BUFG_clk10 (.I(clk_10), .O(clk10));

    // ======== ethernet status signals ========
    reg sfp_los = 0;      // loss of signal for Gigabit ethernet (not used)
    wire eth_link_status; // link status of Gigabit ethernet

    // ======== reset signals ========
    wire rst_from_ipb, rst_from_ipb_n;  // active-high reset from IPbus; synchronous to IPbus clock
    assign rst_from_ipb_n = ~rst_from_ipb;


    // Synchronize reset from IPbus clock domain to other domains
    wire ipb_rst_stretch;
    signal_stretch reset_stretch (
        .signal_in(rst_from_ipb),
        .clk(clk125),
        .n_extra_cycles(4'h8), // add more than enough extra clock cycles for synchronization into 50 MHz and 40 MHz clock domains
        .signal_out(ipb_rst_stretch)
    );

    sync_2stage clk50_reset_sync (
        .clk(clk50),
        .in(ipb_rst_stretch),
        .out(clk50_reset)
    );

    wire reset40;
    sync_2stage reset40_sync (
        .clk(ttc_clk),
        .in(ipb_rst_stretch),
        .out(reset40)
    );

    wire reset40_n;
    assign reset40_n = ~reset40;

	// connect a module that will read from the I2C temperature/memory chip.
	// Since the MAC and IP address are used with IP bus, run the block with 'clk125'
	wire [47:0] i2c_mac_adr; // MAC address read from I2C EEPROM
	wire [31:0] i2c_ip_adr;  //  IP address read from I2C EEPROM
    wire i2c_startup_done;

    wire bbus_scl_oen;
    wire bbus_sda_oen;

	i2c_top i2c_top (
		// inputs
		.clk(clk125),
        .reset(ip_addr_rst),                 // IPbus reset for reloading addresses from EEPROM
        // outputs
        .i2c_startup_done(i2c_startup_done), // MAC andIP will be valid when this is asserted
		.i2c_mac_adr(i2c_mac_adr[47:0]),	 // MAC address read from I2C EEPROM
		.i2c_ip_adr(i2c_ip_adr[31:0]),	     // IP address read from I2C EEPROM
		// I2C signals
		.scl_pad_i(bbus_scl),				 // input from external pin
		.scl_pad_o(bbus_scl_o),			     // output to tri-state driver
		.scl_padoen_o(bbus_scl_oen),		 // enable signal for tri-state driver
		.sda_pad_i(bbus_sda),                // input from external pin
		.sda_pad_o(bbus_sda_o),				 // output to tri-state driver
		.sda_padoen_o(bbus_sda_oen)			 // enable signal for tri-state driver
	);

    assign bbus_scl = bbus_scl_oen ? 1'bz : bbus_scl_o;
    assign bbus_sda = bbus_sda_oen ? 1'bz : bbus_sda_o;

    // debug signals
    assign debug0 = bbus_scl;
    assign debug1 = bbus_sda;
    assign debug2 = 1'b1;
    assign debug3 = bbus_scl_oen;
    assign debug4 = bbus_sda_oen;
    assign debug5 = 1'b1;
    assign debug6 = 1'b0;
    assign debug7 = 1'b0;
    
    // ================== communicate with SPI flash memory ==================

    // The startup block will give us access to the SPI clock pin (which is otherwise reserved for use during FPGA configuration)
    // STARTUPE2: STARTUP Block
    //            7  Series
    // Xilinx HDL Libraries Guide, version 13.3
    STARTUPE2 #(
        .PROG_USR("FALSE"),  // Activate program event security feature. Requires encrypted bitstreams.
        .SIM_CCLK_FREQ(0.0)  // Set the Configuration Clock Frequency(ns) for simulation.
    ) STARTUPE2_inst (
        .CFGCLK(),          // 1-bit output: Configuration main clock output
        .CFGMCLK(),         // 1-bit output: Configuration internal oscillator clock output
        .EOS(),             // 1-bit output: Active high output signal indicating the End Of Startup.
        .PREQ(),            // 1-bit output: PROGRAM request to fabric output
        .CLK(0),            // 1-bit input: User start-up clock input
        .GSR(0),            // 1-bit input: Global Set/Reset input (GSR cannot be used for the port name)
        .GTS(0),            // 1-bit input: Global 3-state input (GTS cannot be used for the port name)
        .KEYCLEARB(0),      // 1-bit input: Clear AES Decrypter Key input from Battery-Backed RAM (BBRAM)
        .PACK(0),           // 1-bit input: PROGRAM acknowledge input
        .USRCCLKO(spi_clk), // 1-bit input: User CCLK input
        .USRCCLKTS(0),      // 1-bit input: User CCLK 3-state enable input
        .USRDONEO(0),       // 1-bit input: User DONE pin output control
        .USRDONETS(0)       // 1-bit input: User DONE 3-state enable output
    );


    wire [31:0] spi_data;
    wire read_bitstream;
    wire end_bitstream;

    wire [8:0] ipbus_to_flash_wr_nBytes;
    wire [8:0] ipbus_to_flash_rd_nBytes;
    wire ipbus_to_flash_cmd_strobe;
    wire flash_to_ipbus_cmd_ack;
    wire ipbus_to_flash_rbuf_en;
    wire [ 6:0] ipbus_to_flash_rbuf_addr;
    wire [31:0] flash_rbuf_to_ipbus_data;
    wire ipbus_to_flash_wbuf_en;
    wire [ 6:0] ipbus_to_flash_wbuf_addr;
    wire [31:0] ipbus_to_flash_wbuf_data;

    spi_flash_intf spi_flash_intf (
        .clk(clk50),
        .ipb_clk(clk125),
        .reset(clk50_reset),
        .spi_clk(spi_clk),
        .spi_mosi(spi_mosi),
        .spi_miso(spi_miso),
        .spi_ss(spi_ss),
        .prog_chan_in_progress(prog_chan_in_progress), // signal from prog_channels
        .read_bitstream(read_bitstream),               // start signal from prog_channels
        .end_bitstream(end_bitstream),                 // done signal to prog_channels
        .ipb_flash_wr_nBytes(ipbus_to_flash_wr_nBytes),
        .ipb_flash_rd_nBytes(ipbus_to_flash_rd_nBytes),
        .ipb_flash_cmd_strobe(ipbus_to_flash_cmd_strobe),
        .ipb_rbuf_rd_en(ipbus_to_flash_rbuf_en),
        .ipb_rbuf_rd_addr(ipbus_to_flash_rbuf_addr),
        .ipb_rbuf_data_out(flash_rbuf_to_ipbus_data),
        .ipb_wbuf_wr_en(ipbus_to_flash_wbuf_en),
        .ipb_wbuf_wr_addr(ipbus_to_flash_wbuf_addr),
        .ipb_wbuf_data_in(ipbus_to_flash_wbuf_data),
        .pc_wbuf_wr_en(pc_to_flash_wbuf_en), // from prog_channels
        .pc_wbuf_wr_addr(7'b0000000),        // hardcode address 0
        .pc_wbuf_data_in(32'h03CE0000)       // hardcode read command for channel bitstream
    );

    // ======== program channel FPGAs using bistream stored on SPI flash memory ========

    wire prog_chan_start_from_ipbus; // in 125 MHz clock domain
    wire prog_chan_start;            // in 50 MHz clock domain 
                                     // don't have to worry about missing the faster signal -- stays high 
                                     // until you use ipbus to set it low again
    wire prog_chan_done;

    sync_2stage prog_chan_start_sync (
        .clk(clk50),
        .in(prog_chan_start_from_ipbus),
        .out(prog_chan_start)
    );

    wire prog_chan_start_mux; // combine ipbus and startup triggers
    assign prog_chan_start_mux = prog_chan_start | startup_rst_clk50;

    prog_channels prog_channels (
        .clk(clk50),
        .reset(clk50_reset),
        .prog_chan_start(prog_chan_start_mux),         // start signal from IPbus
        .c_progb(c_progb),                             // configuration signal to all five channels
        .c_clk(c_clk),                                 // configuration clock to all five channels
        .c_din(c_din),                                 // configuration bitstream to all five channels
        .initb(initb),                                 // configuration signals from each channel
        .prog_done(prog_done),                         // configuration signals from each channel
        .bitstream(spi_miso),                          // bitstream from flash memory
        .prog_chan_in_progress(prog_chan_in_progress), // signal to spi_flash_intf
        .store_flash_command(pc_to_flash_wbuf_en),     // signal to spi_flash_intf
        .read_bitstream(read_bitstream),               // start signal to spi_flash_intf
        .end_bitstream(end_bitstream),                 // done signal from spi_flash_intf
        .prog_chan_done(prog_chan_done)                // done programming the channels
    );

    // ======== module to reprogram FPGA from flash ========

    wire [1:0] reprog_trigger_from_ipbus; // in 125 MHz clock domain
    wire [1:0] reprog_trigger;            // in 50 MHz clock domain
                                          // don't have to worry about missing the faster signal
                                          // (stays high until you use ipbus to set it low again)
    wire [1:0] reprog_trigger_delayed;    // after passing through 32-bit shift register
                                          // (to allow time for IPbus ack before reprogramming FPGA)

    sync_2stage #(
        .WIDTH(2)
    ) reprog_trigger_sync (
        .clk(clk50),
        .in(reprog_trigger_from_ipbus),
        .out(reprog_trigger)
    );

    // Delay signal by passing through 32-bit shift register (to allow time for IPbus ack)

    // SRLC32E: 32-bit variable length cascadable shift register LUT (Mapped to a SliceM LUT6)
    //          with clock enable
    //          7 Series
    // Xilinx HDL Libraries Guide, version 14.2
    SRLC32E #(
        .INIT(32'h00000000) // Initial Value of Shift Register
    ) SRLC32E_inst0 (
        .Q(reprog_trigger_delayed[0]), // SRL data output
        .Q31(),                        // SRL cascade output pin
        .A(5'b11111),                  // 5-bit shift depth select input (5'b11111 = 32-bit shift)
        .CE(1'b1),                     // Clock enable input
        .CLK(clk50),                   // Clock input
        .D(reprog_trigger[0])          // SRL data input
    );

    SRLC32E #(
        .INIT(32'h00000000) // Initial Value of Shift Register
    ) SRLC32E_inst1 (
        .Q(reprog_trigger_delayed[1]), // SRL data output
        .Q31(),                        // SRL cascade output pin
        .A(5'b11111),                  // 5-bit shift depth select input (5'b11111 = 32-bit shift)
        .CE(1'b1),                     // Clock enable input
        .CLK(clk50),                   // Clock input
        .D(reprog_trigger[1])          // SRL data input
    );

    // reprog_trigger_mux[0] for golden image
    // reprog_trigger_mux[1] for master image
    wire [1:0] reprog_trigger_mux; // combine ipbus and front panel triggers
    assign reprog_trigger_mux = fp_sw_master ? reprog_trigger_delayed : 2'b01;
    
    reprog reprog (
        .clk(clk50),
        .reset(clk50_reset),
        .trigger(reprog_trigger_mux)
    );
   

    // ======== triggers and data transfer ========

    // TTC trigger in 40 MHz TTC clock domain
    wire trigger_from_ttc;

    // put other trigger signals into 40 MHz TTC clock domain
    wire ext_trig_sync;
    wire trigger_from_ipbus;
    wire trigger_from_ipbus_stretch;
    wire trigger_from_ipbus_sync;

    sync_2stage ext_trig_sync_module (
        .clk(ttc_clk),
        .in(ext_trig),
        .out(ext_trig_sync)
    );

    signal_stretch trigger_from_ipbus_stretch_module (
        .signal_in(trigger_from_ipbus),
        .clk(clk125),
        .n_extra_cycles(4'h4),
        .signal_out(trigger_from_ipbus_stretch)
    );

    sync_2stage trigger_from_ipbus_sync_module (
        .clk(ttc_clk),
        .in(trigger_from_ipbus_stretch),
        .out(trigger_from_ipbus_sync)
    );


    // select bit for the endianness of ADC data
    //   0 = big-endian (default)
    //   1 = little-endian
    wire endianness_sel;

    // enable signals to channels
    wire [4:0] chan_en;

    // delay between receiving the trigger and passing it onto the channels                                                                                                                                                   
    wire [3:0] trig_delay;

    // ======== wires for interface to channel serial link ========
    // User IPbus interface. Used by Charlie's Aurora block.
    wire [31:0] user_ipb_addr, user_ipb_wdata, user_ipb_rdata;
    wire user_ipb_clk, user_ipb_strobe, user_ipb_write, user_ipb_ack;


    ///////////////////////////////////////////////////////////////////////////
    // AXI4-Stream interface for communicating with serial link to channel FPGA
    // Channel 0
    wire c0_axi_stream_to_cm_tvalid, c0_axi_stream_to_cm_tlast, c0_axi_stream_to_cm_tready;
    wire [0:31] c0_axi_stream_to_cm_tdata;

    wire c0_axi_stream_to_channel_tvalid, c0_axi_stream_to_channel_tlast, c0_axi_stream_to_channel_tready;
    wire [0:31] c0_axi_stream_to_channel_tdata;
    wire [ 0:3] c0_axi_stream_to_channel_tdest;

    // Channel 1
    wire c1_axi_stream_to_cm_tvalid, c1_axi_stream_to_cm_tlast, c1_axi_stream_to_cm_tready;
    wire [0:31] c1_axi_stream_to_cm_tdata;

    wire c1_axi_stream_to_channel_tvalid, c1_axi_stream_to_channel_tlast, c1_axi_stream_to_channel_tready;
    wire [0:31] c1_axi_stream_to_channel_tdata;
    wire [ 0:3] c1_axi_stream_to_channel_tdest;

    // Channel 2
    wire c2_axi_stream_to_cm_tvalid, c2_axi_stream_to_cm_tlast, c2_axi_stream_to_cm_tready;
    wire [0:31] c2_axi_stream_to_cm_tdata;

    wire c2_axi_stream_to_channel_tvalid, c2_axi_stream_to_channel_tlast, c2_axi_stream_to_channel_tready;
    wire [0:31] c2_axi_stream_to_channel_tdata;
    wire [ 0:3] c2_axi_stream_to_channel_tdest;

    // Channel 3
    wire c3_axi_stream_to_cm_tvalid, c3_axi_stream_to_cm_tlast, c3_axi_stream_to_cm_tready;
    wire [0:31] c3_axi_stream_to_cm_tdata;

    wire c3_axi_stream_to_channel_tvalid, c3_axi_stream_to_channel_tlast, c3_axi_stream_to_channel_tready;
    wire [0:31] c3_axi_stream_to_channel_tdata;
    wire [ 0:3] c3_axi_stream_to_channel_tdest;

    // Channel 4
    wire c4_axi_stream_to_cm_tvalid, c4_axi_stream_to_cm_tlast, c4_axi_stream_to_cm_tready;
    wire [0:31] c4_axi_stream_to_cm_tdata;

    wire c4_axi_stream_to_channel_tvalid, c4_axi_stream_to_channel_tlast, c4_axi_stream_to_channel_tready;
    wire [0:31] c4_axi_stream_to_channel_tdata;
    wire [ 0:3] c4_axi_stream_to_channel_tdest;


    ////////////////////////////////////////////////////////////////
    // packaged up channel connections for the AXIS TX Switch output
    wire [  4:0] c_axi_stream_to_channel_tvalid, c_axi_stream_to_channel_tlast, c_axi_stream_to_channel_tready;
    wire [ 19:0] c_axi_stream_to_channel_tdest;
    wire [159:0] c_axi_stream_to_channel_tdata;

    assign c0_axi_stream_to_channel_tvalid = c_axi_stream_to_channel_tvalid[0];
    assign c1_axi_stream_to_channel_tvalid = c_axi_stream_to_channel_tvalid[1];
    assign c2_axi_stream_to_channel_tvalid = c_axi_stream_to_channel_tvalid[2];
    assign c3_axi_stream_to_channel_tvalid = c_axi_stream_to_channel_tvalid[3];
    assign c4_axi_stream_to_channel_tvalid = c_axi_stream_to_channel_tvalid[4];
    assign c0_axi_stream_to_channel_tlast = c_axi_stream_to_channel_tlast[0];
    assign c1_axi_stream_to_channel_tlast = c_axi_stream_to_channel_tlast[1];
    assign c2_axi_stream_to_channel_tlast = c_axi_stream_to_channel_tlast[2];
    assign c3_axi_stream_to_channel_tlast = c_axi_stream_to_channel_tlast[3];
    assign c4_axi_stream_to_channel_tlast = c_axi_stream_to_channel_tlast[4];
    assign c_axi_stream_to_channel_tready[0] = c0_axi_stream_to_channel_tready;
    assign c_axi_stream_to_channel_tready[1] = c1_axi_stream_to_channel_tready;
    assign c_axi_stream_to_channel_tready[2] = c2_axi_stream_to_channel_tready;
    assign c_axi_stream_to_channel_tready[3] = c3_axi_stream_to_channel_tready;
    assign c_axi_stream_to_channel_tready[4] = c4_axi_stream_to_channel_tready;
    assign c0_axi_stream_to_channel_tdata = c_axi_stream_to_channel_tdata[31:0];
    assign c1_axi_stream_to_channel_tdata = c_axi_stream_to_channel_tdata[63:32];
    assign c2_axi_stream_to_channel_tdata = c_axi_stream_to_channel_tdata[95:64];
    assign c3_axi_stream_to_channel_tdata = c_axi_stream_to_channel_tdata[127:96];
    assign c4_axi_stream_to_channel_tdata = c_axi_stream_to_channel_tdata[159:128];
    assign c0_axi_stream_to_channel_tdest = c_axi_stream_to_channel_tdest[3:0];
    assign c1_axi_stream_to_channel_tdest = c_axi_stream_to_channel_tdest[7:4];
    assign c2_axi_stream_to_channel_tdest = c_axi_stream_to_channel_tdest[11:8];
    assign c3_axi_stream_to_channel_tdest = c_axi_stream_to_channel_tdest[15:12];
    assign c4_axi_stream_to_channel_tdest = c_axi_stream_to_channel_tdest[19:16];

    // connections from command manager to AXIS TX Switch
    wire axi_stream_to_channel_from_cm_tvalid, axi_stream_to_channel_from_cm_tlast, axi_stream_to_channel_from_cm_tready;
    wire [0:31] axi_stream_to_channel_from_cm_tdata;
    wire [ 0:3] axi_stream_to_channel_from_cm_tdest;


    ///////////////////////////////////////////////////////////////
    // packaged up channel connections for the AXIS RX Switch input
    wire [  4:0] c_axi_stream_to_cm_tvalid, c_axi_stream_to_cm_tlast, c_axi_stream_to_cm_tready;
    wire [159:0] c_axi_stream_to_cm_tdata;

    assign c_axi_stream_to_cm_tvalid[0] = c0_axi_stream_to_cm_tvalid;
    assign c_axi_stream_to_cm_tvalid[1] = c1_axi_stream_to_cm_tvalid;
    assign c_axi_stream_to_cm_tvalid[2] = c2_axi_stream_to_cm_tvalid;
    assign c_axi_stream_to_cm_tvalid[3] = c3_axi_stream_to_cm_tvalid;
    assign c_axi_stream_to_cm_tvalid[4] = c4_axi_stream_to_cm_tvalid;
    assign c_axi_stream_to_cm_tlast[0] = c0_axi_stream_to_cm_tlast;
    assign c_axi_stream_to_cm_tlast[1] = c1_axi_stream_to_cm_tlast;
    assign c_axi_stream_to_cm_tlast[2] = c2_axi_stream_to_cm_tlast;
    assign c_axi_stream_to_cm_tlast[3] = c3_axi_stream_to_cm_tlast;
    assign c_axi_stream_to_cm_tlast[4] = c4_axi_stream_to_cm_tlast;
    assign c0_axi_stream_to_cm_tready = c_axi_stream_to_cm_tready[0];
    assign c1_axi_stream_to_cm_tready = c_axi_stream_to_cm_tready[1];
    assign c2_axi_stream_to_cm_tready = c_axi_stream_to_cm_tready[2];
    assign c3_axi_stream_to_cm_tready = c_axi_stream_to_cm_tready[3];
    assign c4_axi_stream_to_cm_tready = c_axi_stream_to_cm_tready[4];
    assign c_axi_stream_to_cm_tdata[31:0]    = c0_axi_stream_to_cm_tdata;
    assign c_axi_stream_to_cm_tdata[63:32]   = c1_axi_stream_to_cm_tdata;
    assign c_axi_stream_to_cm_tdata[95:64]   = c2_axi_stream_to_cm_tdata;
    assign c_axi_stream_to_cm_tdata[127:96]  = c3_axi_stream_to_cm_tdata;
    assign c_axi_stream_to_cm_tdata[159:128] = c4_axi_stream_to_cm_tdata;

    // connections from AXIS RX Switch to command manager
    wire axi_stream_to_cm_from_channel_tvalid, axi_stream_to_cm_from_channel_tlast, axi_stream_to_cm_from_channel_tready;
    wire [0:31] axi_stream_to_cm_from_channel_tdata;


    //////////////////////////////////////////////////
    // IPbus and command manager interface connections
    // connections from command manager to IPbus
    wire axi_stream_to_ipbus_from_cm_tvalid, axi_stream_to_ipbus_from_cm_tlast, axi_stream_to_ipbus_from_cm_tready;
    wire [0:31] axi_stream_to_ipbus_from_cm_tdata;

    // connections from IPbus to command manager
    wire axi_stream_to_cm_from_ipbus_tvalid, axi_stream_to_cm_from_ipbus_tlast, axi_stream_to_cm_from_ipbus_tready;
    wire [0:31] axi_stream_to_cm_from_ipbus_tdata;
    wire [ 0:3] axi_stream_to_cm_from_ipbus_tdest;


    ////////////////////////////////////////////////////////
    // trigger top and command manager interface connections
    wire readout_ready, readout_done;
    wire [21:0] readout_size;
    wire send_empty_event;
    wire initiate_readout;

    wire [22:0] burst_count_chan0;
    wire [22:0] burst_count_chan1;
    wire [22:0] burst_count_chan2;
    wire [22:0] burst_count_chan3;
    wire [22:0] burst_count_chan4;

    wire [11:0] wfm_count_chan0;
    wire [11:0] wfm_count_chan1;
    wire [11:0] wfm_count_chan2;
    wire [11:0] wfm_count_chan3;
    wire [11:0] wfm_count_chan4;

    // ======== communication with the AMC13 DAQ link ========
    wire daq_header, daq_trailer;
    wire daq_valid, daq_ready;
    wire daq_almost_full;
    wire [63:0] daq_data;

    // ======== TTC Channel B information signals ========
    wire [5:0] ttc_chan_b_info;      
    wire ttc_evt_reset;         
    wire ttc_chan_b_valid;           
    wire rst_trigger_num;
    wire rst_trigger_timestamp;
    wire [1:0] fill_type;
    
    // ======== status register signals ========
    wire [31:0] status_reg0,  status_reg1,  status_reg2,  status_reg3,  status_reg4, 
                status_reg5,  status_reg6,  status_reg7,  status_reg8,  status_reg9,
                status_reg10, status_reg11, status_reg12, status_reg13, status_reg14,
                status_reg15, status_reg16, status_reg17, status_reg18;

    // ======== finite state machine states ========
    wire [ 3:0] ttr_state;
    wire [ 3:0] cac_state;
    wire [ 6:0] tp_state;
    wire [30:0] cm_state;

    // ======== trigger information signals ========
    wire [ 1:0] trig_sel;
    wire [ 7:0] trig_settings;
    wire [23:0] ttc_event_num;
    wire [23:0] ttc_trig_num;
    wire [ 1:0] ttc_trig_type;
    wire [43:0] ttc_trig_timestamp;
    wire [23:0] trig_num;
    wire [43:0] trig_timestamp;

    // ======== FIFO signals ========
    wire trig_fifo_full;
    wire acq_fifo_full;

    
    // ======== module instantiations ========

    // TTC decoder module
    TTC_decoder ttc (
        .TTC_CLK_p(ttc_clkp),        // in  STD_LOGIC
        .TTC_CLK_n(ttc_clkn),        // in  STD_LOGIC
        .TTC_rst(),                  // in  STD_LOGIC  asynchronous reset after TTC_CLK_p/TTC_CLK_n frequency changed
        .TTC_data_p(ttc_rxp),        // in  STD_LOGIC
        .TTC_data_n(ttc_rxn),        // in  STD_LOGIC
        .TTC_CLK_out(ttc_clk),       // out STD_LOGIC
        .TTCready(ttc_ready),        // out STD_LOGIC
        .L1Accept(trigger_from_ttc), // out STD_LOGIC
        .BCntRes(),                  // out STD_LOGIC
        .EvCntRes(ttc_evt_reset),    // out STD_LOGIC
        .SinErrStr(),                // out STD_LOGIC
        .DbErrStr(),                 // out STD_LOGIC
        .BrcstStr(ttc_chan_b_valid), // out STD_LOGIC
        .Brcst(ttc_chan_b_info)      // out STD_LOGIC_VECTOR (7 downto 2)
    );


    // TTC Channel B information receiver
    TTC_chanB_receiver chanb (
        .clk(ttc_clk),
        .reset(reset40),

        // TTC Channel B information
        .chan_b_info(ttc_chan_b_info),
        .evt_count_reset(ttc_evt_reset),
        .chan_b_valid(ttc_chan_b_valid),
        .ttc_loopback(ttc_loopback),

        // outputs to trigger logic
        .fill_type(fill_type[1:0]), // output [1:0]
        .reset_trig_num(rst_trigger_num),
        .reset_trig_timestamp(rst_trigger_timestamp),

        // status information
        .thres_unknown_ttc(thres_unknown_ttc), // threshold for unknown TTC broadcast command instances
        .unknown_cmd_count(unknown_cmd_count), // number of unknown TTC broadcast commands
        .error_unknown_ttc(error_unknown_ttc)  // hard error flag for unknown TTC broadcast commands
    );


    // IPbus top module
    ipbus_top ipb (
        .gt_clkp(gtx_clk0), .gt_clkn(gtx_clk0_N),
        .gt_txp(gige_tx),   .gt_txn(gige_tx_N),
        .gt_rxp(gige_rx),   .gt_rxn(gige_rx_N),
        .sfp_los(sfp_los),
        .eth_link_status(eth_link_status),
        .rst_out(rst_from_ipb),
        
        // debug ports
        .debug(),

        // clocks
        .clk_200(clk200),
        .clk_125(),
        .ipb_clk(clk125),
        .gtrefclk_out(gtrefclk0),
        
		// MAC and IP address from I2C EEPROM
        .ip_addr_rst_out(ip_addr_rst),       // IP/MAC address from EEPROM reset
		.i2c_mac_adr(i2c_mac_adr[47:0]),	 // MAC address read from I2C EEPROM
		.i2c_ip_adr(i2c_ip_adr[31:0]),		 // IP address read from I2C EEPROM
        .i2c_startup_done(i2c_startup_done), // MAC andIP will be valid when this is asserted

        // channel user space interface
        // pass out the raw IPbus signals; they're handled in the Aurora block
        .user_ipb_clk(user_ipb_clk),           // programming clock
        .user_ipb_strobe(user_ipb_strobe),     // this ipb space is selected for an I/O operation
        .user_ipb_addr(user_ipb_addr[31:0]),   // slave address, memory or register
        .user_ipb_write(user_ipb_write),       // this is a write operation
        .user_ipb_wdata(user_ipb_wdata[31:0]), // data to write for write operations
        .user_ipb_rdata(user_ipb_rdata[31:0]), // data returned for read operations
        .user_ipb_ack(user_ipb_ack),           // 'write' data has been stored, 'read' data is ready
        .user_ipb_err(1'b0),                   // '1' if error, '0' if OK? We never generate an error!

        // data interface to channel serial link
        // connections from IPbus to command manager
        .axi_stream_out_tvalid(axi_stream_to_cm_from_ipbus_tvalid),
        .axi_stream_out_tdata(axi_stream_to_cm_from_ipbus_tdata[0:31]),
        .axi_stream_out_tlast(axi_stream_to_cm_from_ipbus_tlast),
        .axi_stream_out_tdest(axi_stream_to_cm_from_ipbus_tdest),
        .axi_stream_out_tready(axi_stream_to_cm_from_ipbus_tready),
        .axi_stream_out_tstrb(),
        .axi_stream_out_tkeep(),
        .axi_stream_out_tid(),

        // connections from command manager to IPbus
        .axi_stream_in_tvalid(axi_stream_to_ipbus_from_cm_tvalid),
        .axi_stream_in_tdata(axi_stream_to_ipbus_from_cm_tdata),
        .axi_stream_in_tready(axi_stream_to_ipbus_from_cm_tready),
        .axi_stream_in_tstrb(),
        .axi_stream_in_tkeep(),
        .axi_stream_in_tlast(),
        .axi_stream_in_tid(),
        .axi_stream_in_tdest(),

        // control signals
        .trigger_out(trigger_from_ipbus),               // IPbus trigger
        .chan_done_out(),                               // channel done to trigger manager
        .chan_en_out(chan_en),                          // channel enable to command manager
        .prog_chan_out(prog_chan_start_from_ipbus),     // signal to start programming sequence for channel FPGAs
        .reprog_trigger_out(reprog_trigger_from_ipbus), // signal to issue IPROG command to re-program FPGA from flash
        .trig_delay_out(trig_delay[3:0]),               // set trigger delay in the trigger manager
        .endianness_out(endianness_sel),                // select signal for the ADC data's endianness
        .trig_settings_out(trig_settings),              // select which trigger types are enabled
        .trig_sel_out(trig_sel),                        // select which input is the trigger (TTC, IPbus, front panel)
        .ttc_loopback_out(ttc_loopback),                // select whether TTC/TTS is in loopback mode

        // threshold registers
        .thres_data_corrupt(thres_data_corrupt),   // data corruption
        .thres_unknown_ttc(thres_unknown_ttc),     // unknown TTC broadcast command
        .thres_ddr3_overflow(thres_ddr3_overflow), // DDR3 overflow

        // status registers
        .status_reg0(status_reg0),
        .status_reg1(status_reg1),
        .status_reg2(status_reg2),
        .status_reg3(status_reg3),
        .status_reg4(status_reg4),
        .status_reg5(status_reg5),
        .status_reg6(status_reg6),
        .status_reg7(status_reg7),
        .status_reg8(status_reg8),
        .status_reg9(status_reg9),
        .status_reg10(status_reg10),
        .status_reg11(status_reg11),
        .status_reg12(status_reg12),
        .status_reg13(status_reg13),
        .status_reg14(status_reg14),
        .status_reg15(status_reg15),
        .status_reg16(status_reg16),
        .status_reg17(status_reg17),
        .status_reg18(status_reg18),

        // flash interface ports
        .flash_wr_nBytes(ipbus_to_flash_wr_nBytes),
        .flash_rd_nBytes(ipbus_to_flash_rd_nBytes),
        .flash_cmd_strobe(ipbus_to_flash_cmd_strobe),
        .flash_rbuf_en(ipbus_to_flash_rbuf_en),
        .flash_rbuf_addr(ipbus_to_flash_rbuf_addr),
        .flash_rbuf_data(flash_rbuf_to_ipbus_data),
        .flash_wbuf_en(ipbus_to_flash_wbuf_en),
        .flash_wbuf_addr(ipbus_to_flash_wbuf_addr),
        .flash_wbuf_data(ipbus_to_flash_wbuf_data)
    );

 
    // Serial links to channel FPGAs
    all_channels channels (
        .clk50(clk50),
        .clk50_reset(clk50_reset),
        .axis_clk(clk125),
        .axis_clk_resetN(rst_from_ipb_n),
        .gt_refclk(gtrefclk0),
        .clk10(clk10),

        // IPbus inputs
        .ipb_clk(user_ipb_clk),           // programming clock
        .ipb_reset(rst_from_ipb),
        .ipb_strobe(user_ipb_strobe),     // this ipb space is selected for an I/O operation
        .ipb_addr(user_ipb_addr[23:0]),   // slave address(), memory or register
        .ipb_write(user_ipb_write),       // this is a write operation
        .ipb_wdata(user_ipb_wdata[31:0]), // data to write for write operations
        // IPbus outputs
        .ipb_rdata(user_ipb_rdata[31:0]), // data returned for read operations
        .ipb_ack(user_ipb_ack),           // 'write' data has been stored(), 'read' data is ready

        // channel 0 connections
        // connections to 2-byte wide AXI4-stream clock domain crossing and data buffering FIFOs
        // TX interface to slave side of transmit FIFO
        .c0_s_axi_tx_tdata(c0_axi_stream_to_channel_tdata),   // note index order
        .c0_s_axi_tx_tkeep(),                                 // note index order
        .c0_s_axi_tx_tvalid(c0_axi_stream_to_channel_tvalid),
        .c0_s_axi_tx_tlast(c0_axi_stream_to_channel_tlast),
        .c0_s_axi_tx_tready(c0_axi_stream_to_channel_tready),
        // RX interface to master side of receive FIFO
        .c0_m_axi_rx_tdata(c0_axi_stream_to_cm_tdata),        // note index order
        .c0_m_axi_rx_tkeep(),                                 // note index order
        .c0_m_axi_rx_tvalid(c0_axi_stream_to_cm_tvalid),
        .c0_m_axi_rx_tlast(c0_axi_stream_to_cm_tlast),
        .c0_m_axi_rx_tready(c0_axi_stream_to_cm_tready),      // input
        // serial I/O pins
        .c0_rxp(c0_rx), .c0_rxn(c0_rx_N),                     // receive from channel 0 FPGA
        .c0_txp(c0_tx), .c0_txn(c0_tx_N),                     // transmit to channel 0 FPGA
        // PCB traces
        .c0_readout_pause(acq_readout_pause[0]),              // readout pause signal asserted when the Aurora RX FIFO is almost full

        // channel 1 connections
        // connections to 2-byte wide AXI4-stream clock domain crossing and data buffering FIFOs
        // TX interface to slave side of transmit FIFO
        .c1_s_axi_tx_tdata(c1_axi_stream_to_channel_tdata),   // note index order
        .c1_s_axi_tx_tkeep(),                                 // note index order
        .c1_s_axi_tx_tvalid(c1_axi_stream_to_channel_tvalid),
        .c1_s_axi_tx_tlast(c1_axi_stream_to_channel_tlast),
        .c1_s_axi_tx_tready(c1_axi_stream_to_channel_tready),
        // RX interface to master side of receive FIFO
        .c1_m_axi_rx_tdata(c1_axi_stream_to_cm_tdata),        // note index order
        .c1_m_axi_rx_tkeep(),                                 // note index order
        .c1_m_axi_rx_tvalid(c1_axi_stream_to_cm_tvalid),
        .c1_m_axi_rx_tlast(c1_axi_stream_to_cm_tlast),
        .c1_m_axi_rx_tready(c1_axi_stream_to_cm_tready),      // input
        // serial I/O pins
        .c1_rxp(c1_rx), .c1_rxn(c1_rx_N),                     // receive from channel 0 FPGA
        .c1_txp(c1_tx), .c1_txn(c1_tx_N),                     // transmit to channel 0 FPGA
        // PCB traces
        .c1_readout_pause(acq_readout_pause[1]),              // readout pause signal asserted when the Aurora RX FIFO is almost full

        // channel 2 connections
        // connections to 2-byte wide AXI4-stream clock domain crossing and data buffering FIFOs
        // TX interface to slave side of transmit FIFO
        .c2_s_axi_tx_tdata(c2_axi_stream_to_channel_tdata),   // note index order
        .c2_s_axi_tx_tkeep(),                                 // note index order
        .c2_s_axi_tx_tvalid(c2_axi_stream_to_channel_tvalid),
        .c2_s_axi_tx_tlast(c2_axi_stream_to_channel_tlast),
        .c2_s_axi_tx_tready(c2_axi_stream_to_channel_tready),
        // RX interface to master side of receive FIFO
        .c2_m_axi_rx_tdata(c2_axi_stream_to_cm_tdata),        // note index order
        .c2_m_axi_rx_tkeep(),                                 // note index order
        .c2_m_axi_rx_tvalid(c2_axi_stream_to_cm_tvalid),
        .c2_m_axi_rx_tlast(c2_axi_stream_to_cm_tlast),
        .c2_m_axi_rx_tready(c2_axi_stream_to_cm_tready),      // input
        // serial I/O pins
        .c2_rxp(c2_rx), .c2_rxn(c2_rx_N),                     // receive from channel 0 FPGA
        .c2_txp(c2_tx), .c2_txn(c2_tx_N),                     // transmit to channel 0 FPGA
        // PCB traces
        .c2_readout_pause(acq_readout_pause[2]),              // readout pause signal asserted when the Aurora RX FIFO is almost full

        // channel 3 connections
        // connections to 2-byte wide AXI4-stream clock domain crossing and data buffering FIFOs
        // TX interface to slave side of transmit FIFO
        .c3_s_axi_tx_tdata(c3_axi_stream_to_channel_tdata),   // note index order
        .c3_s_axi_tx_tkeep(),                                 // note index order
        .c3_s_axi_tx_tvalid(c3_axi_stream_to_channel_tvalid),
        .c3_s_axi_tx_tlast(c3_axi_stream_to_channel_tlast),
        .c3_s_axi_tx_tready(c3_axi_stream_to_channel_tready),
        // RX interface to master side of receive FIFO
        .c3_m_axi_rx_tdata(c3_axi_stream_to_cm_tdata),        // note index order
        .c3_m_axi_rx_tkeep(),                                 // note index order
        .c3_m_axi_rx_tvalid(c3_axi_stream_to_cm_tvalid),
        .c3_m_axi_rx_tlast(c3_axi_stream_to_cm_tlast),
        .c3_m_axi_rx_tready(c3_axi_stream_to_cm_tready),      // input
        // serial I/O pins
        .c3_rxp(c3_rx), .c3_rxn(c3_rx_N),                     // receive from channel 0 FPGA
        .c3_txp(c3_tx), .c3_txn(c3_tx_N),                     // transmit to channel 0 FPGA
        // PCB traces
        .c3_readout_pause(acq_readout_pause[3]),              // readout pause signal asserted when the Aurora RX FIFO is almost full
 
        // channel 4 connections
        // connections to 2-byte wide AXI4-stream clock domain crossing and data buffering FIFOs
        // TX interface to slave side of transmit FIFO
        .c4_s_axi_tx_tdata(c4_axi_stream_to_channel_tdata),   // note index order
        .c4_s_axi_tx_tkeep(),                                 // note index order
        .c4_s_axi_tx_tvalid(c4_axi_stream_to_channel_tvalid),
        .c4_s_axi_tx_tlast(c4_axi_stream_to_channel_tlast),
        .c4_s_axi_tx_tready(c4_axi_stream_to_channel_tready),
        // RX interface to master side of receive FIFO
        .c4_m_axi_rx_tdata(c4_axi_stream_to_cm_tdata),        // note index order
        .c4_m_axi_rx_tkeep(),                                 // note index order
        .c4_m_axi_rx_tvalid(c4_axi_stream_to_cm_tvalid),
        .c4_m_axi_rx_tlast(c4_axi_stream_to_cm_tlast),
        .c4_m_axi_rx_tready(c4_axi_stream_to_cm_tready),      // input
        // serial I/O pins
        .c4_rxp(c4_rx), .c4_rxn(c4_rx_N),                     // receive from channel 0 FPGA
        .c4_txp(c4_tx), .c4_txn(c4_tx_N),                     // transmit to channel 0 FPGA
        // PCB traces
        .c4_readout_pause(acq_readout_pause[4]),              // readout pause signal asserted when the Aurora RX FIFO is almost full

        // clock synthesizer connections
        .adcclk_dclk(adcclk_dclk),
        .adcclk_ddat(adcclk_ddat),
        .adcclk_dlen(adcclk_dlen),
        .adcclk_sync(adcclk_sync),

        // analog front-end DAC connections
        .afe_dac_sclk(afe_dac_sclk),
        .afe_dac_sdi(afe_dac_sdi),
        .afe_dac_sync_n(afe_dac_sync_n),

        // counter ouputs
        .frame_err(frame_err),
        .hard_err(hard_err),
        .soft_err(soft_err),
        .channel_up(channel_up),
        .lane_up(lane_up),
        .pll_not_locked(pll_not_locked),
        .tx_resetdone_out(tx_resetdone_out),
        .rx_resetdone_out(rx_resetdone_out),
        .link_reset_out(link_reset_out),

        // debug outputs
        .debug()
    );


    // =====================================================================================
    // synchronize signals into 125 MHz clock domain for use in status register block module 
    // =====================================================================================

    // synchronize ttc_ready
    wire ttc_ready_clk125;
    sync_2stage ttc_ready_sync (
        .clk(clk125),
        .in(ttc_ready),
        .out(ttc_ready_clk125)
    );

    // synchronize ttc_chan_b_info
    wire [5:0] ttc_chan_b_info_clk125;
    sync_2stage #(
        .WIDTH(6)
    ) ttc_chan_b_info_sync (
        .clk(clk125),
        .in(ttc_chan_b_info),
        .out(ttc_chan_b_info_clk125)
    );

    // synchronize ttr_state
    wire [3:0] ttr_state_clk125;
    sync_2stage #(
        .WIDTH(4)
    ) ttr_state_sync (
        .clk(clk125),
        .in(ttr_state),
        .out(ttr_state_clk125)
    );

    // synchronize cac_state
    wire [3:0] cac_state_clk125;
    sync_2stage #(
        .WIDTH(4)
    ) cac_state_sync0 (
        .clk(clk125),
        .in(cac_state),
        .out(cac_state_clk125)
    );

    // synchronize fill_type
    wire [1:0] fill_type_clk125;
    sync_2stage #(
        .WIDTH(2)
    ) fill_type_sync (
        .clk(clk125),
        .in(fill_type),
        .out(fill_type_clk125)
    );

    // synchronize trig_num
    wire [23:0] trig_num_clk125;
    sync_2stage #(
        .WIDTH(24)
    ) trig_num_sync (
        .clk(clk125),
        .in(trig_num),
        .out(trig_num_clk125)
    );

    // synchronize trig_timestamp
    wire [43:0] trig_timestamp_clk125;
    sync_2stage #(
        .WIDTH(44)
    ) trig_timestamp_sync (
        .clk(clk125),
        .in(trig_timestamp),
        .out(trig_timestamp_clk125)
    );


    // status register assembly
    status_reg_block status_reg_block (
        .clk(clk125),
        .reset(rst_from_ipb),

        // status inputs
        .prog_chan_done(prog_chan_done),
        .thres_data_corrupt(thres_data_corrupt),
        .thres_unknown_ttc(thres_unknown_ttc),
        .thres_ddr3_overflow(thres_ddr3_overflow),
        .unknown_cmd_count(unknown_cmd_count),
        .ddr3_overflow_count(ddr3_overflow_count),
        .cs_mismatch_count(cs_mismatch_count),
        .error_data_corrupt(error_data_corrupt),
        .error_trig_num_from_tt(error_trig_num_from_tt),
        .error_trig_type_from_tt(error_trig_type_from_tt),
        .error_trig_num_from_cm(error_trig_num_from_cm),
        .error_trig_type_from_cm(error_trig_type_from_cm),
        .error_pll_unlock(error_pll_unlock),
        .error_trig_rate(error_trig_rate),
        .error_unknown_ttc(error_unknown_ttc),
        .ddr3_overflow_warning(ddr3_overflow_warning),
        .chan_error_rc(chan_error_rc),
        .daq_clk_sel(daq_clk_sel),
        .daq_clk_en(daq_clk_en),
        .adcclk_clkin0_stat(adcclk_clkin0_stat),
        .adcclk_clkin1_stat(adcclk_clkin1_stat),
        .adcclk_stat_ld(adcclk_stat_ld),
        .adcclk_stat(adcclk_stat),
        .daq_almost_full(daq_almost_full),
        .daq_ready(daq_ready),
        .tts_state(tts_state),
        .ttc_chan_b_info(ttc_chan_b_info_clk125),
        .ttc_ready(ttc_ready_clk125),
        .cm_state(cm_state),
        .ttr_state(ttr_state_clk125),
        .cac_state(cac_state_clk125),
        .tp_state(tp_state),
        .acq_readout_pause(acq_readout_pause),
        .fill_type(fill_type_clk125),
        .chan_en(chan_en),
        .endianness_sel(endianness_sel),
        .trig_fifo_full(trig_fifo_full),
        .acq_fifo_full(acq_fifo_full),
        .trig_delay(trig_delay),
        .trig_settings(trig_settings),
        .trig_num(trig_num_clk125),
        .trig_timestamp(trig_timestamp_clk125),

        // status register outputs
        .status_reg0(status_reg0),
        .status_reg1(status_reg1),
        .status_reg2(status_reg2),
        .status_reg3(status_reg3),
        .status_reg4(status_reg4),
        .status_reg5(status_reg5),
        .status_reg6(status_reg6),
        .status_reg7(status_reg7),
        .status_reg8(status_reg8),
        .status_reg9(status_reg9),
        .status_reg10(status_reg10),
        .status_reg11(status_reg11),
        .status_reg12(status_reg12),
        .status_reg13(status_reg13),
        .status_reg14(status_reg14),
        .status_reg15(status_reg15),
        .status_reg16(status_reg16),
        .status_reg17(status_reg17),
        .status_reg18(status_reg18)
    );


    wire trigger_mux; // selected trigger source
    assign trigger_mux = (trig_sel[1:0] == 2'b01) ? trigger_from_ipbus_sync :
                         (trig_sel[1:0] == 2'b10) ? ext_trig_sync           :
                                                    trigger_from_ttc;

    // trigger top module
    trigger_top trigger_top (
        // clocks
        .ttc_clk(ttc_clk), //  40 MHz
        .clk125(clk125),   // 125 MHz

        // resets
        .reset40(reset40),           // in  40 MHz clock domain
        .reset40_n(reset40_n),       // in  40 MHz clock domain
        .rst_from_ipb(rst_from_ipb), // in 125 MHz clock domain

        .rst_trigger_num(rst_trigger_num),             // from TTC Channel B
        .rst_trigger_timestamp(rst_trigger_timestamp), // from TTC Channel B

        // trigger interface
        .trigger(trigger_mux),                     // trigger signal
        .trig_type(fill_type),                     // trigger type (muon fill, laser, pedestal)
        .trig_settings(trig_settings),             // trigger settings
        .chan_en(chan_en),                         // enabled channels
        .trig_delay(trig_delay),                   // trigger delay
        .thres_ddr3_overflow(thres_ddr3_overflow), // DDR3 overflow threshold

        // channel interface
        .chan_dones(acq_dones),
        .chan_enable(acq_enable),
        .chan_trig(acq_trigs),

        // command manager interface
        .readout_ready(readout_ready),       // command manager is idle
        .readout_done(readout_done),         // initiated readout has finished
        .readout_size(readout_size),         // burst count of readout event
        .send_empty_event(send_empty_event), // request an empty event
        .initiate_readout(initiate_readout), // request for the channels to be read out

        .ttc_event_num(ttc_event_num),           // channel's trigger number
        .ttc_trig_num(ttc_trig_num),             // global trigger number
        .ttc_trig_type(ttc_trig_type),           // trigger type
        .ttc_trig_timestamp(ttc_trig_timestamp), // trigger timestamp

        .burst_count_chan0(burst_count_chan0), // burst count set for Channel 0
        .burst_count_chan1(burst_count_chan1), // burst count set for Channel 1
        .burst_count_chan2(burst_count_chan2), // burst count set for Channel 2
        .burst_count_chan3(burst_count_chan3), // burst count set for Channel 3
        .burst_count_chan4(burst_count_chan4), // burst count set for Channel 4

        .wfm_count_chan0(wfm_count_chan0), // waveform count set for Channel 0
        .wfm_count_chan1(wfm_count_chan1), // waveform count set for Channel 1
        .wfm_count_chan2(wfm_count_chan2), // waveform count set for Channel 2
        .wfm_count_chan3(wfm_count_chan3), // waveform count set for Channel 3
        .wfm_count_chan4(wfm_count_chan4), // waveform count set for Channel 4

        // status connections
        .ttr_state(ttr_state),           // TTC trigger receiver state
        .cac_state(cac_state),           // channel acquisition controller state
        .tp_state(tp_state),             // trigger processor state
        .trig_num(trig_num),             // global trigger number
        .trig_timestamp(trig_timestamp), // timestamp for latest trigger received
        .trig_fifo_full(trig_fifo_full), // TTC trigger FIFO is almost full
        .acq_fifo_full(acq_fifo_full),   // acquisition event FIFO is almost full

        // error connections
        .ddr3_overflow_count(ddr3_overflow_count),     // number of triggers received that would overflow DDR3
        .ddr3_overflow_warning(ddr3_overflow_warning), // DDR3 overflow warning
        .error_trig_rate(error_trig_rate),             // trigger rate error
        .error_trig_num(error_trig_num_from_tt),       // trigger number error
        .error_trig_type(error_trig_type_from_tt)      // trigger type error
    );

    
    // create a DAQ ready signal to indicate that it's ready to receive data words, used by the command manager
    // pull down DAQ link 'ready' whenever its 'almost_full' is asserted for the previous two clock cycles
    wire daq_ready_for_data;
    assign daq_ready_for_data = daq_ready & ~daq_almost_full;

    // command manager module
    command_manager command_manager (
        // user interface clock and reset
        .clk(clk125),       // input
        .rst(rst_from_ipb), // input

        // interface to TX channel FIFO (through AXI4-Stream TX Switch)
        .chan_tx_fifo_ready(axi_stream_to_channel_from_cm_tready), // input
        .chan_tx_fifo_valid(axi_stream_to_channel_from_cm_tvalid), // output
        .chan_tx_fifo_last(axi_stream_to_channel_from_cm_tlast),   // output
        .chan_tx_fifo_dest(axi_stream_to_channel_from_cm_tdest),   // output [ 3:0]
        .chan_tx_fifo_data(axi_stream_to_channel_from_cm_tdata),   // output [31:0]

        // interface to RX channel FIFO (through AXI4-Stream RX Switch)
        .chan_rx_fifo_valid(axi_stream_to_cm_from_channel_tvalid), // input
        .chan_rx_fifo_last(axi_stream_to_cm_from_channel_tlast),   // input
        .chan_rx_fifo_data(axi_stream_to_cm_from_channel_tdata),   // input [31:0]
        .chan_rx_fifo_ready(axi_stream_to_cm_from_channel_tready), // output

        // interface to IPbus AXI output
        .ipbus_cmd_valid(axi_stream_to_cm_from_ipbus_tvalid), // input
        .ipbus_cmd_last(axi_stream_to_cm_from_ipbus_tlast),   // input
        .ipbus_cmd_dest(axi_stream_to_cm_from_ipbus_tdest),   // input [ 3:0]
        .ipbus_cmd_data(axi_stream_to_cm_from_ipbus_tdata),   // input [31:0]
        .ipbus_cmd_ready(axi_stream_to_cm_from_ipbus_tready), // output

        // interface to IPbus AXI input
        .ipbus_res_ready(axi_stream_to_ipbus_from_cm_tready), // input
        .ipbus_res_valid(axi_stream_to_ipbus_from_cm_tvalid), // output
        .ipbus_res_last(axi_stream_to_ipbus_from_cm_tlast),   // output
        .ipbus_res_data(axi_stream_to_ipbus_from_cm_tdata),   // output [31:0]

        // interface to AMC13 DAQ Link
        .daq_ready(daq_ready_for_data),    // input
        .daq_almost_full(daq_almost_full), // input
        .daq_valid(daq_valid),             // output
        .daq_header(daq_header),           // output
        .daq_trailer(daq_trailer),         // output
        .daq_data(daq_data),               // output [63:0]

        // interface to trigger processor
        .send_empty_event(send_empty_event), // request to send an empty event
        .initiate_readout(initiate_readout), // request for the channels to be read out
        .event_num(ttc_event_num),           // channel's trigger number
        .trig_num(ttc_trig_num),             // global trigger number, starts at 1
        .trig_type(ttc_trig_type),           // trigger type
        .trig_timestamp(ttc_trig_timestamp), // trigger timestamp, defined by when trigger is received by trigger receiver module
        .readout_ready(readout_ready),       // ready to readout data, i.e., when in idle state
        .readout_done(readout_done),         // finished readout flag
        .readout_size(readout_size),         // burst count of readout event

        .burst_count_chan0(burst_count_chan0), // burst count set for Channel 0
        .burst_count_chan1(burst_count_chan1), // burst count set for Channel 1
        .burst_count_chan2(burst_count_chan2), // burst count set for Channel 2
        .burst_count_chan3(burst_count_chan3), // burst count set for Channel 3
        .burst_count_chan4(burst_count_chan4), // burst count set for Channel 4

        .wfm_count_chan0(wfm_count_chan0), // waveform count set for Channel 0
        .wfm_count_chan1(wfm_count_chan1), // waveform count set for Channel 1
        .wfm_count_chan2(wfm_count_chan2), // waveform count set for Channel 2
        .wfm_count_chan3(wfm_count_chan3), // waveform count set for Channel 3
        .wfm_count_chan4(wfm_count_chan4), // waveform count set for Channel 4

        // status connections
        .i2c_mac_adr(i2c_mac_adr[47:0]),         // input  [47:0], MAC address from EEPROM
        .chan_en(chan_en),                       // input  [ 4:0], enabled channels from IPbus
        .endianness_sel(endianness_sel),         // input, from IPbus
        .thres_data_corrupt(thres_data_corrupt), // input  [31:0], from IPbus
        .state(cm_state),                        // output [30:0]

        // error connections
        .cs_mismatch_count(cs_mismatch_count),     // number of checksum mismatches
        .error_data_corrupt(error_data_corrupt),   // output, data corruption error
        .error_trig_num(error_trig_num_from_cm),   // output, trigger number mismatch between channel and master
        .error_trig_type(error_trig_type_from_cm), // output, trigger type mismatch between channel and master
        .chan_error_rc(chan_error_rc[4:0])         // output [ 4:0]
    );
    

    // TTS state reported to DAQ link
    TTS_reporter tts_reporter (
        .clk(clk125),
        .reset(rst_from_ipb),

        // error status
        .error_data_corrupt(error_data_corrupt),
        .error_pll_unlock(error_pll_unlock),
        .error_trig_rate(error_trig_rate),
        .error_unknown_ttc(error_unknown_ttc),

        // sync lost status
        .error_trig_num_from_tt(error_trig_num_from_tt),
        .error_trig_num_from_cm(error_trig_num_from_cm),
        .error_trig_type_from_tt(error_trig_type_from_tt),
        .error_trig_type_from_cm(error_trig_type_from_cm),

        // overflow warning status
        .ddr3_overflow_warning(ddr3_overflow_warning),

        // TTS state output
        .tts_state(tts_state)
    );


    // DAQ Link to AMC13, version 0x10
    DAQ_LINK_Kintex #(
        .F_REFCLK(125),
        .SYSCLK_IN_period(8),
        .USE_TRIGGER_PORT(1'b0)
    ) daq (
        .reset(rst_from_ipb),

        .GTX_REFCLK(gtrefclk0),
        .GTX_RXN(daq_rx_N),
        .GTX_RXP(daq_rx),
        .GTX_TXN(daq_tx_N),
        .GTX_TXP(daq_tx),
        .SYSCLK_IN(clk125),

        .TTCclk(clk125),
        .BcntRes(rst_from_ipb),
        .trig({ 8{trigger_from_ttc} }),

        .TTSclk(clk125),
        .TTS(tts_state),

	    .ReSyncAndEmpty(1'b0),           // added input signal ReSyncAndEmpty for proper ReSync operation; set to 0 because likely won't be used
        .EventDataClk(clk125),
        .EventData_valid(daq_valid),
        .EventData_header(daq_header),   // flag to indicate first AMC13 header word
        .EventData_trailer(daq_trailer), // flag to indicate AMC13 trailer word
        .EventData(daq_data),            // 64-bit data words to send to AMC13
        .AlmostFull(daq_almost_full),    // DAQ link buffer is almost full (space for only 10 additional words)
        .Ready(daq_ready)                // flag to indicate link status during initialization
                                         // Mr. Wu: "It goes low when initialization starts and goes up when initialization is done."
    );


    // AXIS TX Switch
    axis_switch_tx tx_switch (
        .aclk(clk125),            // input
        .aresetn(rst_from_ipb_n), // input

        // command manager side
        .s_axis_tvalid(axi_stream_to_channel_from_cm_tvalid), // input
        .s_axis_tready(axi_stream_to_channel_from_cm_tready), // output
        .s_axis_tdata(axi_stream_to_channel_from_cm_tdata),   // input [31:0]
        .s_axis_tdest(axi_stream_to_channel_from_cm_tdest),   // input [ 3:0]
        .s_axis_tlast(axi_stream_to_channel_from_cm_tlast),   // input

        // channel FPGA side
        .m_axis_tvalid(c_axi_stream_to_channel_tvalid), // output [  4:0]
        .m_axis_tready(c_axi_stream_to_channel_tready), // input  [  4:0]
        .m_axis_tdata(c_axi_stream_to_channel_tdata),   // output [159:0]
        .m_axis_tdest(c_axi_stream_to_channel_tdest),   // output [ 19:0]
        .m_axis_tlast(c_axi_stream_to_channel_tlast),   // output [  4:0]
        
        // unused output port
        .s_decode_err()
    );


    // AXIS RX Switch
    wire [4:0] s_req_suppress = 5'b0; // active-high skips next arbitration cycle
    axis_switch_rx rx_switch (
        .aclk(clk125),                   // input
        .aresetn(rst_from_ipb_n),        // input
        .s_req_suppress(s_req_suppress), // input [4:0]

        // channel FPGA side
        .s_axis_tvalid(c_axi_stream_to_cm_tvalid), // input  [  4:0]
        .s_axis_tready(c_axi_stream_to_cm_tready), // output [  4:0]
        .s_axis_tlast(c_axi_stream_to_cm_tlast),   // input  [  4:0]
        .s_axis_tdata(c_axi_stream_to_cm_tdata),   // input  [159:0]

        // command manager side
        .m_axis_tvalid(axi_stream_to_cm_from_channel_tvalid), // output
        .m_axis_tready(axi_stream_to_cm_from_channel_tready), // input
        .m_axis_tlast(axi_stream_to_cm_from_channel_tlast),   // output
        .m_axis_tdata(axi_stream_to_cm_from_channel_tdata),   // output [31:0]
        
        // unused output port
        .s_decode_err()
    );

endmodule
