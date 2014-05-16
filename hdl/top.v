
module wfd_top(
	input wire gtx_clk0, gtx_clk0_N,
	output wire gige_tx, gige_tx_N,
	input wire gige_rx, gige_rx_N,
    input wire daq_rx, daq_rx_N,
    output wire daq_tx, daq_tx_N,
    input wire c0_rx, c0_rx_N,
    output wire c0_tx, c0_tx_N,
    // input wire c1_rx, c1_rx_N,
    // output wire c1_tx, c1_tx_N,
    input wire clkin,
    output wire[15:0] debug,
    output wire[4:0] acq_trigs,
    output wire led0, led1
);
    reg sfp_los = 0;
    wire eth_link_status;
    wire rst_from_ipb;
    wire clk200;
    wire clkfb;
    wire clk125;
    wire clk50;
    wire gtrefclk0;

    wire pll_lock;

    wire axi_stream_to_ipbus_tvalid, axi_stream_to_ipbus_tlast, axi_stream_to_ipbus_tready;
    wire[31:0] axi_stream_to_ipbus_tdata;
    wire[3:0] axi_stream_to_ipbus_tstrb;
    wire[3:0] axi_stream_to_ipbus_tkeep;
    wire[3:0] axi_stream_to_ipbus_tid;
    wire[3:0] axi_stream_to_ipbus_tdest;

    wire axi_stream_from_ipbus_tvalid, axi_stream_from_ipbus_tlast, axi_stream_from_ipbus_tready;
    wire[31:0] axi_stream_from_ipbus_tdata;
    wire[3:0] axi_stream_from_ipbus_tstrb;
    wire[3:0] axi_stream_from_ipbus_tkeep;
    wire[3:0] axi_stream_from_ipbus_tid;
    wire[3:0] axi_stream_from_ipbus_tdest;

    assign led0 = eth_link_status; // green
    assign led1 = ~eth_link_status; // red

    assign clk50 = clkin;

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

    wire daq_valid, daq_header, daq_trailer;
    wire[63:0] daq_data;
    wire daq_ready, daq_almost_full;

    wire trigger_from_ipbus;
    wire[4:0] chan_triggers;
    assign acq_trigs = chan_triggers;

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
        .user_ipb_clk(user_ipb_clk),            // programming clock
        .user_ipb_strobe(user_ipb_strobe),      // this ipb space is selected for an I/O operation
        .user_ipb_addr(user_ipb_addr[31:0]),    // slave address, memory or register
        .user_ipb_write(user_ipb_write),        // this is a write operation
        .user_ipb_wdata(user_ipb_wdata[31:0]),  // data to write for write operations
        .user_ipb_rdata(user_ipb_rdata[31:0]),  // data returned for read operations
        .user_ipb_ack(user_ipb_ack),            // 'write' data has been stored, 'read' data is ready
        .user_ipb_err(1'b0),                    // '1' if error, '0' if OK? We never generate an error!

        .axi_stream_in_tvalid(axi_stream_to_ipbus_tvalid),
        .axi_stream_in_tdata(axi_stream_to_ipbus_tdata),
        .axi_stream_in_tstrb(axi_stream_to_ipbus_tstrb),
        .axi_stream_in_tkeep(axi_stream_to_ipbus_tkeep),
        .axi_stream_in_tlast(axi_stream_to_ipbus_tlast),
        .axi_stream_in_tid(axi_stream_to_ipbus_tid),
        .axi_stream_in_tdest(axi_stream_to_ipbus_tdest),
        .axi_stream_in_tready(axi_stream_to_ipbus_tready),

        .axi_stream_out_tvalid(axi_stream_from_ipbus_tvalid),
        .axi_stream_out_tdata(axi_stream_from_ipbus_tdata),
        .axi_stream_out_tstrb(axi_stream_from_ipbus_tstrb),
        .axi_stream_out_tkeep(axi_stream_from_ipbus_tkeep),
        .axi_stream_out_tlast(axi_stream_from_ipbus_tlast),
        .axi_stream_out_tid(axi_stream_from_ipbus_tid),
        .axi_stream_out_tdest(axi_stream_from_ipbus_tdest),
        .axi_stream_out_tready(axi_stream_from_ipbus_tready),

        .daq_valid(daq_valid),
        .daq_header(daq_header),
        .daq_trailer(daq_trailer),
        .daq_data(daq_data),
        .daq_ready(daq_ready),
        .daq_almost_full(daq_almost_full),

        .trigger_out(trigger_from_ipbus),

        .debug()
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

        .TTCclk(1'b0),
        .BcntRes(1'b0),
        .trig(8'd0),
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


    channel_triggers ct (
        .ipb_clk(clk125),
        .trigger_in(trigger_from_ipbus),
        .chan_trigger_out(chan_triggers)
        );

    wire rst_n;
    assign rst_n = ~rst_from_ipb;

    wire axi_stream_from_c0_tvalid, axi_stream_from_c0_tlast, axi_stream_from_c0_tready;
    wire[0:15] axi_stream_from_c0_tdata;
    wire[0:1] axi_stream_from_c0_tkeep;

    wire axi_stream_to_c0_tvalid, axi_stream_to_c0_tlast, axi_stream_to_c0_tready;
    wire[0:15] axi_stream_to_c0_tdata;
    wire[0:1] axi_stream_to_c0_tkeep;

    // AXI4-Stream data width converter
    axis_dwidth_converter_m32_d16 channel_to_ipbus (
      .aclk(clk125),                    // input wire aclk
      .aresetn(rst_n),              // input wire aresetn
      .s_axis_tvalid(axi_stream_from_c0_tvalid),  // input wire s_axis_tvalid
      .s_axis_tready(axi_stream_from_c0_tready),  // output wire s_axis_tready
      .s_axis_tdata(axi_stream_from_c0_tdata),    // input wire [15 : 0] s_axis_tdata
      .s_axis_tkeep(axi_stream_from_c0_tkeep),    // input wire [1 : 0] s_axis_tkeep
      .s_axis_tlast(axi_stream_from_c0_tlast),    // input wire s_axis_tlast
      .m_axis_tvalid(axi_stream_to_ipbus_tvalid),  // output wire m_axis_tvalid
      .m_axis_tready(axi_stream_to_ipbus_tready),  // input wire m_axis_tready
      .m_axis_tdata(axi_stream_to_ipbus_tdata),    // output wire [31 : 0] m_axis_tdata
      .m_axis_tkeep(axi_stream_to_ipbus_tkeep),    // output wire [3 : 0] m_axis_tkeep
      .m_axis_tlast(axi_stream_to_ipbus_tlast)    // output wire m_axis_tlast
    );

    axis_dwidth_converter_m16_d32 ipbus_to_channel (
      .aclk(clk125),                    // input wire aclk
      .aresetn(rst_n),              // input wire aresetn
      .s_axis_tvalid(axi_stream_from_ipbus_tvalid),  // input wire s_axis_tvalid
      .s_axis_tready(axi_stream_from_ipbus_tready),  // output wire s_axis_tready
      .s_axis_tdata(axi_stream_from_ipbus_tdata),    // input wire [31 : 0] s_axis_tdata
      .s_axis_tkeep(axi_stream_from_ipbus_tkeep),    // input wire [3 : 0] s_axis_tkeep
      .s_axis_tlast(axi_stream_from_ipbus_tlast),    // input wire s_axis_tlast
      .m_axis_tvalid(axi_stream_to_c0_tvalid),  // output wire m_axis_tvalid
      .m_axis_tready(axi_stream_to_c0_tready),  // input wire m_axis_tready
      .m_axis_tdata(axi_stream_to_c0_tdata),    // output wire [15 : 0] m_axis_tdata
      .m_axis_tkeep(axi_stream_to_c0_tkeep),    // output wire [1 : 0] m_axis_tkeep
      .m_axis_tlast(axi_stream_to_c0_tlast)    // output wire m_axis_tlast
    );

    assign debug[8] = user_ipb_strobe;
    assign debug[9] = user_ipb_write;
    assign debug[10] = user_ipb_ack;

    // Serial links to channel FPGAs
    all_channels channels(
        .clk50(clk50),
        .clk50_reset(1'b0), // FIXME
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
        .c0_s_axi_tx_tdata(axi_stream_to_c0_tdata[0:15]),        // note index order
        .c0_s_axi_tx_tkeep(axi_stream_to_c0_tkeep[0:1]),         // note index order
        .c0_s_axi_tx_tvalid(axi_stream_to_c0_tvalid),
        .c0_s_axi_tx_tlast(axi_stream_to_c0_tlast),
        .c0_s_axi_tx_tready(axi_stream_to_c0_tready),
        // RX Interface to master side of receive FIFO
        .c0_m_axi_rx_tdata(axi_stream_from_c0_tdata[0:15] ),       // note index order
        .c0_m_axi_rx_tkeep(axi_stream_from_c0_tkeep[0:1]),        // note index order
        .c0_m_axi_rx_tvalid(axi_stream_from_c0_tvalid),
        .c0_m_axi_rx_tlast(axi_stream_from_c0_tlast),
        .c0_m_axi_rx_tready(axi_stream_from_c0_tready),            // input wire m_axis_tready
        // serial I/O pins
        .c0_rxp(c0_rx), .c0_rxn(c0_rx_N),                   // receive from channel 0 FPGA
        .c0_txp(c0_tx), .c0_txn(c0_tx_N)                   // transmit to channel 0 FPGA

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
    );

    // AXI4-Stream loopback with FIFO buffer
    // axis_data_fifo_ipbus_loopback axi_looopback (
    //   .s_axis_aresetn(rst_n),          // input wire s_axis_aresetn
    //   .s_axis_aclk(clk125),                // input wire s_axis_aclk
    //   .s_axis_tvalid(axi_stream_from_ipbus_tvalid),            // input wire s_axis_tvalid
    //   .s_axis_tready(axi_stream_from_ipbus_tready),            // output wire s_axis_tready
    //   .s_axis_tdata(axi_stream_from_ipbus_tdata),              // input wire [31 : 0] s_axis_tdata
    //   .s_axis_tkeep(axi_stream_from_ipbus_tkeep),              // input wire [3 : 0] s_axis_tkeep
    //   .s_axis_tlast(axi_stream_from_ipbus_tlast),              // input wire s_axis_tlast
    //   .s_axis_tid(axi_stream_from_ipbus_tid),                  // input wire [3 : 0] s_axis_tid
    //   .s_axis_tdest(axi_stream_from_ipbus_tdest),              // input wire [3 : 0] s_axis_tdest
    //   .m_axis_tvalid(axi_stream_to_ipbus_tvalid),            // output wire m_axis_tvalid
    //   .m_axis_tready(axi_stream_to_ipbus_tready),            // input wire m_axis_tready
    //   .m_axis_tdata(axi_stream_to_ipbus_tdata),              // output wire [31 : 0] m_axis_tdata
    //   .m_axis_tkeep(axi_stream_to_ipbus_tkeep),              // output wire [3 : 0] m_axis_tkeep
    //   .m_axis_tlast(axi_stream_to_ipbus_tlast),              // output wire m_axis_tlast
    //   .m_axis_tid(axi_stream_to_ipbus_tid),                  // output wire [3 : 0] m_axis_tid
    //   .m_axis_tdest(axi_stream_to_ipbus_tdest),              // output wire [3 : 0] m_axis_tdest
    //   .axis_data_count(axis_data_count),        // output wire [31 : 0] axis_data_count
    //   .axis_wr_data_count(axis_wr_data_count),  // output wire [31 : 0] axis_wr_data_count
    //   .axis_rd_data_count(axis_rd_data_count)  // output wire [31 : 0] axis_rd_data_count
    // );
endmodule