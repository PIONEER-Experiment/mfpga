// top-level module for g-2 WFD Master FPGA


module wfd_top(
	input wire gtx_clk0, gtx_clk0_N, // GTX Tranceiver refclk
	output wire gige_tx, gige_tx_N, // Gigabit Ethernet TX
	input wire gige_rx, gige_rx_N, // Gigabit Ethernet RX
    input wire daq_rx, daq_rx_N, // AMC13 Link RX
    output wire daq_tx, daq_tx_N, // AMC13 Link TX
    input wire c0_rx, c0_rx_N, // Serial link to Channel 0 RX
    output wire c0_tx, c0_tx_N, // Serial link to Channel 0 TX
    // input wire c1_rx, c1_rx_N,
    // output wire c1_tx, c1_tx_N,
    input wire clkin, // 50 MHz clock
    output wire[15:0] debug, // debug header
    (* mark_debug = "true" *) output wire[4:0] acq_trigs, // triggers to channel FPGAs
    output wire led0, led1 // front panel LEDs. led0 is green, led1 is red
);
    reg sfp_los = 0; // loss of signal for gigabit ethernet. Not used
    wire eth_link_status; // link status of gigabit ethernet
    wire rst_from_ipb; // reset from IPbus. Synchronous to IPbus clock
    wire clk200;
    wire clkfb;
    wire clk125;
    wire clk50;
    wire gtrefclk0;

    wire pll_lock;

    // AXI4-Stream interface for communicating with serial link to channel FPGA
    wire axi_stream_to_ipbus_tvalid, axi_stream_to_ipbus_tlast, axi_stream_to_ipbus_tready;
    wire[0:31] axi_stream_to_ipbus_tdata;
    wire[0:3] axi_stream_to_ipbus_tstrb;
    wire[0:3] axi_stream_to_ipbus_tkeep;
    wire[0:3] axi_stream_to_ipbus_tid;
    wire[0:3] axi_stream_to_ipbus_tdest;

    wire axi_stream_from_ipbus_tvalid, axi_stream_from_ipbus_tlast, axi_stream_from_ipbus_tready;
    wire[0:31] axi_stream_from_ipbus_tdata;
    wire[0:3] axi_stream_from_ipbus_tstrb;
    wire[0:3] axi_stream_from_ipbus_tkeep;
    wire[0:3] axi_stream_from_ipbus_tid;
    wire[0:3] axi_stream_from_ipbus_tdest;

    // LED is green when GigE link is up, red otherwise
    assign led0 = eth_link_status; // green
    assign led1 = ~eth_link_status; // red

    // Just to make the frequency explicit
    assign clk50 = clkin;


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

    // Communication with the AMC13 DAQ Link
    wire daq_valid, daq_header, daq_trailer;
    wire[63:0] daq_data;
    wire daq_ready, daq_almost_full;

    // Triggers
    (* mark_debug = "true" *) wire trigger_from_ipbus;
    wire[4:0] chan_triggers;
    // assign acq_trigs = chan_triggers;

    // Channel done
    (* mark_debug = "true" *) wire[4:0] chan_done;

    // User IPbus interface. Used by Charlie's Aurora block
    wire [31:0] user_ipb_addr, user_ipb_wdata, user_ipb_rdata;
    wire user_ipb_clk, user_ipb_strobe, user_ipb_write, user_ipb_ack;

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

        // Data interface to channel serial link
        /********************** Moved from IPBus to DataXferManager **********************/
        /*
        .axi_stream_in_tvalid(axi_stream_to_ipbus_tvalid),
        .axi_stream_in_tdata(axi_stream_to_ipbus_tdata),
        .axi_stream_in_tstrb(axi_stream_to_ipbus_tstrb), // not connected to anything else
        .axi_stream_in_tkeep(axi_stream_to_ipbus_tkeep),
        .axi_stream_in_tlast(axi_stream_to_ipbus_tlast),
        .axi_stream_in_tid(axi_stream_to_ipbus_tid), // not connected to anything else
        .axi_stream_in_tdest(axi_stream_to_ipbus_tdest), // not connected to anything else
        .axi_stream_in_tready(axi_stream_to_ipbus_tready),
        */

        .axi_stream_out_tvalid(axi_stream_from_ipbus_tvalid),
        .axi_stream_out_tdata(axi_stream_from_ipbus_tdata[0:31]),
        .axi_stream_out_tstrb(axi_stream_from_ipbus_tstrb[0:3]),
        .axi_stream_out_tkeep(axi_stream_from_ipbus_tkeep[0:3]),
        .axi_stream_out_tlast(axi_stream_from_ipbus_tlast),
        .axi_stream_out_tid(axi_stream_from_ipbus_tid),
        .axi_stream_out_tdest(axi_stream_from_ipbus_tdest),
        .axi_stream_out_tready(axi_stream_from_ipbus_tready),

        // Interface to AMC13 DAQ Link
        /********************** Moved from IPBus to DataXferManager **********************/
        /*
        .daq_valid(daq_valid),
        .daq_header(daq_header),
        .daq_trailer(daq_trailer),
        .daq_data(daq_data),
        .daq_ready(daq_ready),
        .daq_almost_full(daq_almost_full), // currently ignored with dtm
        */

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

    // assign debug[8] = daq_header;
    // assign debug[9] = daq_valid;
    // assign debug[10] = daq_trailer;
    // assign debug[11] = daq_ready;

    wire rst_n;
    assign rst_n = ~rst_from_ipb;

    // Synchronize reset from IPbus clock domain to other domains
    wire clk50_reset;
    resets r (
        .ipb_rst_in(rst_from_ipb),
        .ipb_clk(clk125),
        .clk50(clk50),
        .rst_clk50(clk50_reset)
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
        .c0_s_axi_tx_tdata(axi_stream_from_ipbus_tdata[0:31]),        // note index order
        .c0_s_axi_tx_tkeep(axi_stream_from_ipbus_tkeep[0:3]),         // note index order
        .c0_s_axi_tx_tvalid(axi_stream_from_ipbus_tvalid),
        .c0_s_axi_tx_tlast(axi_stream_from_ipbus_tlast),
        .c0_s_axi_tx_tready(axi_stream_from_ipbus_tready),
        // RX Interface to master side of receive FIFO
        .c0_m_axi_rx_tdata(axi_stream_to_ipbus_tdata[0:31] ),       // note index order
        .c0_m_axi_rx_tkeep(axi_stream_to_ipbus_tkeep[0:3]),        // note index order
        .c0_m_axi_rx_tvalid(axi_stream_to_ipbus_tvalid),
        .c0_m_axi_rx_tlast(axi_stream_to_ipbus_tlast),
        .c0_m_axi_rx_tready(axi_stream_to_ipbus_tready),            // input wire m_axis_tready
        // serial I/O pins
        .c0_rxp(c0_rx), .c0_rxn(c0_rx_N),                   // receive from channel 0 FPGA
        .c0_txp(c0_tx), .c0_txn(c0_tx_N),                   // transmit to channel 0 FPGA
        .debug(),

        // // channel 1 connections
        // // connections to 2-byte wide AXI4-stream clock domain crossing and data buffering FIFOs
        // // TX interface to slave side of transmit FIFO
        // .c1_s_axi_tx_tdata(c0_rx_to_c1_tx_axi_tdata[0:15]),        // note index order
        // .c1_s_axi_tx_tkeep(c0_rx_to_c1_tx_axi_keep[0:1]),         // note index order
        // .c1_s_axi_tx_tvalid(c0_rx_to_c1_tx_axi_tvalid),
        // .c1_s_axi_tx_tlast(c0_rx_to_c1_tx_axi_tlast),
        // .c1_s_axi_tx_tready(c0_rx_to_c1_tx_axi_tready),
        // // RX Interface to master side of receive FIFO
        // .c1_m_axi_rx_tdata(c1_rx_to_c0_tx_axi_tdata[0:15] ),       // note index order
        // .c1_m_axi_rx_tkeep(c1_rx_to_c0_tx_axi_keep[0:1]),        // note index order
        // .c1_m_axi_rx_tvalid(c1_rx_to_c0_tx_axi_tvalid),
        // .c1_m_axi_rx_tlast(c1_rx_to_c0_tx_axi_tlast),
        // .c1_m_axi_rx_tready(c1_rx_to_c0_tx_axi_tready),            // input wire m_axis_tready
        // serial I/O pins
        // .c1_rxp(c1_rx), .c1_rxn(c1_rx_N),                   // receive from channel 0 FPGA
        // .c1_txp(c1_tx), .c1_txn(c1_tx_N)                   // transmit to channel 0 FPGA

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

    // simpleDataTransfer module
    simpleDataTransfer sdt(
        // Interface to AMC13 DAQ Link
        .daq_valid(daq_valid),                // output from dtm
        .daq_header(daq_header),              // output from dtm
        .daq_trailer(daq_trailer),            // output from dtm
        .daq_data(daq_data),                  // output from dtm
        .daq_ready(daq_ready),                // input to dtm
        // .daq_almost_full(daq_almost_full), // currently ignored by dtm

        // Interface to FIFO (connected to the Aurora serial link to the channel FPGA)
        .fifo_ready(axi_stream_to_ipbus_tready),       // output from dtm
        .fifo_data(axi_stream_to_ipbus_tdata),         // input to dtm
        .fifo_last(axi_stream_to_ipbus_tlast),         // input to dtm
        .fifo_valid(axi_stream_to_ipbus_tvalid),       // input to dtm

        // Other connections required by dtm module
        .clk(clk125),           // input to dtm
        .rst(rst_from_ipb)      // input to dtm
    );

    // wires connecting the fifo to the tm
    (* mark_debug = "true" *) wire tm_to_fifo_tvalid, tm_to_fifo_tready;
    (* mark_debug = "true" *) wire[23:0] tm_to_fifo_tdata;
    // wires connecting the fifo to the dtm
    (* mark_debug = "true" *) wire fifo_to_dtm_tvalid, fifo_to_dtm_tready;
    (* mark_debug = "true" *) wire[23:0] fifo_to_dtm_tdata;

    // fifo expects a different (negative) reset signal
    wire local_axis_resetn;
    assign local_axis_resetn = ~rst_from_ipb;

    // fill number FIFO
    fill_num_axis_data_fifo fill_num_fifo (
      .s_axis_aresetn(local_axis_resetn),            // input wire s_axis_aresetn
      .s_axis_aclk(clk125),                          // input wire s_axis_aclk
      .s_axis_tvalid(tm_to_fifo_tvalid),             // input wire s_axis_tvalid
      .s_axis_tready(tm_to_fifo_tready),             // output wire s_axis_tready
      .s_axis_tdata(tm_to_fifo_tdata),               // input wire [23 : 0] s_axis_tdata
      .m_axis_tvalid(fifo_to_dtm_tvalid),            // output wire m_axis_tvalid
      .m_axis_tready(fifo_to_dtm_tready),            // input wire m_axis_tready
      .m_axis_tdata(fifo_to_dtm_tdata)               // output wire [23 : 0] m_axis_tdata
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

endmodule