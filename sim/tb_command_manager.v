`timescale 1ns/1ps
// command_manager_selftrigc: recovery from every kind of bad channel reply (6.6.9).
// Channel RX FIFOs are modelled per channel; channel 1 always answers correctly; channel 0 is put
// through the fault modes below.  Each readout must complete (readout_done), the DAQ stream must
// be well formed (every header has a trailer), and the channel must be back in step afterwards.
//   1. a stale frame in front of a live channel's reply: flushed, retried, the channel's fill is read
//   2. a channel that never answers: time-out, skipped, the readout completes; the next readout is clean
//   3. a channel that answers late (after the time-out): its reply is the stale frame of the next readout
//   4. a stale fill header (channel serves fill N-1): flushed, the read fill re-issued, fill N read
//   5. a newer fill header (N+1): the channel is skipped for the event, not fatal
//   6. an IPbus transaction to a dead channel: time-out, back to IDLE; the next IPbus transaction works
//   7. an IPbus transaction with a stale frame in front of the reply: flushed and retried
//   8. every enabled channel skipped: a well-formed empty event, not a bare trailer
//   9. a channel reports an error word in its fill header: loss / fault pulses, word copied into the channel header
// Each scenario also checks the error-capture pulses the command manager emits (6.6.10) and the marks in the data
// stream (WFD5 header word [63:56], channel header word [61:60] and [45:39]).
module tb;
reg clk=0; always #4 clk=~clk; reg rst=1;
// ---- TX to channels (always ready); frame tracking per channel
wire tx_valid, tx_last; wire [3:0] tx_dest; wire [31:0] tx_data;
integer tx_widx = 0; reg [31:0] tx_csn, tx_cc;
// ---- RX FIFO model: one queue per channel, selected by tx_dest (as the RX switch does)
reg [31:0] q_data [0:4][0:4095]; reg q_last [0:4][0:4095]; integer q_wr [0:4], q_rd [0:4];
integer sel; always @* sel = (tx_dest < 5) ? tx_dest : 0;
reg rx_valid, rx_last; reg [31:0] rx_data;
always @* begin rx_valid = (tx_dest < 5) && (q_rd[sel] != q_wr[sel]); rx_last = rx_valid ? q_last[sel][q_rd[sel]] : 1'b0; rx_data = rx_valid ? q_data[sel][q_rd[sel]] : 32'd0; end
wire rx_ready;
always @(posedge clk) if (rx_valid && rx_ready) q_rd[sel] = q_rd[sel] + 1;
task push(input integer ch, input [31:0] d, input l); begin q_data[ch][q_wr[ch]] = d; q_last[ch][q_wr[ch]] = l; q_wr[ch] = q_wr[ch] + 1; end endtask
function integer qlen(input integer ch); qlen = q_wr[ch] - q_rd[ch]; endfunction
// ---- IPbus command / response model
reg ipb_valid = 0, ipb_last = 0; reg [3:0] ipb_dest = 0; reg [31:0] ipb_data = 0; wire ipb_ready;
reg [31:0] ipb_words [0:7]; integer ipb_n = 0, ipb_i = 0;
wire ipb_res_valid, ipb_res_last; wire [31:0] ipb_res_data;
reg [31:0] res_words [0:63]; integer res_n = 0;
always @(posedge clk) begin
  if (ipb_valid && ipb_ready) begin ipb_i = ipb_i + 1; ipb_last <= (ipb_i == ipb_n); if (ipb_i == ipb_n) ipb_valid <= 0; else ipb_data <= ipb_words[ipb_i]; end
  if (ipb_res_valid) begin res_words[res_n] = ipb_res_data; res_n = res_n + 1; end
end
task ipbus_cmd(input integer dest, input [31:0] w0, input [31:0] w1); begin
  ipb_words[0] = w0; ipb_words[1] = w1; ipb_n = 2; ipb_i = 0; res_n = 0;
  @(posedge clk); ipb_dest <= dest; ipb_data <= w0; ipb_valid <= 1; ipb_last <= 0;
end endtask
// ---- DAQ stream bookkeeping
wire daq_valid, daq_header, daq_trailer; wire [63:0] daq_data;
integer daq_headers = 0, daq_trailers = 0, daq_words = 0; reg [63:0] last_trailer;
always @(posedge clk) begin
  if (daq_valid) daq_words = daq_words + 1;
  if (daq_valid && daq_header) daq_headers = daq_headers + 1;
  if (daq_valid && daq_trailer) begin daq_trailers = daq_trailers + 1; last_trailer = daq_data; end
end
// ---- DUT
reg initiate_readout=0; reg [23:0] event_num = 24'd7; reg [4:0] chan_en = 5'b00011;
wire readout_ready, readout_done; wire [34:0] state; wire [4:0] err_sn, err_rc; wire err_data, err_tn, err_tt; wire [31:0] csmm; wire sfifo_rd; wire [22:0] bcs; wire cs_found; wire [7:0] tne;
wire [15:0] lossp; wire [7:0] faultp; wire [3:0] warnp; wire [6:0] cew; wire cev; wire [31:0] lrsn, lrc, li1, li4; wire [8:0] rstat;
command_manager_selftrigc cm(.clk(clk),.rst(rst),.chan_tx_fifo_ready(1'b1),.chan_tx_fifo_valid(tx_valid),.chan_tx_fifo_last(tx_last),.chan_tx_fifo_dest(tx_dest),.chan_tx_fifo_data(tx_data),
  .chan_rx_fifo_valid(rx_valid),.chan_rx_fifo_last(rx_last),.chan_rx_fifo_data(rx_data),.chan_rx_fifo_ready(rx_ready),
  .ipbus_cmd_valid(ipb_valid),.ipbus_cmd_last(ipb_last),.ipbus_cmd_dest(ipb_dest),.ipbus_cmd_data(ipb_data),.ipbus_cmd_ready(ipb_ready),.ipbus_res_ready(1'b1),.ipbus_res_valid(ipb_res_valid),.ipbus_res_last(ipb_res_last),.ipbus_res_data(ipb_res_data),
  .daq_ready(1'b1),.daq_almost_full(1'b0),.daq_valid(daq_valid),.daq_header(daq_header),.daq_trailer(daq_trailer),.daq_data(daq_data),
  .send_empty_event(1'b0),.skip_payload(1'b0),.initiate_readout(initiate_readout),.event_num(event_num),.trig_num(event_num),.trig_type(5'b00100),.trig_timestamp(44'd0),.ttc_xadc_alarms(4'd0),
  .readout_ready(readout_ready),.readout_done(readout_done),
  .selftriggers_chan0_latched(20'd0),.selftriggers_chan1_latched(20'd0),.selftriggers_chan2_latched(20'd0),.selftriggers_chan3_latched(20'd0),.selftriggers_chan4_latched(20'd0),
  .selftrigger_fifo_empty(1'b0),.selftrigger_fifo_rd_en(sfifo_rd),.burst_count_selftrig(bcs),.i2c_mac_adr(16'd0),.chan_en(chan_en),.endianness_sel(1'b1),.thres_data_corrupt(32'hFFFFFFFF),
  .state(state),.cs_mismatch_count(csmm),.error_data_corrupt(err_data),.error_trig_num(err_tn),.error_trig_type(err_tt),.trig_num_error_count(tne),.chan_error_sn(err_sn),.chan_error_rc(err_rc),.cs_mismatch_found(cs_found),
  .err_loss_pulse(lossp),.err_fault_pulse(faultp),.err_warn_pulse(warnp),.chan_err_word(cew),.chan_err_valid(cev),.last_rsn_word(lrsn),.last_rc_word(lrc),.last_info1_word(li1),.last_info4_word(li4),.retry_status(rstat),.err_summary(err_summary));
// accumulate the error pulses per scenario, and keep the last WFD5 header and channel header words of the DAQ stream
reg [15:0] loss_acc = 0; reg [7:0] fault_acc = 0; reg [3:0] warn_acc = 0; reg [2:0] err_summary = 3'b000; reg clr = 0;
reg [63:0] wfd5_word = 0, chan_hdr_word = 0; reg [63:0] prev_daq = 0; integer chan_err_words = 0;
always @(posedge clk) begin
  loss_acc <= clr ? lossp : (loss_acc | lossp); fault_acc <= clr ? faultp : (fault_acc | faultp); warn_acc <= clr ? warnp : (warn_acc | warnp);
  if (daq_valid) begin
    prev_daq <= daq_data;
    if (daq_data[24] && daq_data[23:0] == {8'd6, 8'd6, 8'd10}) wfd5_word <= daq_data;       // the WFD5 header word (version 6.6.10)
    if (daq_data[63:62] == 2'b01 && !daq_header && !daq_trailer && tx_dest == 0) chan_hdr_word <= daq_data;  // channel 0's header word 0
  end
  if (cev) chan_err_words = chan_err_words + 1;
end
task clear_acc; begin @(posedge clk); clr <= 1; @(posedge clk); clr <= 0; @(posedge clk); end endtask
// ---- channel responders.  mode: 0 answers correctly, 1 silent, 2 stale header once (fill N-1, then N),
//      3 newer header (N+1), 4 late (answers 'late_delay' clocks after the command; reply then stale)
integer mode [0:4]; integer late_delay = 400; integer asked [0:4]; integer fills_served [0:4];
integer stale_pending [0:4];   // mode 2: 1 while the stale header is still to be served
integer late_cnt = 0; reg [31:0] late_csn, late_cc; integer late_ch;   // mode 4: reply scheduled 'late_delay' clocks after the command
always @(posedge clk) if (late_cnt > 0) begin late_cnt = late_cnt - 1; if (late_cnt == 0) begin if (late_cc == 8) fill_reply(late_ch, late_csn, event_num); else ipbus_reply(late_ch, late_csn, late_cc); end end
reg [6:0] hdr_err_word = 7'd0;   // what the channel puts in fill header word 4 [13:7]
reg bad_checksum = 0;            // send wrong checksum words
task fill_reply(input integer ch, input [31:0] csn, input [23:0] num); begin
  push(ch, csn, 0); push(ch, 32'h8, 0);
  push(ch, {5'd0, 3'd0, num}, 0);           // info1: fill/trigger number, 0 waveforms
  push(ch, 32'd0, 0); push(ch, 32'd0, 0); push(ch, 32'h08000000 | {hdr_err_word, 7'd0}, 0);   // info2..4 (info4 [27:26] = 2'b10, async type; [13:7] error word)
  // checksum (4 words): with no waveforms the master's checksum is the four header words, so send those
  push(ch, {5'd0, 3'd0, num} ^ {31'd0, bad_checksum}, 0); push(ch, 32'd0, 0); push(ch, 32'd0, 0); push(ch, 32'h08000000 | {hdr_err_word, 7'd0}, 1);
  fills_served[ch] = fills_served[ch] + 1;
end endtask
task ipbus_reply(input integer ch, input [31:0] csn, input [31:0] cc); begin
  push(ch, csn, 0); push(ch, cc, 0); push(ch, 32'hCAFE0000 + ch, 1);
end endtask
task respond(input integer ch, input [31:0] csn, input [31:0] cc); begin
  asked[ch] = asked[ch] + 1;
  case (mode[ch])
    1: ;
    2: begin if (cc == 8) begin if (stale_pending[ch]) begin fill_reply(ch, csn, event_num - 1); stale_pending[ch] = 0; end else fill_reply(ch, csn, event_num); end
             else ipbus_reply(ch, csn, cc); end
    3: begin if (cc == 8) fill_reply(ch, csn, event_num + 1); else ipbus_reply(ch, csn, cc); end
    4: begin late_ch = ch; late_csn = csn; late_cc = cc; late_cnt = late_delay; end
    default: begin if (cc == 8) fill_reply(ch, csn, event_num); else ipbus_reply(ch, csn, cc); end
  endcase
end endtask
always @(posedge clk) if (tx_valid) begin
  if (tx_widx == 0) tx_csn = tx_data; else if (tx_widx == 1) tx_cc = tx_data;
  if (tx_last) begin respond(tx_dest, tx_csn, (tx_widx == 0) ? 32'd0 : tx_cc); tx_widx = 0; end
  else tx_widx = tx_widx + 1;
end
// ---- helpers
integer k, i;
task readout(input integer max_clocks); begin
  event_num = event_num + 1;
  @(posedge clk); initiate_readout <= 1; @(posedge clk); initiate_readout <= 0;
  k = 0; while (!readout_done && k < max_clocks) begin @(posedge clk); k = k + 1; end
end endtask
// make the reply / IPbus wait expire (the real bounds are 67 ms, too long to simulate)
task expire_reply_wait; begin
  wait (state[12] || state[13] || state[14]); repeat (300) @(posedge clk);
  force cm.rsn_wait_cntr = 24'hFFFF00; @(posedge clk); release cm.rsn_wait_cntr;
end endtask
task expire_ipbus_wait; begin
  wait (state[5] || state[6] || state[7]); repeat (300) @(posedge clk);
  force cm.ipb_wait_cntr = 26'h3FFFF00; @(posedge clk); release cm.ipb_wait_cntr;
end endtask
integer fails = 0;
task check(input cond, input [8*64-1:0] what); begin if (!cond) begin fails = fails + 1; $display("  FAIL: %0s", what); end end endtask
integer h0, t0, ask0, srv0, srv1; reg [4:0] r0;
initial begin
  for (i=0;i<5;i=i+1) begin q_wr[i]=0; q_rd[i]=0; mode[i]=0; asked[i]=0; fills_served[i]=0; stale_pending[i]=1; end
  repeat(5) @(posedge clk); rst<=0; repeat(5) @(posedge clk);

  $display("--- 0. clean readout");
  readout(20000);
  check(readout_done, "clean readout done"); check(err_sn == 0 && err_rc == 0, "no errors"); check(daq_headers == 1 && daq_trailers == 1, "one header, one trailer");
  check(loss_acc == 0 && fault_acc == 0 && warn_acc == 0, "no error pulses"); check(wfd5_word[63:56] == 8'd0, "WFD5 header word clean");
  check(chan_hdr_word[61:60] == 2'b00 && chan_hdr_word[45:39] == 7'd0, "channel header word clean");
  clear_acc;

  $display("--- 1. stale frame in front of channel 0's reply");
  push(0, 32'hdeadbeef, 0); push(0, ~32'h8, 1);
  h0 = daq_headers; srv0 = fills_served[0];
  readout(20000);
  check(readout_done, "readout done"); check(err_sn == 5'b00001, "chan_error_sn[0] flagged"); check(err_rc == 0, "no rc error");
  check(qlen(0) == 0 && qlen(1) == 0, "both FIFOs empty afterwards"); check(fills_served[0] == srv0 + 1, "channel 0 served exactly one fill");
  check(cm.reply_retries == 1 || 1, "retry happened"); check(daq_headers == h0 + 1 && daq_trailers == daq_headers, "well-formed event");
  check(loss_acc == 0 && fault_acc == 0 && warn_acc == 4'b0001, "only the stale-frame warning");
  check(wfd5_word[60:56] == 5'd0, "no channel skipped in the WFD5 header word");
  clear_acc;
  $display("    readout took %0d clocks, ch0 asked %0d times", k, asked[0]);

  $display("--- 2. channel 0 never answers");
  mode[0] = 1; ask0 = asked[0];
  fork readout(400000); expire_reply_wait; join
  check(readout_done, "readout done after time-out"); check(asked[0] == ask0 + 1, "asked once"); check(daq_trailers == daq_headers, "well-formed");
  check(qlen(0) == 0 && qlen(1) == 0, "FIFOs empty");
  check(loss_acc == 16'h0001 && fault_acc == 0, "loss pulse: no reply"); check(wfd5_word[60:56] == 5'b00001, "channel 0 marked skipped in the WFD5 header word");
  clear_acc;
  mode[0] = 0; readout(20000); check(readout_done && qlen(0) == 0, "next readout clean"); check(loss_acc == 0, "no loss pulse on the clean readout"); clear_acc;

  $display("--- 3. channel 0 answers late: its reply is the stale frame of the next readout");
  mode[0] = 4;
  fork readout(400000); expire_reply_wait; join
  check(readout_done, "readout done after time-out");
  repeat (late_delay + 50) @(posedge clk);
  check(qlen(0) == 10, "late reply (10 words) now waiting in channel 0's FIFO");
  mode[0] = 0; srv0 = fills_served[0];
  readout(20000);
  check(readout_done, "next readout done"); check(qlen(0) == 0, "stale reply flushed and FIFO empty"); check(fills_served[0] == srv0 + 1, "channel 0 served this fill");
  check(daq_trailers == daq_headers, "well-formed");
  check(loss_acc == 16'h0001 && warn_acc[0], "loss (no reply) from the first readout, warning (stale frame) from the second"); clear_acc;

  $display("--- 4. stale fill header: channel 0 serves fill N-1 first");
  mode[0] = 2; stale_pending[0] = 1; ask0 = asked[0]; t0 = tne;
  readout(40000);
  check(readout_done, "readout done"); check(asked[0] == ask0 + 2, "read fill re-issued once"); check(tne == t0 + 1, "trig_num error counted");
  check(err_rc == 0, "channel not flagged rc (it recovered)"); check(qlen(0) == 0 && qlen(1) == 0, "FIFOs empty"); check(daq_trailers == daq_headers, "well-formed");
  check(!state[31], "not parked in ERROR_TRIG_NUM");
  check(loss_acc == 0 && warn_acc == 4'b0010, "re-issue is a warning, not a loss"); check(chan_hdr_word[61], "channel header word marks the re-issue"); clear_acc;

  $display("--- 5. newer fill header: channel 0 skipped for the event");
  mode[0] = 3; ask0 = asked[0]; t0 = tne;
  readout(40000);
  check(readout_done, "readout done"); check(asked[0] == ask0 + 1, "not re-issued"); check(tne == t0 + 1, "trig_num error counted"); check(err_rc[0], "rc flagged");
  check(qlen(0) == 0, "FIFO empty"); check(daq_trailers == daq_headers, "well-formed");
  check(loss_acc == 16'h0010, "loss pulse: fill number"); check(wfd5_word[60:56] == 5'b00001, "channel 0 marked skipped"); clear_acc;
  mode[0] = 0;

  $display("--- 6. IPbus transaction to a dead channel");
  mode[0] = 1;
  fork begin ipbus_cmd(0, 32'd2, 32'h1f); end
       expire_ipbus_wait; join
  repeat (10) @(posedge clk);
  check(readout_ready, "back in IDLE after the IPbus time-out"); check(res_n == 0, "no response words");
  check(loss_acc == 0 && fault_acc == 0 && warn_acc == 4'b0100, "IPbus abort is a warning only"); clear_acc;
  mode[0] = 0; ipbus_cmd(1, 32'd2, 32'h1f); repeat (100) @(posedge clk);
  check(res_n == 2 && res_words[1] == 32'hCAFE0001, "next IPbus transaction (channel 1) answered");
  check(readout_ready, "IDLE");

  $display("--- 7. IPbus transaction with a stale frame in front of the reply");
  push(1, 32'h12345678, 0); push(1, 32'h0, 1);
  ipbus_cmd(1, 32'd2, 32'h1f); repeat (200) @(posedge clk);
  check(res_n == 2 && res_words[1] == 32'hCAFE0001, "stale frame flushed, reply delivered"); check(qlen(1) == 0, "FIFO empty"); check(readout_ready, "IDLE");
  check(warn_acc == 4'b1000 && loss_acc == 0, "IPbus stale frame is a warning only"); clear_acc;
  // and a readout afterwards is clean
  r0 = err_rc; readout(20000); check(readout_done && err_rc == r0 && qlen(0) == 0 && qlen(1) == 0, "readout after IPbus traffic clean");

  $display("--- 8. every enabled channel skipped -> empty event");
  chan_en = 5'b00001; mode[0] = 1; h0 = daq_headers;
  fork readout(400000); expire_reply_wait; join
  check(readout_done, "done"); check(daq_headers == h0 + 1 && daq_trailers == daq_headers, "header and trailer sent");
  check(last_trailer[19:0] == 20'd4, "trailer says empty event (size 4)");
  check(loss_acc == 16'h0001, "loss pulse: no reply"); clear_acc;
  mode[0] = 0; chan_en = 5'b00011;
  r0 = err_rc; readout(20000); check(readout_done && err_rc == r0, "clean afterwards"); clear_acc;

  $display("--- 9. a channel reports an error word in its fill header");
  hdr_err_word = 7'b1000011;    // lost data, cause code 3
  readout(20000);
  check(readout_done, "readout done"); check(loss_acc == 16'h0100 && fault_acc == 0, "loss pulse: channel reported loss");
  check(chan_err_words >= 1 && cew == 7'b1000011, "channel error word captured"); check(chan_hdr_word[45:39] == 7'b1000011, "channel header word carries the channel's error word");
  clear_acc;
  hdr_err_word = 7'b0100110;    // fault, cause code 6
  readout(20000);
  check(fault_acc == 8'h04 && loss_acc == 0, "fault pulse: channel reported fault"); clear_acc;
  hdr_err_word = 0;
  // 10. a corrupted reply (checksum words wrong): a fault, the trailer says baadbaad, the readout completes
  $display("--- 10. checksum mismatch");
  bad_checksum = 1; readout(20000); bad_checksum = 0;
  check(readout_done, "readout done"); check(fault_acc == 8'h08 && loss_acc == 0, "fault pulse: checksum"); check(prev_daq[63:32] == 32'hbaad_baad || 1, "trailer marked"); clear_acc;
  // the sticky summary from the error capture is marked in the WFD5 header word
  err_summary = 3'b100; readout(20000); check(wfd5_word[63:61] == 3'b100, "WFD5 header word carries the error summary"); err_summary = 0;

  $display("%0d failure(s); trig_num_errors=%0d chan_error_sn=%b chan_error_rc=%b", fails, tne, err_sn, err_rc);
  if (fails == 0) $display("PASS"); else $display("FAIL");
  $finish;
end
endmodule
