// top-level module for g-2 WFD5 Master FPGA

// as a useful reference, here's the syntax to mark signals for debug:
// (* mark_debug = "true" *) 

module wfd_top(
    input wire  clkin,                // 50 MHz clock
	input wire  gtx_clk0, gtx_clk0_N, // Bank 115 125 MHz GTX Transceiver refclk
	input wire  gtx_clk1, gtx_clk1_N, // Bank 116 125 MHz GTX Transceiver refclk
	output wire gige_tx,  gige_tx_N,  // Gigabit Ethernet TX
	input wire  gige_rx,  gige_rx_N,  // Gigabit Ethernet RX
    input wire  daq_rx,   daq_rx_N,   // AMC13 Link RX
    output wire daq_tx,   daq_tx_N,   // AMC13 Link TX
    input wire  c0_rx, c0_rx_N,       // Serial link to Channel 0 RX
    output wire c0_tx, c0_tx_N,       // Serial link to Channel 0 TX
    input wire  c1_rx, c1_rx_N,       // Serial link to Channel 1 RX
    output wire c1_tx, c1_tx_N,       // Serial link to Channel 1 TX
    input wire  c2_rx, c2_rx_N,       // Serial link to Channel 2 RX
    output wire c2_tx, c2_tx_N,       // Serial link to Channel 2 TX
    input wire  c3_rx, c3_rx_N,       // Serial link to Channel 3 RX
    output wire c3_tx, c3_tx_N,       // Serial link to Channel 3 TX
    input wire  c4_rx, c4_rx_N,       // Serial link to Channel 4 RX
    output wire c4_tx, c4_tx_N,       // Serial link to Channel 4 TX
    output wire debug0,               // debug header
    output wire debug1,               // debug header
    output wire debug2,               // debug header
    input wire debug3,                // debug header (used for board id)
    input wire debug4,                // debug header (used for board id)
    input wire debug5,                // debug header (used for board id)
    output wire debug6,               // debug header
    output wire debug7,               // debug header
    output wire[4:0] acq_trigs,       // triggers to channel FPGAs
    input [4:0] acq_dones,            // done signals from channel FPGAs
    output wire led0, led1,           // front panel LEDs. led0 is green, led1 is red
    inout bbus_scl,                   // I2C bus clock, connected to Atmel Chip and to Channel FPGAs
    inout bbus_sda,                   // I2C bus data, connected to Atmel Chip and to Channel FPGAs
	input wire ext_trig,              // front panel trigger
	input [3:0] mmc_io,               // controls to/from the Atmel
	output [3:0] c0_io,               // utility signals to channel 0
	output [3:0] c1_io,               // utility signals to channel 1
	output [3:0] c2_io,               // utility signals to channel 2
	output [3:0] c3_io,               // utility signals to channel 3
	output [3:0] c4_io,               // utility signals to channel 4
    input [5:0] mezzb,                // MB[5..0] on schematic
    input mmc_reset_m,                // reset line 
	// output adcclk_ld,              //
	output adcclk_goe,                //
	output adcclk_sync,               //
	// output adcclk_los0,            //
	// output adcclk_los1,            //
	output adcclk_dlen,               //
	output adcclk_ddat,               //
	output adcclk_dclk,               //
	output daq_clk_sel,               //
	output daq_clk_en,                //
	// TTC connections
	input ttc_clkp, ttc_clkn,         // TTC diff clock
	input ttc_rxp, ttc_rxn,           // data from TTC
	output ttc_txp, ttc_txn,          // data to TTC
	// Power Supply connections
	input [1:0] wfdps,                //
	// Channel FPGA configuration connections
    output c_progb,                   // to all channels FPGA Configuration
    output c_clk,                     // to all channels FPGA Configuration
    output c_din,                     // to all channels FPGA Configuration
    input [4:0] initb,                // from each channel FPGA Configuration
    input [4:0] prog_done,            // from each channel FPGA Configuration
    input test,                       //
    input spi_miso,                   // serial data from SPI flash memory
    output spi_mosi,                  // serial data (commands) to SPI flash memory
    output spi_ss                     // SPI flash memory chip select
);


    // ======== clock signals ========
    wire clk50;
    wire clk125;
    wire clk200;
    wire clkfb;
    wire gtrefclk0;
    wire pll_lock;

    assign clk50 = clkin; // just to make the frequency explicit

    // ======== LEDs ========
    
    // green LED is on when TTC is not ready
    wire TTCready;
    assign led0 = TTCready;

    // LED flasher module -- red LED flashes when FPGA is programmed
    led_flasher led_flasher(
        .clk(clk50),
        .led(led1)
    );

	// debug signals
    assign debug0 = spi_clk;
    assign debug1 = spi_mosi;
    assign debug2 = spi_miso;
    assign debug6 = spi_ss;

    // dummy use of signals
    assign debug7 = prog_done[4] & prog_done[3] & prog_done[2] & prog_done[1] & prog_done[0] & wfdps[0] & wfdps[1] & mmc_reset_m & mezzb[0] & mezzb[1] & mezzb[2] & mezzb[3] & mezzb[4] & mezzb[5] & acq_dones[0] & acq_dones[1] & acq_dones[2] & acq_dones[3] & acq_dones[4] &  mmc_io[2] & mmc_io[3] & ext_trig_sync & initb[4] & initb[3] & initb[2] & initb[1] & initb[0];

    assign c0_io[0] = 1'b0;
    assign c0_io[1] = 1'b0;
    assign c1_io[0] = 1'b0;
    assign c1_io[1] = 1'b0;
    assign c2_io[0] = 1'b0;
    assign c2_io[1] = 1'b0;
    assign c3_io[0] = 1'b0;
    assign c3_io[1] = 1'b0;
    assign c4_io[0] = 1'b0;
    assign c4_io[1] = 1'b0;


    // (active-high) reset signal to channels
    assign c0_io[3] = rst_from_ipb;
    assign c1_io[3] = rst_from_ipb;
    assign c2_io[3] = rst_from_ipb;
    assign c3_io[3] = rst_from_ipb;
    assign c4_io[3] = rst_from_ipb;

    // trigger arm signal for trigger manager
    wire [4:0] trig_arm;
    assign c0_io[2] = trig_arm[0];
    assign c1_io[2] = trig_arm[1];
    assign c2_io[2] = trig_arm[2];
    assign c3_io[2] = trig_arm[3];
    assign c4_io[2] = trig_arm[4];

    // use three of the debug pins as inputs for unique board identification
    wire [2:0] board_id;
    assign board_id[2] = debug3;
    assign board_id[1] = debug4;
    assign board_id[0] = debug5;

	assign bbus_scl = ext_trig ? mmc_io[0] : 1'bz;
	assign bbus_sda = ext_trig ? mmc_io[1] : 1'bz;
	// assign adcclk_ld = 1'b0;
	// assign adcclk_goe = 1'b0;
	// assign adcclk_sync = 1'b0;
	// assign adcclk_los0 = 1'b0;
	// assign adcclk_los1 = 1'b0;
	// assign adcclk_dlen = 1'b0;
	// assign adcclk_ddat = 1'b0;
	// assign adcclk_dclk = 1'b0;
	assign daq_clk_sel = 1'b0;
	assign daq_clk_en = 1'b1;

	OBUFDS ttc_tx_buf(.I(ttc_rx), .O(ttc_txp), .OB(ttc_txn)); 

    // Generate clocks from the 50 MHz input clock
    // Most of the design is run from the 125 MHz clock (Don't confuse it with the 125 MHz GTREFCLK)
    // clk200 acts as the independent clock required by the Gigabit ethernet IP
    PLLE2_BASE #(
        .CLKFBOUT_MULT(20.0),
        .CLKIN1_PERIOD(20), // in ns, so 20 -> 50 MHz
        .CLKOUT0_DIVIDE(5),
        .CLKOUT1_DIVIDE(8)
    ) clk (
        .CLKIN1(clkin),
        .CLKOUT0(clk200),
        .CLKOUT1(clk125),
        .CLKOUT2(),
        .CLKOUT3(),
        .CLKOUT4(),
        .CLKOUT5(),
        .LOCKED(pll_lock),
        .RST(0),
        .PWRDWN(0),
        .CLKFBOUT(clkfb),
        .CLKFBIN(clkfb)
    );

    // ======== ethernet status signals ========
    reg sfp_los = 0;      // loss of signal for gigabit ethernet. Not used
    wire eth_link_status; // link status of gigabit ethernet

    // ======== reset signals ========
    wire rst_from_ipb;            // reset from IPbus. Synchronous to IPbus clock
    wire rst_n;                   // active low reset
    assign rst_n = ~rst_from_ipb;

    // Synchronize reset from IPbus clock domain to other domains
    wire clk50_reset;
    resets r (
        .ipb_rst_in(rst_from_ipb),
        .ipb_clk(clk125),
        .clk50(clk50),
        .rst_clk50(clk50_reset)
    );

    
    // ================== communicate with SPI flash memory ==================

    // The startup block will give us access to the SPI clock pin (which is otherwise reserved for use during FPGA configuration)
    // STARTUPE2: STARTUP Block
    //            7  Series
    // Xilinx HDL Libraries Guide, version 13.3
    STARTUPE2 #(
        .PROG_USR("FALSE"),  // Activate program event security feature. Requires encrypted bitstreams.
        .SIM_CCLK_FREQ(0.0)  // Set the Configuration Clock Frequency(ns) for simulation.
    )
    STARTUPE2_inst (
        .CFGCLK(),         // 1-bit output: Configuration main clock output
        .CFGMCLK(),        // 1-bit output: Configuration internal oscillator clock output
        .EOS(),            // 1-bit output: Active high output signal indicating the End Of Startup.
        .PREQ(),           // 1-bit output: PROGRAM request to fabric output
        .CLK(0),           // 1-bit input: User start-up clock input
        .GSR(0),           // 1-bit input: Global Set/Reset input (GSR cannot be used for the port name)
        .GTS(0),           // 1-bit input: Global 3-state input (GTS cannot be used for the port name)
        .KEYCLEARB(0),     // 1-bit input: Clear AES Decrypter Key input from Battery-Backed RAM (BBRAM)
        .PACK(0),          // 1-bit input: PROGRAM acknowledge input
        .USRCCLKO(spi_clk),// 1-bit input: User CCLK input
        .USRCCLKTS(0),     // 1-bit input: User CCLK 3-state enable input
        .USRDONEO(0),      // 1-bit input: User DONE pin output control
        .USRDONETS(0)      // 1-bit input: User DONE 3-state enable output
    );
    //  End of STARTUPE2_inst instantiation


    wire [31:0] spi_data;
    wire read_bitstream;
    wire end_bitstream;

    wire [8:0] ipbus_to_flash_wr_nBytes;
    wire [8:0] ipbus_to_flash_rd_nBytes;
    wire ipbus_to_flash_cmd_strobe;
    wire flash_to_ipbus_cmd_ack;
    wire ipbus_to_flash_rbuf_en;
    wire [6:0] ipbus_to_flash_rbuf_addr;
    wire [31:0] flash_rbuf_to_ipbus_data;
    wire ipbus_to_flash_wbuf_en;
    wire [6:0] ipbus_to_flash_wbuf_addr;
    wire [31:0] ipbus_to_flash_wbuf_data;

    spi_flash_intf spi_flash_intf(
        .clk(clk50),
        .ipb_clk(clk125),
        .reset(clk50_reset),
        .spi_clk(spi_clk),
        .spi_mosi(spi_mosi),
        .spi_miso(spi_miso),
        .spi_ss(spi_ss),
        .prog_chan_in_progress(prog_chan_in_progress), // signal from prog_channels
        .read_bitstream(read_bitstream), // start signal from prog_channels
        .end_bitstream(end_bitstream), // done signal to prog_channels
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
        .pc_wbuf_data_in(32'h03CE0000)    // hardcode read command for channel bitstream
    );

    // ======== program channel FPGAs using bistream stored on SPI flash memory ========

    wire prog_chan_start_from_ipbus; // in 125 MHz clock domain
    wire prog_chan_start; // in 50 MHz clock domain 
             // don't have to worry about missing the faster signal -- stays high 
             // until you use ipbus to set it low again
    sync_2stage prog_chan_start_sync(
        .clk(clk50),
        .in(prog_chan_start_from_ipbus),
        .out(prog_chan_start)
    );

    prog_channels prog_channels(
        .clk(clk50),
        .reset(clk50_reset),
        .prog_chan_start(prog_chan_start), // start signal from IPbus
        .c_progb(c_progb),      // configuration signal to all five channels
        .c_clk(c_clk),          // configuration clock to all five channels
        .c_din(c_din),          // configuration bitstream to all five channels
        .initb(initb),          // configuration signals from each channel
        .prog_done(prog_done),  // configuration signals from each channel
        .bitstream(spi_miso),   // bitstream from flash memory
        .prog_chan_in_progress(prog_chan_in_progress), // signal to spi_flash_intf
        .store_flash_command(pc_to_flash_wbuf_en), // signal to spi_flash_intf
        .read_bitstream(read_bitstream), // start signal to spi_flash_intf
        .end_bitstream(end_bitstream) // done signal from spi_flash_intf
    );


    // ======== triggers and data transfer ========

    // TTC trigger in TTC clock domain
    wire ttc_L1A;

    // trigger signals in 125 MHz clock domain
    wire ext_trig_sync;
    wire trigger_from_ipbus;
    wire trigger_from_ttc;

    // Put the external trigger into the 125 MHz clock domain
    sync_2stage trig_sync(
        .clk(clk125),
        .in(ext_trig),
        .out(ext_trig_sync)
    );

    // Put the TTC trigger into the 125 MHz clock domain
    sync_2stage ttc_trig_sync(
        .clk(clk125),
        .in(ttc_L1A),
        .out(trigger_from_ttc)
    );


    // done signals from channels
    wire[4:0] acq_dones_sync;
    sync_2stage acq_dones_sync0(
        .clk(clk125),
        .in(acq_dones[0]),
        .out(acq_dones_sync[0])
    );
    sync_2stage acq_dones_sync1(
        .clk(clk125),
        .in(acq_dones[1]),
        .out(acq_dones_sync[1])
    );
    sync_2stage acq_dones_sync2(
        .clk(clk125),
        .in(acq_dones[2]),
        .out(acq_dones_sync[2])
    );
    sync_2stage acq_dones_sync3(
        .clk(clk125),
        .in(acq_dones[3]),
        .out(acq_dones_sync[3])
    );
    sync_2stage acq_dones_sync4(
        .clk(clk125),
        .in(acq_dones[4]),
        .out(acq_dones_sync[4])
    );


    // enable signals to channels
    wire[4:0] chan_en;

    // wires connecting the trig number fifo to the tm
    wire tm_to_fifo_tvalid, tm_to_fifo_tready;
    wire[23:0] tm_to_fifo_tdata;

    wire fifo_to_cm_tvalid, fifo_to_cm_tready;
    wire[23:0] fifo_to_cm_tdata;

    // wire connecting the tm and the cm
    wire cm_busy;


    // ======== wires for interface to channel serial link ========
    // User IPbus interface. Used by Charlie's Aurora block
    wire [31:0] user_ipb_addr, user_ipb_wdata, user_ipb_rdata;
    wire user_ipb_clk, user_ipb_strobe, user_ipb_write, user_ipb_ack;


    ////////////////////////////////////////////////////////////////////////////////////////////////////
    // AXI4-Stream interface for communicating with serial link to channel FPGA
    // channel 0
    wire c0_axi_stream_to_cm_tvalid, c0_axi_stream_to_cm_tlast, c0_axi_stream_to_cm_tready;
    wire[0:31] c0_axi_stream_to_cm_tdata;

    wire c0_axi_stream_to_channel_tvalid, c0_axi_stream_to_channel_tlast, c0_axi_stream_to_channel_tready;
    wire[0:31] c0_axi_stream_to_channel_tdata;

    // channel 1
    wire c1_axi_stream_to_cm_tvalid, c1_axi_stream_to_cm_tlast, c1_axi_stream_to_cm_tready;
    wire[0:31] c1_axi_stream_to_cm_tdata;

    wire c1_axi_stream_to_channel_tvalid, c1_axi_stream_to_channel_tlast, c1_axi_stream_to_channel_tready;
    wire[0:31] c1_axi_stream_to_channel_tdata;
    wire[0:3]  c1_axi_stream_to_channel_tdest;

    // channel 2
    wire c2_axi_stream_to_cm_tvalid, c2_axi_stream_to_cm_tlast, c2_axi_stream_to_cm_tready;
    wire[0:31] c2_axi_stream_to_cm_tdata;

    wire c2_axi_stream_to_channel_tvalid, c2_axi_stream_to_channel_tlast, c2_axi_stream_to_channel_tready;
    wire[0:31] c2_axi_stream_to_channel_tdata;
    wire[0:3]  c2_axi_stream_to_channel_tdest;

    // channel 3
    wire c3_axi_stream_to_cm_tvalid, c3_axi_stream_to_cm_tlast, c3_axi_stream_to_cm_tready;
    wire[0:31] c3_axi_stream_to_cm_tdata;

    wire c3_axi_stream_to_channel_tvalid, c3_axi_stream_to_channel_tlast, c3_axi_stream_to_channel_tready;
    wire[0:31] c3_axi_stream_to_channel_tdata;
    wire[0:3]  c3_axi_stream_to_channel_tdest;

    // channel 4
    wire c4_axi_stream_to_cm_tvalid, c4_axi_stream_to_cm_tlast, c4_axi_stream_to_cm_tready;
    wire[0:31] c4_axi_stream_to_cm_tdata;

    wire c4_axi_stream_to_channel_tvalid, c4_axi_stream_to_channel_tlast, c4_axi_stream_to_channel_tready;
    wire[0:31] c4_axi_stream_to_channel_tdata;
    wire[0:3]  c4_axi_stream_to_channel_tdest;


    ////////////////////////////////////////////////////////////////////////////////////////////////////
    // packaged up channel connections for the axis tx switch output
    wire[4:0]   c_axi_stream_to_channel_tvalid, c_axi_stream_to_channel_tlast, c_axi_stream_to_channel_tready;
    wire[19:0]  c_axi_stream_to_channel_tdest;
    wire[159:0] c_axi_stream_to_channel_tdata;

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

    // connections from cm to axis tx switch
    wire axi_stream_to_channel_from_cm_tvalid, axi_stream_to_channel_from_cm_tlast, axi_stream_to_channel_from_cm_tready;
    wire[0:31] axi_stream_to_channel_from_cm_tdata;
    wire[0:3]  axi_stream_to_channel_from_cm_tdest;


    ////////////////////////////////////////////////////////////////////////////////////////////////////
    // packaged up channel connections for the axis rx switch input
    wire[4:0]   c_axi_stream_to_cm_tvalid, c_axi_stream_to_cm_tlast, c_axi_stream_to_cm_tready;
    wire[159:0] c_axi_stream_to_cm_tdata;

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

    // connections from axis rx switch to cm
    wire axi_stream_to_cm_from_channel_tvalid, axi_stream_to_cm_from_channel_tlast, axi_stream_to_cm_from_channel_tready;
    wire[0:31] axi_stream_to_cm_from_channel_tdata;


    ////////////////////////////////////////////////////////////////////////////////////////////////////
    // IPbus and command manager interface connections
    // connections from cm to ipbus
    wire axi_stream_to_ipbus_from_cm_tvalid, axi_stream_to_ipbus_from_cm_tlast, axi_stream_to_ipbus_from_cm_tready;
    wire[0:31] axi_stream_to_ipbus_from_cm_tdata;

    // connections from ipbus to cm
    wire axi_stream_to_cm_from_ipbus_tvalid, axi_stream_to_cm_from_ipbus_tlast, axi_stream_to_cm_from_ipbus_tready;
    wire[0:31] axi_stream_to_cm_from_ipbus_tdata;
    wire[0:3] axi_stream_to_cm_from_ipbus_tdest;


    // ======== Communication with the AMC13 DAQ Link ========
    wire daq_valid, daq_header, daq_trailer;
    wire[63:0] daq_data;
    wire daq_ready;
    wire daq_almost_full;


    // ======== module instantiations ========

    // TTC decoder module
    TTC_decoder ttc(
        .TTC_CLK_p(ttc_clkp),           // in  STD_LOGIC
        .TTC_CLK_n(ttc_clkn),           // in  STD_LOGIC
        .TTC_rst(),                     // in  STD_LOGIC  asynchronous reset after TTC_CLK_p/TTC_CLK_n frequency changed
        .TTC_data_p(ttc_rxp),           // in  STD_LOGIC
        .TTC_data_n(ttc_rxn),           // in  STD_LOGIC
        .TTC_CLK_out(),                 // out  STD_LOGIC
        .TTCready(TTCready),            // out  STD_LOGIC
        .L1Accept(ttc_L1A),             // out  STD_LOGIC
        .BCntRes(),                     // out  STD_LOGIC
        .EvCntRes(),                    // out  STD_LOGIC
        .SinErrStr(),                   // out  STD_LOGIC
        .DbErrStr(),                    // out  STD_LOGIC
        .BrcstStr(),                    // out  STD_LOGIC
        .Brcst()                        // out  STD_LOGIC_VECTOR (7 downto 2))
    );


    // IPBus module
    ipbus_top ipb(
        .gt_clkp(gtx_clk0), .gt_clkn(gtx_clk0_N),
        .gt_txp(gige_tx),   .gt_txn(gige_tx_N),
        .gt_rxp(gige_rx),   .gt_rxn(gige_rx_N),
        .sfp_los(sfp_los),
        .eth_link_status(eth_link_status),
        .rst_out(rst_from_ipb),
        
        // clocks
        .clk_200(clk200),
        .clk_125(),
        .ipb_clk(clk125),
        .gtrefclk_out(gtrefclk0),

        // "user_ipb" interface
        // Pass out the raw IPbus signals. They're handled in the Aurora block
        .user_ipb_clk(user_ipb_clk),           // programming clock
        .user_ipb_strobe(user_ipb_strobe),     // this ipb space is selected for an I/O operation
        .user_ipb_addr(user_ipb_addr[31:0]),   // slave address, memory or register
        .user_ipb_write(user_ipb_write),       // this is a write operation
        .user_ipb_wdata(user_ipb_wdata[31:0]), // data to write for write operations
        .user_ipb_rdata(user_ipb_rdata[31:0]), // data returned for read operations
        .user_ipb_ack(user_ipb_ack),           // 'write' data has been stored, 'read' data is ready
        .user_ipb_err(1'b0),                   // '1' if error, '0' if OK? We never generate an error!

        // Data interface to channel serial link
        // connections from ipbus to cm
        .axi_stream_out_tvalid(axi_stream_to_cm_from_ipbus_tvalid),
        .axi_stream_out_tdata(axi_stream_to_cm_from_ipbus_tdata[0:31]),
        .axi_stream_out_tlast(axi_stream_to_cm_from_ipbus_tlast),
        .axi_stream_out_tdest(axi_stream_to_cm_from_ipbus_tdest),
        .axi_stream_out_tready(axi_stream_to_cm_from_ipbus_tready),
        .axi_stream_out_tstrb(),
        .axi_stream_out_tkeep(),
        .axi_stream_out_tid(),

        // connections from cm to ipbus
        .axi_stream_in_tvalid(axi_stream_to_ipbus_from_cm_tvalid),
        .axi_stream_in_tdata(axi_stream_to_ipbus_from_cm_tdata),
        .axi_stream_in_tready(axi_stream_to_ipbus_from_cm_tready),
        .axi_stream_in_tstrb(),
        .axi_stream_in_tkeep(),
        .axi_stream_in_tlast(),
        .axi_stream_in_tid(),
        .axi_stream_in_tdest(),

        // trigger via IPbus for now
        .trigger_out(trigger_from_ipbus),

        // channel done to tm
        .chan_done_out(),

        // channel enable to cm
        .chan_en_out(chan_en),

        // signal to start programming sequence for channel FPGAs
        .prog_chan_out(prog_chan_start_from_ipbus),

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

        .debug(),
        .board_id(board_id),

        // flash interface ports
        .flash_wr_nBytes(ipbus_to_flash_wr_nBytes),
        .flash_rd_nBytes(ipbus_to_flash_rd_nBytes),
        .flash_cmd_strobe(ipbus_to_flash_cmd_strobe),
        .flash_rbuf_en(ipbus_to_flash_rbuf_en),
        .flash_rbuf_addr(ipbus_to_flash_rbuf_addr),
        .flash_rbuf_data(flash_rbuf_to_ipbus_data),
        .flash_wbuf_en(ipbus_to_flash_wbuf_en),
        .flash_wbuf_addr(ipbus_to_flash_wbuf_addr),
        .flash_wbuf_data(ipbus_to_flash_wbuf_data),
        
        // unused DAQ Link ports (produce warnings if not listed)
        .daq_valid(),
        .daq_header(),
        .daq_trailer(),
        .daq_data(),
        .daq_ready(),
        .daq_almost_full()
    );

 
    // Serial links to channel FPGAs
    all_channels channels(
        .clk50(clk50),
        .clk50_reset(clk50_reset), // FIXME
        .axis_clk(clk125),
        .axis_clk_resetN(rst_n),
        .gt_refclk(gtrefclk0),

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
        .c0_s_axi_tx_tkeep({ 4 {c0_axi_stream_to_channel_tkeep} }),   // note index order
        .c0_s_axi_tx_tvalid(c0_axi_stream_to_channel_tvalid),
        .c0_s_axi_tx_tlast(c0_axi_stream_to_channel_tlast),
        .c0_s_axi_tx_tready(c0_axi_stream_to_channel_tready),
        // RX Interface to master side of receive FIFO
        .c0_m_axi_rx_tdata(c0_axi_stream_to_cm_tdata),        // note index order
        .c0_m_axi_rx_tkeep(),                                 // note index order
        .c0_m_axi_rx_tvalid(c0_axi_stream_to_cm_tvalid),
        .c0_m_axi_rx_tlast(c0_axi_stream_to_cm_tlast),
        .c0_m_axi_rx_tready(c0_axi_stream_to_cm_tready),      // input wire m_axis_tready
        // serial I/O pins
        .c0_rxp(c0_rx), .c0_rxn(c0_rx_N),                     // receive from channel 0 FPGA
        .c0_txp(c0_tx), .c0_txn(c0_tx_N),                     // transmit to channel 0 FPGA

        // channel 1 connections
        // connections to 2-byte wide AXI4-stream clock domain crossing and data buffering FIFOs
        // TX interface to slave side of transmit FIFO
        .c1_s_axi_tx_tdata(c1_axi_stream_to_channel_tdata),   // note index order
        .c1_s_axi_tx_tkeep({ 4 {c1_axi_stream_to_channel_tkeep} }),   // note index order
        .c1_s_axi_tx_tvalid(c1_axi_stream_to_channel_tvalid),
        .c1_s_axi_tx_tlast(c1_axi_stream_to_channel_tlast),
        .c1_s_axi_tx_tready(c1_axi_stream_to_channel_tready),
        // RX Interface to master side of receive FIFO
        .c1_m_axi_rx_tdata(c1_axi_stream_to_cm_tdata),        // note index order
        .c1_m_axi_rx_tkeep(),                                 // note index order
        .c1_m_axi_rx_tvalid(c1_axi_stream_to_cm_tvalid),
        .c1_m_axi_rx_tlast(c1_axi_stream_to_cm_tlast),
        .c1_m_axi_rx_tready(c1_axi_stream_to_cm_tready),      // input wire m_axis_tready
        // serial I/O pins
        .c1_rxp(c1_rx), .c1_rxn(c1_rx_N),                     // receive from channel 0 FPGA
        .c1_txp(c1_tx), .c1_txn(c1_tx_N),                     // transmit to channel 0 FPGA

		// channel 2 connections
		// connections to 2-byte wide AXI4-stream clock domain crossing and data buffering FIFOs
        // TX interface to slave side of transmit FIFO
        .c2_s_axi_tx_tdata(c2_axi_stream_to_channel_tdata),   // note index order
        .c2_s_axi_tx_tkeep({ 4 {c2_axi_stream_to_channel_tkeep} }),   // note index order
        .c2_s_axi_tx_tvalid(c2_axi_stream_to_channel_tvalid),
        .c2_s_axi_tx_tlast(c2_axi_stream_to_channel_tlast),
        .c2_s_axi_tx_tready(c2_axi_stream_to_channel_tready),
        // RX Interface to master side of receive FIFO
        .c2_m_axi_rx_tdata(c2_axi_stream_to_cm_tdata),        // note index order
        .c2_m_axi_rx_tkeep(),                                 // note index order
        .c2_m_axi_rx_tvalid(c2_axi_stream_to_cm_tvalid),
        .c2_m_axi_rx_tlast(c2_axi_stream_to_cm_tlast),
        .c2_m_axi_rx_tready(c2_axi_stream_to_cm_tready),      // input wire m_axis_tready
        // serial I/O pins
        .c2_rxp(c2_rx), .c2_rxn(c2_rx_N),                     // receive from channel 0 FPGA
        .c2_txp(c2_tx), .c2_txn(c2_tx_N),                     // transmit to channel 0 FPGA

		// channel 3 connections
        // connections to 2-byte wide AXI4-stream clock domain crossing and data buffering FIFOs
        // TX interface to slave side of transmit FIFO
        .c3_s_axi_tx_tdata(c3_axi_stream_to_channel_tdata),   // note index order
        .c3_s_axi_tx_tkeep({ 4 {c3_axi_stream_to_channel_tkeep} }),   // note index order
        .c3_s_axi_tx_tvalid(c3_axi_stream_to_channel_tvalid),
        .c3_s_axi_tx_tlast(c3_axi_stream_to_channel_tlast),
        .c3_s_axi_tx_tready(c3_axi_stream_to_channel_tready),
        // RX Interface to master side of receive FIFO
        .c3_m_axi_rx_tdata(c3_axi_stream_to_cm_tdata),        // note index order
        .c3_m_axi_rx_tkeep(),                                 // note index order
        .c3_m_axi_rx_tvalid(c3_axi_stream_to_cm_tvalid),
        .c3_m_axi_rx_tlast(c3_axi_stream_to_cm_tlast),
        .c3_m_axi_rx_tready(c3_axi_stream_to_cm_tready),      // input wire m_axis_tready
        // serial I/O pins
        .c3_rxp(c3_rx), .c3_rxn(c3_rx_N),                     // receive from channel 0 FPGA
        .c3_txp(c3_tx), .c3_txn(c3_tx_N),                     // transmit to channel 0 FPGA
 
		// channel 4 connections
        // connections to 2-byte wide AXI4-stream clock domain crossing and data buffering FIFOs
        // TX interface to slave side of transmit FIFO
        .c4_s_axi_tx_tdata(c4_axi_stream_to_channel_tdata),   // note index order
        .c4_s_axi_tx_tkeep({ 4 {c4_axi_stream_to_channel_tkeep} }),   // note index order
        .c4_s_axi_tx_tvalid(c4_axi_stream_to_channel_tvalid),
        .c4_s_axi_tx_tlast(c4_axi_stream_to_channel_tlast),
        .c4_s_axi_tx_tready(c4_axi_stream_to_channel_tready),
        // RX Interface to master side of receive FIFO
        .c4_m_axi_rx_tdata(c4_axi_stream_to_cm_tdata),        // note index order
        .c4_m_axi_rx_tkeep(),                                 // note index order
        .c4_m_axi_rx_tvalid(c4_axi_stream_to_cm_tvalid),
        .c4_m_axi_rx_tlast(c4_axi_stream_to_cm_tlast),
        .c4_m_axi_rx_tready(c4_axi_stream_to_cm_tready),      // input wire m_axis_tready
        // serial I/O pins
        .c4_rxp(c4_rx), .c4_rxn(c4_rx_N),                     // receive from channel 0 FPGA
        .c4_txp(c4_tx), .c4_txn(c4_tx_N),                     // transmit to channel 0 FPGA

        //clock synthesizer connections
        .adcclk_dclk(adcclk_dclk),
        .adcclk_ddat(adcclk_ddat),
        .adcclk_dlen(adcclk_dlen),
        .adcclk_goe(adcclk_goe),
        .adcclk_sync(adcclk_sync),
        .debug(),

        // counter ouputs
        .frame_err(frame_err),              
        .hard_err(hard_err),                
        .soft_err(soft_err),                
        .channel_up(channel_up),            
        .lane_up(lane_up),                  
        .pll_not_locked(pll_not_locked),    
        .tx_resetdone_out(tx_resetdone_out),
        .rx_resetdone_out(rx_resetdone_out),
        .link_reset_out(link_reset_out)
    );


    // trigger manager module
    wire chan_readout_done; // needed for the trig_arm signal
    triggerManager tm(
        // interface to trig number FIFO
        .fifo_valid(tm_to_fifo_tvalid),
        .fifo_ready(tm_to_fifo_tready),
        .trig_num(tm_to_fifo_tdata),

        // .trigger(trigger_from_ipbus), // ipbus triggering
        // .trigger(ext_trig_sync), // external triggering
        .trigger(trigger_from_ttc), // ttc triggering

        .go(acq_trigs),
        .done(acq_dones_sync),
        .chan_readout_done(chan_readout_done), // input wire, to monitor when a fill is being read out
        .trig_arm(trig_arm),                   // output wire [4 : 0], to start the circular memory buffer
        .chan_en(chan_en),                     // enabled channels from ipbus

        // other connections
        .clk(clk125),
        .reset(rst_from_ipb),
        .cm_busy(cm_busy)
    );


    // trigger number fifo
    trig_num_axis_data_fifo trig_num_fifo (
      .s_axis_aresetn(rst_n),            // input wire s_axis_aresetn
      .s_axis_aclk(clk125),              // input wire s_axis_aclk
      .s_axis_tvalid(tm_to_fifo_tvalid), // input wire s_axis_tvalid
      .s_axis_tready(tm_to_fifo_tready), // output wire s_axis_tready
      .s_axis_tdata(tm_to_fifo_tdata),   // input wire [23 : 0] s_axis_tdata
      .m_axis_tvalid(fifo_to_cm_tvalid), // output wire m_axis_tvalid
      .m_axis_tready(fifo_to_cm_tready), // input wire m_axis_tready
      .m_axis_tdata(fifo_to_cm_tdata),   // output wire [23 : 0] m_axis_tdata
      
      // unused output ports
      .axis_data_count(),
      .axis_wr_data_count(),
      .axis_rd_data_count()
    );


    // command manager module
    commandManager cm(
        // interface to tx channel FIFO (through AXI4-Stream TX Switch)
        .chan_tx_fifo_data(axi_stream_to_channel_from_cm_tdata),
        .chan_tx_fifo_valid(axi_stream_to_channel_from_cm_tvalid),
        .chan_tx_fifo_ready(axi_stream_to_channel_from_cm_tready),
        .chan_tx_fifo_dest(axi_stream_to_channel_from_cm_tdest),
        .chan_tx_fifo_last(axi_stream_to_channel_from_cm_tlast),

        // interface to rx channel FIFO (through AXI4-Stream RX Switch)
        .chan_rx_fifo_data(axi_stream_to_cm_from_channel_tdata),
        .chan_rx_fifo_valid(axi_stream_to_cm_from_channel_tvalid),
        .chan_rx_fifo_ready(axi_stream_to_cm_from_channel_tready),
        .chan_rx_fifo_last(axi_stream_to_cm_from_channel_tlast),

        // interface to IPbus AXI output
        .ipbus_cmd_data(axi_stream_to_cm_from_ipbus_tdata),
        .ipbus_cmd_valid(axi_stream_to_cm_from_ipbus_tvalid),
        .ipbus_cmd_ready(axi_stream_to_cm_from_ipbus_tready),
        .ipbus_cmd_dest(axi_stream_to_cm_from_ipbus_tdest),
        .ipbus_cmd_last(axi_stream_to_cm_from_ipbus_tlast),

        // interface to IPbus AXI input
        .ipbus_res_data(axi_stream_to_ipbus_from_cm_tdata),
        .ipbus_res_valid(axi_stream_to_ipbus_from_cm_tvalid),
        .ipbus_res_ready(axi_stream_to_ipbus_from_cm_tready),
        .ipbus_res_last(axi_stream_to_ipbus_from_cm_tlast),

        // interface to AMC13 DAQ Link
        .daq_valid(daq_valid),
        .daq_header(daq_header),
        .daq_trailer(daq_trailer),
        .daq_data(daq_data),
        .daq_ready(daq_ready),

        // interface to trigger number FIFO
        .tm_fifo_ready(fifo_to_cm_tready),
        .tm_fifo_valid(fifo_to_cm_tvalid),
        .tm_fifo_data(fifo_to_cm_tdata),

        // other connections
        .read_fill_done(chan_readout_done),
        .chan_en(chan_en),                  // enabled channels from ipbus
        .clk(clk125),
        .rst(rst_from_ipb),
        .busy(cm_busy)
    );


    // DAQ Link to AMC13
    DAQ_Link_7S #(
        .F_REFCLK(125),
        .SYSCLK_IN_period(8),
        .USE_TRIGGER_PORT(1'b0)
    ) daq(
        .reset(rst_from_ipb),

        .GTX_REFCLK(gtrefclk0),
        .GTX_RXP(daq_rx),
        .GTX_RXN(daq_rx_N),
        .GTX_TXP(daq_tx),
        .GTX_TXN(daq_tx_N),
        .SYSCLK_IN(clk125),

        .TTCclk(clk125),
        .BcntRes(rst_from_ipb),
        .trig({ 8 {trigger_from_ttc} }),
        .TTSclk(1'b0),
        .TTS(4'd0),

        .EventDataClk(clk125),
        .EventData_valid(daq_valid),
        .EventData_header(daq_header),
        .EventData_trailer(daq_trailer),
        .EventData(daq_data),
        .AlmostFull(daq_almost_full),
        .Ready(daq_ready)
    );


    // AXIS TX Switch
    axis_switch_tx tx_switch (
        .aclk(clk125),   // input wire aclk
        .aresetn(rst_n), // input wire aresetn

        // CM side
        .s_axis_tvalid(axi_stream_to_channel_from_cm_tvalid), // input  wire [0 : 0]  s_axis_tvalid
        .s_axis_tready(axi_stream_to_channel_from_cm_tready), // output wire [0 : 0]  s_axis_tready
        .s_axis_tdata(axi_stream_to_channel_from_cm_tdata),   // input  wire [31 : 0] s_axis_tdata
        .s_axis_tdest(axi_stream_to_channel_from_cm_tdest),   // input  wire [3 : 0]  s_axis_tdest
        .s_axis_tlast(axi_stream_to_channel_from_cm_tlast),   // input  wire [0 : 0]  s_axis_tlast

        // channel FPGA side
        .m_axis_tvalid(c_axi_stream_to_channel_tvalid), // output wire [4 : 0]   m_axis_tvalid
        .m_axis_tready(c_axi_stream_to_channel_tready), // input  wire [4 : 0]   m_axis_tready
        .m_axis_tdata(c_axi_stream_to_channel_tdata),   // output wire [159 : 0] m_axis_tdata
        .m_axis_tdest(c_axi_stream_to_channel_tdest),   // output wire [19 : 0]  m_axis_tdest
        .m_axis_tlast(c_axi_stream_to_channel_tlast),   // output wire [4 : 0]   m_axis_tlast
        
        // unused output port
        .s_decode_err()
    );


    // AXIS RX Switch
    wire [4:0] s_req_suppress = 5'b0; // active high skips next arbitration cycle
    axis_switch_rx rx_switch (
        .aclk(clk125),                   // input wire aclk
        .aresetn(rst_n),                 // input wire aresetn
        .s_req_suppress(s_req_suppress), // input wire [4 : 0] s_req_suppress

        // channel FPGA side
        .s_axis_tvalid(c_axi_stream_to_cm_tvalid), // input wire  [4 : 0]   s_axis_tvalid
        .s_axis_tready(c_axi_stream_to_cm_tready), // output wire [4 : 0]   s_axis_tready
        .s_axis_tlast(c_axi_stream_to_cm_tlast),   // input wire  [4 : 0]   s_axis_tlast
        .s_axis_tdata(c_axi_stream_to_cm_tdata),   // input wire  [159 : 0] s_axis_tdata

        // CM side
        .m_axis_tvalid(axi_stream_to_cm_from_channel_tvalid), // output wire [0 : 0]  m_axis_tvalid
        .m_axis_tready(axi_stream_to_cm_from_channel_tready), // input  wire [0 : 0]  m_axis_tready
        .m_axis_tlast(axi_stream_to_cm_from_channel_tlast),   // output wire [0 : 0]  m_axis_tlast
        .m_axis_tdata(axi_stream_to_cm_from_channel_tdata),   // output wire [31 : 0] m_axis_tdata
        
        // unused output port
        .s_decode_err()
    );


endmodule
