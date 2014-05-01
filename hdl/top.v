
module wfd_top(
	input wire gtx_clk0, gtx_clk0_N,
	output wire gige_tx, gige_tx_N,
	input wire gige_rx, gige_rx_N,
    input wire daq_rx, daq_rx_N,
    output wire daq_tx, daq_tx_N,
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
    assign debug[15] = pll_lock;


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
    assign debug[12:8] = chan_triggers;

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
        .trigger_in(trigger_from_ipbus),
        .chan_trigger_out(chan_triggers)
        );

    wire rst_n;
    assign rst_n = ~rst_from_ipb;

    // AXI4-Stream loopback with FIFO buffer
    axis_data_fifo_ipbus_loopback axi_looopback (
      .s_axis_aresetn(rst_n),          // input wire s_axis_aresetn
      .s_axis_aclk(clk125),                // input wire s_axis_aclk
      .s_axis_tvalid(axi_stream_from_ipbus_tvalid),            // input wire s_axis_tvalid
      .s_axis_tready(axi_stream_from_ipbus_tready),            // output wire s_axis_tready
      .s_axis_tdata(axi_stream_from_ipbus_tdata),              // input wire [31 : 0] s_axis_tdata
      .s_axis_tkeep(axi_stream_from_ipbus_tkeep),              // input wire [3 : 0] s_axis_tkeep
      .s_axis_tlast(axi_stream_from_ipbus_tlast),              // input wire s_axis_tlast
      .s_axis_tid(axi_stream_from_ipbus_tid),                  // input wire [3 : 0] s_axis_tid
      .s_axis_tdest(axi_stream_from_ipbus_tdest),              // input wire [3 : 0] s_axis_tdest
      .m_axis_tvalid(axi_stream_to_ipbus_tvalid),            // output wire m_axis_tvalid
      .m_axis_tready(axi_stream_to_ipbus_tready),            // input wire m_axis_tready
      .m_axis_tdata(axi_stream_to_ipbus_tdata),              // output wire [31 : 0] m_axis_tdata
      .m_axis_tkeep(axi_stream_to_ipbus_tkeep),              // output wire [3 : 0] m_axis_tkeep
      .m_axis_tlast(axi_stream_to_ipbus_tlast),              // output wire m_axis_tlast
      .m_axis_tid(axi_stream_to_ipbus_tid),                  // output wire [3 : 0] m_axis_tid
      .m_axis_tdest(axi_stream_to_ipbus_tdest),              // output wire [3 : 0] m_axis_tdest
      .axis_data_count(axis_data_count),        // output wire [31 : 0] axis_data_count
      .axis_wr_data_count(axis_wr_data_count),  // output wire [31 : 0] axis_wr_data_count
      .axis_rd_data_count(axis_rd_data_count)  // output wire [31 : 0] axis_rd_data_count
    );
endmodule