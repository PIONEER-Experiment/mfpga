// top-level module for g-2 WFD Master FPGA


module wfd_top(
	input wire gtx_clk0, gtx_clk0_N, // GTX Tranceiver refclk
	output wire gige_tx, gige_tx_N,  // Gigabit Ethernet TX
	input wire gige_rx, gige_rx_N,   // Gigabit Ethernet RX
    input wire daq_rx, daq_rx_N,     // AMC13 Link RX
    output wire daq_tx, daq_tx_N,    // AMC13 Link TX
    input wire c0_rx, c0_rx_N,       // Serial link to Channel 0 RX
    output wire c0_tx, c0_tx_N,      // Serial link to Channel 0 TX
    input wire c1_rx, c1_rx_N,       // Serial link to Channel 1 RX
    output wire c1_tx, c1_tx_N,      // Serial link to Channel 1 TX
    input wire clkin,                // 50 MHz clock
    output wire[15:0] debug,         // debug header
    output wire[4:0] acq_trigs,      // triggers to channel FPGAs
    output wire led0, led1           // front panel LEDs. led0 is green, led1 is red
);


    // ========  debug signals ========
    // assign debug[8] = clk125;
    // assign debug[9] = rst_from_ipb;
    // assign debug[10] = trigger_from_ipbus;
    // assign debug[11] = fifo_to_dtm_tvalid;
    // assign debug[12] = fifo_to_dtm_tready;


    // ======== clock signals ========
    wire clk50;
    wire clk125;
    wire clk200;
    wire clkfb;
    wire gtrefclk0;
    wire pll_lock;

    assign clk50 = clkin; // Just to make the frequency explicit

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


    // ======== ethernet status signals ========
    reg sfp_los = 0; // loss of signal for gigabit ethernet. Not used
    wire eth_link_status; // link status of gigabit ethernet

    // LED is green when GigE link is up, red otherwise
    assign led0 = eth_link_status; // green
    assign led1 = ~eth_link_status; // red


    // ======== reset signals ========
    wire rst_from_ipb; // reset from IPbus. Synchronous to IPbus clock
    wire rst_n; // active low reset
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

    // wires connecting the fill number fifo to the tm
    (* mark_debug = "true" *) wire tm_to_fifo_tvalid, tm_to_fifo_tready;
    wire[23:0] tm_to_fifo_tdata;

    // wires connecting the fill number fifo to the dtm
    (* mark_debug = "true" *) wire fifo_to_dtm_tvalid, fifo_to_dtm_tready;
    wire[23:0] fifo_to_dtm_tdata;


    // ======== wires for interface to channel serial link ========
    // User IPbus interface. Used by Charlie's Aurora block
    wire [31:0] user_ipb_addr, user_ipb_wdata, user_ipb_rdata;
    wire user_ipb_clk, user_ipb_strobe, user_ipb_write, user_ipb_ack;

    // AXI4-Stream interface for communicating with serial link to channel FPGA

    // channel 0
    wire c0_axi_stream_to_dtm_tvalid, c0_axi_stream_to_dtm_tlast, c0_axi_stream_to_dtm_tready;
    wire[0:31] c0_axi_stream_to_dtm_tdata;
    wire[0:3] c0_axi_stream_to_dtm_tstrb;
    wire[0:3] c0_axi_stream_to_dtm_tkeep;
    wire[0:3] c0_axi_stream_to_dtm_tid;
    wire[0:3] c0_axi_stream_to_dtm_tdest;

    wire c0_axi_stream_to_channel_tvalid, c0_axi_stream_to_channel_tlast, c0_axi_stream_to_channel_tready;
    wire[0:31] c0_axi_stream_to_channel_tdata;
    wire[0:3] c0_axi_stream_to_channel_tstrb;
    wire[0:3] c0_axi_stream_to_channel_tkeep;
    wire[0:3] c0_axi_stream_to_channel_tid;
    wire[0:3] c0_axi_stream_to_channel_tdest;

    // channel 1
    wire c1_axi_stream_to_dtm_tvalid, c1_axi_stream_to_dtm_tlast, c1_axi_stream_to_dtm_tready;
    wire[0:31] c1_axi_stream_to_dtm_tdata;
    wire[0:3] c1_axi_stream_to_dtm_tstrb;
    wire[0:3] c1_axi_stream_to_dtm_tkeep;
    wire[0:3] c1_axi_stream_to_dtm_tid;
    wire[0:3] c1_axi_stream_to_dtm_tdest;

    wire c1_axi_stream_to_channel_tvalid, c1_axi_stream_to_channel_tlast, c1_axi_stream_to_channel_tready;
    wire[0:31] c1_axi_stream_to_channel_tdata;
    wire[0:3] c1_axi_stream_to_channel_tstrb;
    wire[0:3] c1_axi_stream_to_channel_tkeep;
    wire[0:3] c1_axi_stream_to_channel_tid;
    wire[0:3] c1_axi_stream_to_channel_tdest;


    // packaging up channel connections for the axi rx switch input
    (* mark_debug = "true" *) wire[1:0] c_axi_stream_to_dtm_tvalid, c_axi_stream_to_dtm_tlast, c_axi_stream_to_dtm_tready;
    (* mark_debug = "true" *) wire[63:0] c_axi_stream_to_dtm_tdata;

    assign c_axi_stream_to_dtm_tvalid[0] = c0_axi_stream_to_dtm_tvalid;
    assign c_axi_stream_to_dtm_tvalid[1] = c1_axi_stream_to_dtm_tvalid;
    assign c_axi_stream_to_dtm_tlast[0] = c0_axi_stream_to_dtm_tlast;
    assign c_axi_stream_to_dtm_tlast[1] = c1_axi_stream_to_dtm_tlast;
    assign c0_axi_stream_to_dtm_tready = c_axi_stream_to_dtm_tready[0];
    assign c1_axi_stream_to_dtm_tready = c_axi_stream_to_dtm_tready[1];
    assign c_axi_stream_to_dtm_tdata[31:0] = c0_axi_stream_to_dtm_tdata;
    assign c_axi_stream_to_dtm_tdata[63:32] = c1_axi_stream_to_dtm_tdata;

    // connection from axi rx switch to data transfer manager
    (* mark_debug = "true" *) wire axi_stream_to_dtm_tvalid, axi_stream_to_dtm_tlast, axi_stream_to_dtm_tready;
    (* mark_debug = "true" *) wire[0:31] axi_stream_to_dtm_tdata;
    wire[0:3] axi_stream_to_dtm_tstrb;
    wire[0:3] axi_stream_to_dtm_tkeep;
    wire[0:3] axi_stream_to_dtm_tid;
    wire[0:3] axi_stream_to_dtm_tdest;

    // packaging up channel connections for the axi tx switch output
    (* mark_debug = "true" *) wire[1:0] c_axi_stream_to_channel_tvalid, c_axi_stream_to_channel_tlast, c_axi_stream_to_channel_tready;
    wire [7:0] c_axi_stream_to_channel_tdest;
    (* mark_debug = "true" *) wire[63:0] c_axi_stream_to_channel_tdata;

    assign c0_axi_stream_to_channel_tvalid = c_axi_stream_to_channel_tvalid[0];
    assign c1_axi_stream_to_channel_tvalid = c_axi_stream_to_channel_tvalid[1];
    assign c0_axi_stream_to_channel_tlast = c_axi_stream_to_channel_tlast[0];
    assign c1_axi_stream_to_channel_tlast = c_axi_stream_to_channel_tlast[1];
    assign c_axi_stream_to_channel_tready[0] = c0_axi_stream_to_channel_tready;
    assign c_axi_stream_to_channel_tready[1] = c1_axi_stream_to_channel_tready;
    assign c0_axi_stream_to_channel_tdata = c_axi_stream_to_channel_tdata[31:0];
    assign c1_axi_stream_to_channel_tdata = c_axi_stream_to_channel_tdata[63:32];
    assign c0_axi_stream_to_channel_tdest = c_axi_stream_to_channel_tdest[3:0];
    assign c1_axi_stream_to_channel_tdest = c_axi_stream_to_channel_tdest[7:4];


    // connection from ipbus to axi tx switch
    (* mark_debug = "true" *) wire axi_stream_to_channel_from_ipbus_tvalid, axi_stream_to_channel_from_ipbus_tlast, axi_stream_to_channel_from_ipbus_tready;
    (* mark_debug = "true" *) wire[0:31] axi_stream_to_channel_from_ipbus_tdata;
    wire[0:3] axi_stream_to_channel_from_ipbus_tstrb;
    wire[0:3] axi_stream_to_channel_from_ipbus_tkeep;
    wire[0:3] axi_stream_to_channel_from_ipbus_tid;
    (* mark_debug = "true" *) wire[0:3] axi_stream_to_channel_from_ipbus_tdest;

    // connection from dtm to axi tx switch
    (* mark_debug = "true" *) wire axi_stream_to_channel_from_dtm_tvalid, axi_stream_to_channel_from_dtm_tlast, axi_stream_to_channel_from_dtm_tready;
    (* mark_debug = "true" *) wire[0:31] axi_stream_to_channel_from_dtm_tdata;
    (* mark_debug = "true" *) wire[0:3] axi_stream_to_channel_from_dtm_tdest;

    // packaging up channel connections for the axi tx switch input
    (* mark_debug = "true" *) wire[1:0] axi_stream_to_channel_tvalid, axi_stream_to_channel_tlast, axi_stream_to_channel_tready;
    wire [7:0] axi_stream_to_channel_tdest;
    (* mark_debug = "true" *) wire[63:0] axi_stream_to_channel_tdata;

    assign axi_stream_to_channel_tvalid[0]    = axi_stream_to_channel_from_ipbus_tvalid;
    assign axi_stream_to_channel_tvalid[1]    = axi_stream_to_channel_from_dtm_tvalid;
    assign axi_stream_to_channel_tlast[0]     = axi_stream_to_channel_from_ipbus_tlast;
    assign axi_stream_to_channel_tlast[1]     = axi_stream_to_channel_from_dtm_tlast;
    assign axi_stream_to_channel_from_ipbus_tready = axi_stream_to_channel_tready[0];
    assign axi_stream_to_channel_from_dtm_tready   = axi_stream_to_channel_tready[1];
    assign axi_stream_to_channel_tdata[31:0]  = axi_stream_to_channel_from_ipbus_tdata;
    assign axi_stream_to_channel_tdata[63:32] = axi_stream_to_channel_from_dtm_tdata;
    assign axi_stream_to_channel_tdest[3:0]   = axi_stream_to_channel_from_ipbus_tdest;
    assign axi_stream_to_channel_tdest[7:4]   = axi_stream_to_channel_from_dtm_tdest;


    // ======== Communication with the AMC13 DAQ Link ========
    (* mark_debug = "true" *) wire daq_valid, daq_header, daq_trailer;
    (* mark_debug = "true" *) wire[63:0] daq_data;
    (* mark_debug = "true" *) wire daq_ready;
    wire daq_almost_full;


    // ======== module instantiations ========

    // IPBus module
    ipbus_top ipb(
        .gt_clkp(gtx_clk0), .gt_clkn(gtx_clk0_N),
        .gt_txp(gige_tx), .gt_txn(gige_tx_N),
        .gt_rxp(gige_rx), .gt_rxn(gige_rx_N),
        .sfp_los(sfp_los),
        .eth_link_status(eth_link_status),
        .rst_out(rst_from_ipb),
        .clk_200(clk200),
        .clk_125(),
        .ipb_clk(clk125),
        .gtrefclk_out(gtrefclk0),

        // "user_ipb" interface
        // Pass out the raw IPbus signals. They're handled in the Aurora block
        .user_ipb_clk(user_ipb_clk),            // programming clock
        .user_ipb_strobe(user_ipb_strobe),      // this ipb space is selected for an I/O operation
        .user_ipb_addr(user_ipb_addr[31:0]),    // slave address, memory or register
        .user_ipb_write(user_ipb_write),        // this is a write operation
        .user_ipb_wdata(user_ipb_wdata[31:0]),  // data to write for write operations
        .user_ipb_rdata(user_ipb_rdata[31:0]),  // data returned for read operations
        .user_ipb_ack(user_ipb_ack),            // 'write' data has been stored, 'read' data is ready
        .user_ipb_err(1'b0),                    // '1' if error, '0' if OK? We never generate an error!

        // read output from ipbus, not amc13 (temporary)
        //.axi_stream_in_tvalid(daq_valid),
        //.axi_stream_in_tdata(daq_data),
        //.axi_stream_in_tready(daq_ready),

        // Data interface to channel serial link
        // connections from ipbus to channel TX switch
        .axi_stream_out_tvalid(axi_stream_to_channel_from_ipbus_tvalid),
        .axi_stream_out_tdata(axi_stream_to_channel_from_ipbus_tdata[0:31]),
        .axi_stream_out_tstrb(axi_stream_to_channel_from_ipbus_tstrb[0:3]),
        .axi_stream_out_tkeep(axi_stream_to_channel_from_ipbus_tkeep[0:3]),
        .axi_stream_out_tlast(axi_stream_to_channel_from_ipbus_tlast),
        .axi_stream_out_tid(axi_stream_to_channel_from_ipbus_tid),
        .axi_stream_out_tdest(axi_stream_to_channel_from_ipbus_tdest),
        .axi_stream_out_tready(axi_stream_to_channel_from_ipbus_tready),

        // Trigger via IPbus for now
        .trigger_out(trigger_from_ipbus),

        // channel done to tm
        .chan_done_out(chan_done),

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


    // Serial links to channel FPGAs
    all_channels channels(
        .clk50(clk50),
        .clk50_reset(clk50_reset), // FIXME
        .axis_clk(clk125),
        .axis_clk_resetN(rst_n),
        .gt_refclk(gtrefclk0),

        // IPbus inputs
        .ipb_clk(user_ipb_clk),                          // programming clock
        .ipb_reset(rst_from_ipb),
        .ipb_strobe(user_ipb_strobe),                       // this ipb space is selected for an I/O operation
        .ipb_addr(user_ipb_addr[23:0]),                  // slave address(), memory or register
        .ipb_write(user_ipb_write),                        // this is a write operation
        .ipb_wdata(user_ipb_wdata[31:0]),                 // data to write for write operations
        // IPbus outputs
        .ipb_rdata(user_ipb_rdata[31:0]),                // data returned for read operations
        .ipb_ack(user_ipb_ack),                         // 'write' data has been stored(), 'read' data is ready

        // channel 0 connections
        // connections to 2-byte wide AXI4-stream clock domain crossing and data buffering FIFOs
        // TX interface to slave side of transmit FIFO
        .c0_s_axi_tx_tdata(c0_axi_stream_to_channel_tdata),        // note index order
        //.c0_s_axi_tx_tkeep(c0_axi_stream_to_channel_tkeep),         // note index order
        .c0_s_axi_tx_tvalid(c0_axi_stream_to_channel_tvalid),
        .c0_s_axi_tx_tlast(c0_axi_stream_to_channel_tlast),
        .c0_s_axi_tx_tready(c0_axi_stream_to_channel_tready),
        // RX Interface to master side of receive FIFO
        .c0_m_axi_rx_tdata(c0_axi_stream_to_dtm_tdata),       // note index order
        //.c0_m_axi_rx_tkeep(c0_axi_stream_to_dtm_tkeep),        // note index order
        .c0_m_axi_rx_tvalid(c0_axi_stream_to_dtm_tvalid),
        .c0_m_axi_rx_tlast(c0_axi_stream_to_dtm_tlast),
        .c0_m_axi_rx_tready(c0_axi_stream_to_dtm_tready),            // input wire m_axis_tready
        // serial I/O pins
        .c0_rxp(c0_rx), .c0_rxn(c0_rx_N),                   // receive from channel 0 FPGA
        .c0_txp(c0_tx), .c0_txn(c0_tx_N),                   // transmit to channel 0 FPGA
        .debug(),

        // channel 1 connections
        // connections to 2-byte wide AXI4-stream clock domain crossing and data buffering FIFOs
        // TX interface to slave side of transmit FIFO
        .c1_s_axi_tx_tdata(c1_axi_stream_to_channel_tdata),        // note index order
        //.c1_s_axi_tx_tkeep(c1_axi_stream_to_channel_tkeep),         // note index order
        .c1_s_axi_tx_tvalid(c1_axi_stream_to_channel_tvalid),
        .c1_s_axi_tx_tlast(c1_axi_stream_to_channel_tlast),
        .c1_s_axi_tx_tready(c1_axi_stream_to_channel_tready),
        // RX Interface to master side of receive FIFO
        .c1_m_axi_rx_tdata(c1_axi_stream_to_dtm_tdata),       // note index order
        //.c1_m_axi_rx_tkeep(c1_axi_stream_to_dtm_tkeep),        // note index order
        .c1_m_axi_rx_tvalid(c1_axi_stream_to_dtm_tvalid),
        .c1_m_axi_rx_tlast(c1_axi_stream_to_dtm_tlast),
        .c1_m_axi_rx_tready(c1_axi_stream_to_dtm_tready),            // input wire m_axis_tready
        // serial I/O pins
        .c1_rxp(c1_rx), .c1_rxn(c1_rx_N),                   // receive from channel 0 FPGA
        .c1_txp(c1_tx), .c1_txn(c1_tx_N),                   // transmit to channel 0 FPGA

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


    // triggerManager module
    triggerManager tm(
        // Interface to fill number FIFO
        .fifo_valid(tm_to_fifo_tvalid),
        .fifo_ready(tm_to_fifo_tready),
        .fillNum(tm_to_fifo_tdata),

        .trigger(trigger_from_ipbus),
        .go(acq_trigs),
        
        .done(chan_done),

        // Other connections required by tm module
        .clk(clk125),
        .reset(rst_from_ipb)
    );


    // fill number FIFO
    fill_num_axis_data_fifo fill_num_fifo (
      .s_axis_aresetn(rst_n),             // input wire s_axis_aresetn
      .s_axis_aclk(clk125),               // input wire s_axis_aclk
      .s_axis_tvalid(tm_to_fifo_tvalid),  // input wire s_axis_tvalid
      .s_axis_tready(tm_to_fifo_tready),  // output wire s_axis_tready
      .s_axis_tdata(tm_to_fifo_tdata),    // input wire [23 : 0] s_axis_tdata
      .m_axis_tvalid(fifo_to_dtm_tvalid), // output wire m_axis_tvalid
      .m_axis_tready(fifo_to_dtm_tready), // input wire m_axis_tready
      .m_axis_tdata(fifo_to_dtm_tdata)    // output wire [23 : 0] m_axis_tdata
    );

    assign axi_stream_to_channel_from_dtm_tdest[0] = 0;
    assign axi_stream_to_channel_from_dtm_tdest[1] = 0;
    assign axi_stream_to_channel_from_dtm_tdest[2] = 0;
    assign axi_stream_to_channel_from_dtm_tdest[3] = 0;

    // data transfer manager module
    dataTransferManager dtm(
        // Interface to AMC13 DAQ Link
        .daq_valid(daq_valid),                // output from dtm
        .daq_header(daq_header),              // output from dtm
        .daq_trailer(daq_trailer),            // output from dtm
        .daq_data(daq_data),                  // output from dtm
        .daq_ready(daq_ready),                // input to dtm
        // .daq_almost_full(daq_almost_full), // currently ignored by dtm

        // Interface to fill number FIFO
        .tm_fifo_ready(fifo_to_dtm_tready),
        .tm_fifo_valid(fifo_to_dtm_tvalid),
        .tm_fifo_data(fifo_to_dtm_tdata),

        // Interface to rx channel FIFO (through AXI4-Stream RX Switch)
        .chan_rx_fifo_ready(axi_stream_to_dtm_tready), // output from dtm
        .chan_rx_fifo_data(axi_stream_to_dtm_tdata),   // input to dtm
        .chan_rx_fifo_last(axi_stream_to_dtm_tlast),   // input to dtm
        .chan_rx_fifo_valid(axi_stream_to_dtm_tvalid), // input to dtm

        // Interface to tx channel FIFO (through AXI4-Stream TX Switch)
        .chan_tx_fifo_ready(axi_stream_to_channel_from_dtm_tready), // input to dtm
        .chan_tx_fifo_data(axi_stream_to_channel_from_dtm_tdata),   // output from dtm
        .chan_tx_fifo_last(axi_stream_to_channel_from_dtm_tlast),   // output from dtm
        .chan_tx_fifo_valid(axi_stream_to_channel_from_dtm_tvalid), // output from dtm
        //.chan_tx_fifo_dest(axi_stream_to_channel_from_dtm_tdest[0]),   // output from dtm

        // Other connections required by dtm module
        .clk(clk125),      // input to dtm
        .rst(rst_from_ipb) // input to dtm
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
        .trig(trigger_from_ipbus),
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


    wire s_req_suppress = 0; // active high skips next arbitration cycle

    // AXIS RX Switch
    axis_switch_rx rx_switch (
        .aclk(clk125),                            // input wire aclk
        .aresetn(rst_n),                          // input wire aresetn
        .s_req_suppress(s_req_suppress),          // input wire [1 : 0] s_req_suppress

        // channel FPGA side
        .s_axis_tvalid(c_axi_stream_to_dtm_tvalid), // input wire [1 : 0] s_axis_tvalid
        .s_axis_tready(c_axi_stream_to_dtm_tready), // output wire [1 : 0] s_axis_tready
        .s_axis_tlast(c_axi_stream_to_dtm_tlast),   // input wire [1 : 0] s_axis_tlast
        .s_axis_tdata(c_axi_stream_to_dtm_tdata),   // input wire [63 : 0] s_axis_tdata

        // DTM side
        .m_axis_tvalid(axi_stream_to_dtm_tvalid), // output wire [0 : 0] m_axis_tvalid
        .m_axis_tready(axi_stream_to_dtm_tready), // input wire [0 : 0] m_axis_tready
        .m_axis_tlast(axi_stream_to_dtm_tlast),   // output wire [0 : 0] m_axis_tlast
        .m_axis_tdata(axi_stream_to_dtm_tdata)    // output wire [31 : 0] m_axis_tdata
    );



    // AXIS TX Switch
    axis_switch_tx tx_switch (
        .aclk(clk125),           // input wire aclk
        .aresetn(rst_n),         // input wire aresetn

        // IPBus + DTM side
        .s_axis_tvalid(axi_stream_to_channel_tvalid),  // input wire [1 : 0] s_axis_tvalid
        .s_axis_tready(axi_stream_to_channel_tready),  // output wire [1 : 0] s_axis_tready
        .s_axis_tdata(axi_stream_to_channel_tdata),    // input wire [63 : 0] s_axis_tdata
        .s_axis_tdest(axi_stream_to_channel_tdest),    // input wire [1 : 0] s_axis_tdest
        .s_axis_tlast(axi_stream_to_channel_tlast),    // input wire [1 : 0] s_axis_tlast

        // channel FPGA side
        .m_axis_tvalid(c_axi_stream_to_channel_tvalid),  // output wire [1 : 0] m_axis_tvalid
        .m_axis_tready(c_axi_stream_to_channel_tready),  // input wire [1 : 0] m_axis_tready
        .m_axis_tdata(c_axi_stream_to_channel_tdata),    // output wire [63 : 0] m_axis_tdata
        .m_axis_tdest(c_axi_stream_to_channel_tdest),    // output wire [1 : 0] m_axis_tdest
        .m_axis_tlast(c_axi_stream_to_channel_tlast)     // output wire [1 : 0] m_axis_tlast
    );


endmodule