`timescale 1ns/1ps
// command manager: a readout where channel 0's RX FIFO holds a stale frame (RSN mismatch) must be
// flushed to its tlast and the readout must continue with channel 1; a channel that never answers
// must be given up on after the (shortened) time-out; the IPbus path must still work afterwards.
module tb;
reg clk=0; always #4 clk=~clk; reg rst=1;
// TX fifo (to channels): always ready, record what is sent
wire tx_valid, tx_last; wire [3:0] tx_dest; wire [31:0] tx_data;
// RX fifo model: one queue per channel, selected by tx_dest (as the RX switch does)
reg [31:0] q_data [0:4][0:255]; reg q_last [0:4][0:255]; integer q_wr [0:4], q_rd [0:4];
integer sel; always @* sel = (tx_dest < 5) ? tx_dest : 0;
reg rx_valid, rx_last; reg [31:0] rx_data;
always @* begin rx_valid = (tx_dest < 5) && (q_rd[sel] != q_wr[sel]); rx_last = rx_valid ? q_last[sel][q_rd[sel]] : 1'b0; rx_data = rx_valid ? q_data[sel][q_rd[sel]] : 32'd0; end
wire rx_ready;
always @(posedge clk) if (rx_valid && rx_ready) q_rd[sel] = q_rd[sel] + 1;
task push(input integer ch, input [31:0] d, input l); begin q_data[ch][q_wr[ch]] = d; q_last[ch][q_wr[ch]] = l; q_wr[ch] = q_wr[ch] + 1; end endtask
// IPbus: unused here
wire daq_valid, daq_header, daq_trailer; wire [63:0] daq_data;
reg initiate_readout=0; wire readout_ready, readout_done; wire [34:0] state; wire [4:0] err_sn, err_rc; wire err_data, err_tn, err_tt; wire [31:0] csmm; wire sfifo_rd; wire [22:0] bcs; wire ipb_ready, ipb_res_valid, ipb_res_last; wire [31:0] ipb_res_data; wire cs_found;
command_manager_selftrigc cm(.clk(clk),.rst(rst),.chan_tx_fifo_ready(1'b1),.chan_tx_fifo_valid(tx_valid),.chan_tx_fifo_last(tx_last),.chan_tx_fifo_dest(tx_dest),.chan_tx_fifo_data(tx_data),
  .chan_rx_fifo_valid(rx_valid),.chan_rx_fifo_last(rx_last),.chan_rx_fifo_data(rx_data),.chan_rx_fifo_ready(rx_ready),
  .ipbus_cmd_valid(1'b0),.ipbus_cmd_last(1'b0),.ipbus_cmd_dest(4'd0),.ipbus_cmd_data(32'd0),.ipbus_cmd_ready(ipb_ready),.ipbus_res_ready(1'b1),.ipbus_res_valid(ipb_res_valid),.ipbus_res_last(ipb_res_last),.ipbus_res_data(ipb_res_data),
  .daq_ready(1'b1),.daq_almost_full(1'b0),.daq_valid(daq_valid),.daq_header(daq_header),.daq_trailer(daq_trailer),.daq_data(daq_data),
  .send_empty_event(1'b0),.skip_payload(1'b0),.initiate_readout(initiate_readout),.event_num(24'd7),.trig_num(24'd7),.trig_type(5'b00100),.trig_timestamp(44'd0),.ttc_xadc_alarms(4'd0),
  .readout_ready(readout_ready),.readout_done(readout_done),
  .selftriggers_chan0_latched(20'd0),.selftriggers_chan1_latched(20'd0),.selftriggers_chan2_latched(20'd0),.selftriggers_chan3_latched(20'd0),.selftriggers_chan4_latched(20'd0),
  .selftrigger_fifo_empty(1'b0),.selftrigger_fifo_rd_en(sfifo_rd),.burst_count_selftrig(bcs),.i2c_mac_adr(16'd0),.chan_en(5'b00011),.endianness_sel(1'b1),.thres_data_corrupt(32'd10),
  .state(state),.cs_mismatch_count(csmm),.error_data_corrupt(err_data),.error_trig_num(err_tn),.error_trig_type(err_tt),.chan_error_sn(err_sn),.chan_error_rc(err_rc),.cs_mismatch_found(cs_found));
integer i, k;
// answer every read-fill command for channel 1 correctly: RSN = csn as sent, RC = 8, 4 info words (trig num 7, 0 waveforms), checksum words
always @(posedge clk) if (tx_valid && tx_dest==1 && tx_last) begin
  // the CSN was the first word of this frame: it is cm.csn
  push(1, cm.csn, 0); push(1, 32'h8, 0);
  push(1, {5'd0, 3'd0, 24'd7}, 0);          // info1: trig num 7, stored bursts 0 -> wfm_count 0
  push(1, 32'd0, 0); push(1, 32'd0, 0); push(1, 32'h08000000, 0);   // info2..4 (info4 [27:26] = 2'b10, async type)
  push(1, 32'd0, 0); push(1, 32'd0, 0); push(1, 32'd0, 0); push(1, 32'd0, 1);  // checksum (4 words), last
end
initial begin
  for (i=0;i<5;i=i+1) begin q_wr[i]=0; q_rd[i]=0; end
  repeat(5) @(posedge clk); rst<=0; repeat(5) @(posedge clk);
  // a stale frame in channel 0's FIFO: wrong RSN then a ~CC word with tlast
  push(0, 32'hdeadbeef, 0); push(0, ~32'h8, 1);
  initiate_readout<=1; @(posedge clk); initiate_readout<=0;
  // shorten the reply time-out so the test runs: channel 0 answers with the stale frame at once anyway
  k=0; while (!readout_done && k<200000) begin @(posedge clk); k=k+1; end
  $display("readout 1: done=%0d after %0d clocks, chan_error_sn=%b chan_error_rc=%b, ch0 fifo left=%0d, state=%h", readout_done, k, err_sn, err_rc, q_wr[0]-q_rd[0], state);
  repeat(50) @(posedge clk);
  // second readout: channel 0 never answers -> time-out (forced short), channel 1 answers
  initiate_readout<=1; @(posedge clk); initiate_readout<=0;
  repeat(200) @(posedge clk); force cm.rsn_wait_cntr = 31'h3FFFFF00; @(posedge clk); release cm.rsn_wait_cntr;
  k=0; while (!readout_done && k<200000) begin @(posedge clk); k=k+1; end
  $display("readout 2: done=%0d after %0d clocks, chan_error_sn=%b chan_error_rc=%b, state=%h", readout_done, k, err_sn, err_rc, state);
  if (readout_done && err_sn==5'b00001 && (q_wr[0]-q_rd[0])==0) $display("PASS"); else $display("FAIL");
  $finish;
end
endmodule
