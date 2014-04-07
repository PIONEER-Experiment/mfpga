
module ipbus_only_top(
	input wire gtx_clk0, gtx_clk0_N,
	output wire gige_tx, gige_tx_N,
	input wire gige_rx, gige_rx_N,
    input wire clkin,
    output wire[15:0] debug
);
    reg sfp_los = 0;
    wire rst_from_ipb;
    wire clk200_ub, clk200;
    wire clk125;
    wire clkfb;

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


    MMCME2_BASE #(
        .CLKFBOUT_MULT_F(20.0),
        .CLKIN1_PERIOD(20), // in ns, so 20 -> 50 MHz
        .CLKOUT1_DIVIDE(5),
    ) clk (
        .CLKIN1(clkin),
        .CLKOUT1(clk200_ub),
        .LOCKED(debug[15]),
        .RST(rst_from_ipb),
        .CLKFBOUT(clkfb),
        .CLKFBIN(clkfb)
    );

    BUFG clk200_bufg(
        .O(clk200),
        .I(clk200_ub)
    );

    assign debug[14] = clk125;

    // IPBus module
    ipbus_top ipb(
        .gt_clkp(gtx_clk0), .gt_clkn(gtx_clk0_N),
        .gt_txp(gige_tx), .gt_txn(gige_tx_N),
        .gt_rxp(gige_rx), .gt_rxn(gige_rx_N),
        .sfp_los(sfp_los),
        .rst_out(rst_from_ipb),
        .clk_200(clk200),
        .clk_125(clk125), // output, already on bufg
        .ipb_clk(clk125),
        .debug(debug[13:8]),

        .axi_stream_in_tvalid(axi_stream_to_ipbus_tvalid),
        .axi_stream_in_tdata(axi_stream_to_ipbus_tdata),
        .axi_stream_in_tstrb(axi_stream_to_ipbus_tstrb),
        .axi_stream_in_tkeep(axi_stream_to_ipbus_tkeep),
        .axi_stream_in_tlast(axi_stream_to_ipbus_tlast),
        .axi_stream_in_tid(axi_stream_to_ipbus_tid),
        .axi_stream_in_tdest(axi_stream_to_ipbus_tdest),
        .axi_stream_in_tready(axi_stream_to_ipbus_tready),

        .axi_stream_out_tvalid(axi_stream_to_ipbus_tvalid),
        .axi_stream_out_tdata(axi_stream_to_ipbus_tdata),
        .axi_stream_out_tstrb(axi_stream_to_ipbus_tstrb),
        .axi_stream_out_tkeep(axi_stream_to_ipbus_tkeep),
        .axi_stream_out_tlast(axi_stream_to_ipbus_tlast),
        .axi_stream_out_tid(axi_stream_to_ipbus_tid),
        .axi_stream_out_tdest(axi_stream_to_ipbus_tdest),
        .axi_stream_out_tready(axi_stream_to_ipbus_tready)
    );

    // wire rst_n;
    // assign rst_n = ~rst_from_ipb;

    // // AXI4-Stream loopback with FIFO buffer
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