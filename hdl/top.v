// top-level module for g-2 WFD5 Master FPGA


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
    input [4:0] initb,                // to each channel FPGA Configuration
    input [4:0] prog_done,            // from each channel FPGA Configuration
    input test                        // 
);

    // ======== clock signals ========
    wire clk50;
    wire clk125;
    wire clk200;
    wire clkfb;
    wire gtrefclk0;
    wire pll_lock;

    assign clk50 = clkin; // just to make the frequency explicit

	// dummy use of signals
    assign debug0 = acq_dones[0] & acq_dones[1] & acq_dones[2] & acq_dones[3] & acq_dones[4];
    assign debug1 = mmc_io[2] & mmc_io[3] & ext_trig_sync;
    assign debug2 = initb[4] & initb[3] & initb[2] & initb[1] & initb[0];
    assign debug6 = prog_done[4] & prog_done[3] & prog_done[2] & prog_done[1] & prog_done[0] & wfdps[0] & wfdps[1] & mmc_reset_m;;
    assign debug7 = mezzb[0] & mezzb[1] & mezzb[2] & mezzb[3] & mezzb[4] & mezzb[5];

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
    (* mark_debug = "true" *) wire [4:0] trig_arm;
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
	assign daq_clk_sel = 1'b1;
	assign daq_clk_en = 1'b1;

    wire ttc_clk, ttc_rx;
	IBUFDS ttc_clk_buf(.I(ttc_clkp), .IB(ttc_clkn), .O(ttc_clk));  
	IBUFDS ttc_rx_buf(.I(ttc_rxp), .IB(ttc_rxn), .O(ttc_rx)); 
	OBUFDS ttc_tx_buf(.I(ttc_rx), .O(ttc_txp), .OB(ttc_txn)); 

    assign c_progb = 1'b1;
    assign c_clk = 1'b0;
    assign c_din = test;
    // assign initb[4:0] = prog_done[4:0]; // initb changed from output to input


    // Generate clocks from the 50 MHz input clock
    // Most of the design is run from the 125 MHz clock (Don't confuse it with the 125 MHz GTREFCLK)
    // clk200 acts as the independent clock required by the Gigabit ethernet IP
    PLLE2_BASE #(
        .CLKFBOUT_MULT(20.0),
        .CLKIN1_PERIOD(20), // in ns, so 20 -> 50 MHz
        .CLKOUT0_DIVIDE(5),
        .CLKOUT1_DIVIDE(8),
    ) clk (
        .CLKIN1(clkin),
        .CLKOUT0(clk200),
        .CLKOUT1(clk125),
        .CLKOUT3(),
        .CLKOUT4(),
        .CLKOUT5(),
        .LOCKED(pll_lock),
        .RST(0),
        .PWRDWN(0),
        .CLKFBOUT(clkfb),
        .CLKFBIN(clkfb)
    );


    // sync_2stage module
    // Put the external trigger into the 125 MHz clock domain
    (* mark_debug = "true" *) wire ext_trig_sync;
    sync_2stage trig_sync(
        .clk(clk125),
        .in(ext_trig),
        .out(ext_trig_sync)
    );


    // ======== ethernet status signals ========
    reg sfp_los = 0;      // loss of signal for gigabit ethernet. Not used
    wire eth_link_status; // link status of gigabit ethernet

    // LED is green when GigE link is up, red otherwise
    assign led0 = eth_link_status;     // green
    // assign led1 = ~eth_link_status; // red (now flashes instead)


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


    // ======== triggers and data transfer ========
    (* mark_debug = "true" *) wire trigger_from_ipbus;

    // done signals from channels
    (* mark_debug = "true" *) wire[4:0] chan_done;

    // enable signals to channels
    (* mark_debug = "true" *) wire[4:0] chan_en;

    // wires connecting the trig number fifo to the tm
    (* mark_debug = "true" *) wire tm_to_fifo_tvalid, tm_to_fifo_tready;
    (* mark_debug = "true" *) wire[23:0] tm_to_fifo_tdata;

    (* mark_debug = "true" *) wire fifo_to_cm_tvalid, fifo_to_cm_tready;
    (* mark_debug = "true" *) wire[23:0] fifo_to_cm_tdata;

    // wire connecting the tm and the cm
    (* mark_debug = "true" *) wire cm_busy;


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
    (* mark_debug = "true" *) wire[19:0]  c_axi_stream_to_channel_tdest;
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
    (* mark_debug = "true" *) wire[0:3]  axi_stream_to_channel_from_cm_tdest;


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
    (* mark_debug = "true" *) wire daq_valid, daq_header, daq_trailer;
    (* mark_debug = "true" *) wire[63:0] daq_data;
    (* mark_debug = "true" *) wire daq_ready;
    wire daq_almost_full;


    // ======== module instantiations ========

    // LED flasher module
    led_flasher led_flasher(
        .clk(clk50),
        .led(led1)
    );


    // IPBus module
    ipbus_top ipb(
        .gt_clkp(gtx_clk0), .gt_clkn(gtx_clk0_N),
        .gt_txp(gige_tx),   .gt_txn(gige_tx_N),
        .gt_rxp(gige_rx),   .gt_rxn(gige_rx_N),
        .sfp_los(sfp_los),
        .eth_link_status(eth_link_status),
        .rst_out(rst_from_ipb),
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

        // connections from cm to ipbus
        .axi_stream_in_tvalid(axi_stream_to_ipbus_from_cm_tvalid),
        .axi_stream_in_tdata(axi_stream_to_ipbus_from_cm_tdata),
        .axi_stream_in_tready(axi_stream_to_ipbus_from_cm_tready),

        // trigger via IPbus for now
        .trigger_out(trigger_from_ipbus),

        // channel done to tm
        .chan_done_out(chan_done),

        // channel enable to cm
        .chan_en_out(chan_en),

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

        .board_id(board_id)
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
        .c0_s_axi_tx_tkeep(c0_axi_stream_to_channel_tkeep),   // note index order
        .c0_s_axi_tx_tvalid(c0_axi_stream_to_channel_tvalid),
        .c0_s_axi_tx_tlast(c0_axi_stream_to_channel_tlast),
        .c0_s_axi_tx_tready(c0_axi_stream_to_channel_tready),
        // RX Interface to master side of receive FIFO
        .c0_m_axi_rx_tdata(c0_axi_stream_to_cm_tdata),        // note index order
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
        .c1_s_axi_tx_tkeep(c1_axi_stream_to_channel_tkeep),   // note index order
        .c1_s_axi_tx_tvalid(c1_axi_stream_to_channel_tvalid),
        .c1_s_axi_tx_tlast(c1_axi_stream_to_channel_tlast),
        .c1_s_axi_tx_tready(c1_axi_stream_to_channel_tready),
        // RX Interface to master side of receive FIFO
        .c1_m_axi_rx_tdata(c1_axi_stream_to_cm_tdata),        // note index order
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
        .c2_s_axi_tx_tkeep(c2_axi_stream_to_channel_tkeep),   // note index order
        .c2_s_axi_tx_tvalid(c2_axi_stream_to_channel_tvalid),
        .c2_s_axi_tx_tlast(c2_axi_stream_to_channel_tlast),
        .c2_s_axi_tx_tready(c2_axi_stream_to_channel_tready),
        // RX Interface to master side of receive FIFO
        .c2_m_axi_rx_tdata(c2_axi_stream_to_cm_tdata),        // note index order
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
        .c3_s_axi_tx_tkeep(c3_axi_stream_to_channel_tkeep),   // note index order
        .c3_s_axi_tx_tvalid(c3_axi_stream_to_channel_tvalid),
        .c3_s_axi_tx_tlast(c3_axi_stream_to_channel_tlast),
        .c3_s_axi_tx_tready(c3_axi_stream_to_channel_tready),
        // RX Interface to master side of receive FIFO
        .c3_m_axi_rx_tdata(c3_axi_stream_to_cm_tdata),        // note index order
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
        .c4_s_axi_tx_tkeep(c4_axi_stream_to_channel_tkeep),   // note index order
        .c4_s_axi_tx_tvalid(c4_axi_stream_to_channel_tvalid),
        .c4_s_axi_tx_tlast(c4_axi_stream_to_channel_tlast),
        .c4_s_axi_tx_tready(c4_axi_stream_to_channel_tready),
        // RX Interface to master side of receive FIFO
        .c4_m_axi_rx_tdata(c4_axi_stream_to_cm_tdata),        // note index order
        .c4_m_axi_rx_tvalid(c4_axi_stream_to_cm_tvalid),
        .c4_m_axi_rx_tlast(c4_axi_stream_to_cm_tlast),
        .c4_m_axi_rx_tready(c4_axi_stream_to_cm_tready),      // input wire m_axis_tready
        // serial I/O pins
        .c4_rxp(c4_rx), .c4_rxn(c4_rx_N),                     // receive from channel 0 FPGA
        .c4_txp(c4_tx), .c4_txn(c4_tx_N),                     // transmit to channel 0 FPGA

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
    (* mark_debug = "true" *) wire chan_readout_done; // needed for the trig_arm signal
    triggerManager tm(
        // interface to trig number FIFO
        .fifo_valid(tm_to_fifo_tvalid),
        .fifo_ready(tm_to_fifo_tready),
        .trig_num(tm_to_fifo_tdata),

        // .trigger(trigger_from_ipbus), // ipbus triggering
        .trigger(ext_trig_sync),         // external triggering
        .go(acq_trigs),
        .done(acq_dones),
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
      .m_axis_tdata(fifo_to_cm_tdata)    // output wire [23 : 0] m_axis_tdata
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

        .GTX_REFCLK(clk125),
        .GTX_RXP(daq_rx),
        .GTX_RXN(daq_rx_N),
        .GTX_TXP(daq_tx),
        .GTX_TXN(daq_tx_N),
        .SYSCLK_IN(gtrefclk0),

        .TTCclk(clk125),
        .BcntRes(rst_from_ipb),
        .trig(ext_trig_sync),
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
        .m_axis_tlast(c_axi_stream_to_channel_tlast)    // output wire [4 : 0]   m_axis_tlast
    );


    // AXIS RX Switch
    wire s_req_suppress = 0; // active high skips next arbitration cycle
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
        .m_axis_tdata(axi_stream_to_cm_from_channel_tdata)    // output wire [31 : 0] m_axis_tdata
    );


    // clock synthesizer initialization
    clk_synth_intf clk_synth1(
        .clk(clk50),
        .reset(rst_from_ipb),
        .dclk(adcclk_dclk),
        .ddat(adcclk_ddat),
        .dlen(adcclk_dlen),
        .goe(adcclk_goe),
        .sync(adcclk_sync),
        .debug() 
    );


endmodule
