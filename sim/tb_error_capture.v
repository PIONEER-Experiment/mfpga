`timescale 1ns/1ps
// error_capture_selftrigc: the first loss or fault freezes the snapshot and sets the TTS flags; later
// errors accumulate in "since"; warnings do not snapshot; a TTC-domain pulse is caught; the clear
// (rising edge of the control bit) empties everything and the next error snapshots again.
module tb;
reg clk=0; always #4 clk=~clk;          // 125 MHz
reg tclk=0; always #12.5 tclk=~tclk;    // 40 MHz
reg rst=1, clear=0;
reg [15:0] lossp=0; reg [7:0] faultp=0; reg [5:0] warnp=0; reg em=0, cw=0; reg [6:0] cew=0; reg cev=0;
reg [34:0] cm_state = 35'h1; reg [3:0] ttr=4'h1; reg [5:0] cac=6'h1; reg [6:0] tp=7'h1; reg [4:0] dones=0, erc=0, esn=0, pause=0, cen=5'b11111, rxv=0, txr=5'b11111;
reg [3:0] dest=0; reg [23:0] evn=24'd100, trn=24'd120; reg [43:0] ts=44'h123456789; reg [31:0] w1=32'h11, w2=32'h22, w3=32'h33, w4=32'h44, misc=32'hABCD0000; reg [8:0] rs=9'd0;
wire data_loss, hw_fault, warning; wire [2:0] summ;
wire [31:0] s35,s36,s37,s38,s39,s40,s41,s42,s43,s44,s45,s46,s47,s48,s49;
error_capture_selftrigc dut(.clk(clk),.rst(rst),.clear(clear),.err_loss_pulse(lossp),.err_fault_pulse(faultp),.err_warn_pulse(warnp),.empty_midrun(em),.cac_wait_gave_up(cw),
  .chan_err_word(cew),.chan_err_valid(cev),.cm_state(cm_state),.ttr_state(ttr),.cac_state(cac),.tp_state(tp),.acq_dones(dones),.chan_error_rc(erc),.chan_error_sn(esn),
  .acq_readout_pause(pause),.chan_en(cen),.cm_rx_valid(rxv),.cm_tx_ready(txr),.cm_rx_ready(1'b1),.cm_tx_valid(1'b0),.cm_tx_dest(dest),.event_num(evn),.trig_num(trn),.trig_timestamp(ts),
  .last_rsn_word(w1),.last_rc_word(w2),.last_info1_word(w3),.last_info4_word(w4),.retry_status(rs),.misc_live(misc),
  .data_loss(data_loss),.hw_fault(hw_fault),.warning(warning),.err_summary(summ),
  .status_reg35(s35),.status_reg36(s36),.status_reg37(s37),.status_reg38(s38),.status_reg39(s39),.status_reg40(s40),.status_reg41(s41),.status_reg42(s42),.status_reg43(s43),
  .status_reg44(s44),.status_reg45(s45),.status_reg46(s46),.status_reg47(s47),.status_reg48(s48),.status_reg49(s49));
integer fails=0;
task check(input c, input [8*64-1:0] what); begin if (!c) begin fails=fails+1; $display("  FAIL: %0s", what); end end endtask
task pulse_loss(input integer b); begin @(posedge clk); lossp <= 16'd1 << b; @(posedge clk); lossp <= 0; repeat(3) @(posedge clk); end endtask
task pulse_fault(input integer b); begin @(posedge clk); faultp <= 8'd1 << b; @(posedge clk); faultp <= 0; repeat(3) @(posedge clk); end endtask
task do_clear; begin @(posedge clk); clear <= 1; repeat(3) @(posedge clk); clear <= 0; repeat(3) @(posedge clk); end endtask
initial begin
  repeat(4) @(posedge clk); rst<=0; repeat(4) @(posedge clk);
  check(s35 == 0 && !data_loss && !hw_fault && !warning, "clean after reset");
  // a warning alone: flag, no snapshot
  @(posedge clk); warnp <= 6'b010010; @(posedge clk); warnp <= 0; repeat(3) @(posedge clk);
  check(warning && !data_loss && !s35[31], "warning sets the flag only"); check(s36[8:5] == 4'b0010 && s49[7:0] == 8'b00010010, "warning bits recorded (36 holds the low four, 49 all six)");
  // first loss: snapshot
  cm_state = 35'h1000; dest = 4'd2; evn = 24'd101; rs = 9'b01_10_00101;
  pulse_loss(3);
  check(data_loss && summ == 3'b101, "data loss latched, summary {loss, fault, warning}");
  check(s35[31] && s35[27:24] == 4'd1 && s35[15:0] == 16'h0008, "snapshot valid, count 1, loss bit 3");
  check(s36[31:24] == 8'h03 && s36[23:20] == 4'd2 && s36[4:3] == 2'b01 && s36[1:0] == 2'b10, "first cause = loss 3, channel 2, retries");
  check(s37 == 32'h1000 && s40 == {5'b00101, 3'd0, 24'd101} && s41 == 32'd120 && s42 == 32'h23456789 && s43 == 32'h1, "snapshot words");
  check(s44 == 32'h11 && s47 == 32'h44 && s48 == 32'hABCD0000, "last words and misc frozen");
  // later errors do not change the snapshot, but accumulate
  cm_state = 35'h2000; evn = 24'd102;
  pulse_loss(0); pulse_fault(1);
  check(s37 == 32'h1000 && s40[23:0] == 24'd101, "snapshot unchanged by later errors");
  check(s35[15:0] == 16'h0009 && s35[23:16] == 8'h02 && hw_fault, "later loss and fault bits accumulate; fault flag set");
  check(s49[31:16] == 16'h0001 && s49[15:8] == 8'h02, "since-snapshot bits");
  // a channel error word
  @(posedge clk); cew <= 7'b1000011; cev <= 1; dest <= 4'd3; @(posedge clk); cev <= 0; repeat(2) @(posedge clk);
  check(s36[19:13] == 7'b1000011 && s36[12:9] == 4'd3, "channel-reported word and source");
  // a TTC-domain pulse (25 ns)
  @(posedge tclk); em <= 1; @(posedge tclk); em <= 0; repeat(8) @(posedge clk);
  check(s35[9], "TTC-domain empty-mid-run pulse caught (bit 9)");
  @(posedge tclk); cw <= 1; @(posedge tclk); cw <= 0; repeat(8) @(posedge clk);
  check(s35[10], "TTC-domain controller gave-up pulse caught (bit 10)");
  // clear: everything goes, the count stays, and the next error snapshots again
  do_clear;
  check(!data_loss && !hw_fault && !warning && s35[31:28] == 0 && s35[23:0] == 0 && s49 == 0 && s36[19:13] == 0, "clear empties the flags, bits and channel word");
  check(s35[27:24] == 4'd1, "snapshot count survives the clear");
  cm_state = 35'h4000; pulse_fault(0);
  check(hw_fault && !data_loss && s35[31] && s35[27:24] == 4'd2 && s36[31:24] == 8'h80 && s37 == 32'h4000, "fault after the clear: new snapshot, first cause = fault 0");
  // a held clear level does not keep clearing (edge)
  @(posedge clk); clear <= 1; repeat(3) @(posedge clk); pulse_loss(2); check(data_loss, "an error while the clear bit is held high is kept (edge-triggered clear)"); clear <= 0;
  $display("%0d failure(s)", fails); if (fails == 0) $display("PASS"); else $display("FAIL"); $finish;
end
endmodule
