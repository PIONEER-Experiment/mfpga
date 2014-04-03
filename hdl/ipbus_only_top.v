
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
        .debug(debug[13:8])
    );
endmodule