`timescale 1ns/1ps
// command_manager (standard image, 6.8.0): the readout hardening ported from the self-triggering
// image.  Channel RX FIFOs are modelled per channel, each with a queue of fills; channel 1 always
// answers correctly; channel 0 is put through the fault modes below.  Every readout must complete
// (readout_done), the DAQ stream must be well formed (every header has a trailer), the words sent
// must match the size in the header unless a channel was skipped (then a data-loss pulse must have
// been raised), and the channel must be back in step afterwards.
//   0. clean readout (sync, muon fill type)
//   1. a stale frame in front of a live channel's reply: flushed, retried, the channel's fill is read
//   2. a channel that never answers: time-out, skipped, a loss pulse; the next readout is clean
//   3. a channel that answers late: its reply is the stale frame of the next readout
//   4. a stale fill (the channel holds fill N-1 in front of N): terminal (ERROR_TRIG_NUM), loss pulse
//   5. a newer fill (N+1): terminal as well; after a reset the readout works again
//   6. an IPbus transaction to a dead channel: time-out, back to IDLE; the next one works
//   7. an IPbus transaction with a stale frame in front of the reply: flushed and retried
//   8. every enabled channel skipped: a well-formed empty event
//   9. checksum mismatch: a fault
//  10. trigger type mismatch: the channel is skipped, not fatal
//  11. async mode, the second channel skipped: the pulse records stored for it are drained before
//      the next readout, which is clean
//  13. a channel whose fill header carries a waveform or burst count other than the configured one (the
//      event size was computed from the configuration): a size-mismatch loss pulse
//  12. a channel that stops streaming mid-fill: ERROR_DATA_CORRUPTION and a fault (terminal, last)
module tb;
reg clk=0; always #4 clk=~clk; reg rst=1;
wire tx_valid, tx_last; wire [3:0] tx_dest; wire [31:0] tx_data;
integer tx_widx = 0; reg [31:0] tx_csn, tx_cc;
reg [32:0] q [0:5*4096-1]; integer q_wr [0:4], q_rd [0:4];
integer sel; always @* sel = (tx_dest < 5) ? tx_dest : 0;
reg rx_valid, rx_last; reg [31:0] rx_data;
always @* begin rx_valid = (tx_dest < 5) && (q_rd[sel] != q_wr[sel]); rx_last = rx_valid ? q[sel*4096 + (q_rd[sel] & 4095)][32] : 1'b0; rx_data = rx_valid ? q[sel*4096 + (q_rd[sel] & 4095)][31:0] : 32'd0; end
wire rx_ready;
reg stall_after = 0; integer stall_at = -1;   // scenario 12: stop the channel 0 stream after 'stall_at' words
integer words_out0 = 0;
always @(posedge clk) if (rx_valid && rx_ready) begin q_rd[sel] = q_rd[sel] + 1; if (sel == 0) words_out0 = words_out0 + 1; end
task push(input integer ch, input [31:0] d, input l); begin q[ch*4096 + (q_wr[ch] & 4095)] = {l, d}; q_wr[ch] = q_wr[ch] + 1; end endtask
function integer qlen(input integer ch); qlen = q_wr[ch] - q_rd[ch]; endfunction
// IPbus model
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
// DAQ stream
wire daq_valid, daq_header, daq_trailer; wire [63:0] daq_data;
integer daq_headers = 0, daq_trailers = 0, ev_words = 0; reg [63:0] last_trailer, last_header;
always @(posedge clk) begin
  if (daq_valid) ev_words = ev_words + 1;
  if (daq_valid && daq_header) begin daq_headers = daq_headers + 1; last_header = daq_data; ev_words = 1; end
  if (daq_valid && daq_trailer) begin daq_trailers = daq_trailers + 1; last_trailer = daq_data; end
end
// pulse trigger FIFO (async mode): one record per front panel trigger
reg [127:0] pq [0:255]; integer pq_wr = 0, pq_rd = 0; wire pulse_tready;
wire pulse_tvalid = (pq_wr != pq_rd); wire [127:0] pulse_tdata = pq[pq_rd & 255];
always @(posedge clk) if (pulse_tvalid && pulse_tready) pq_rd = pq_rd + 1;
// DUT
reg initiate_readout=0; reg [23:0] event_num = 24'd7; reg [4:0] chan_en = 5'b00011; reg [4:0] trig_type = 5'b00001;
reg async_mode = 0; reg [23:0] total_fp = 24'd0;
wire readout_ready, readout_done, async_done, dfp; wire [21:0] mgc; wire [34+1:0] state; wire [4:0] err_sn, err_rc; wire err_data, err_tn, err_tt; wire [31:0] csmm;
wire [22:0] rs0, rs1, rs2, rs3, rs4, bc0, bc1, bc2, bc3, bc4; wire [11:0] wc0, wc1, wc2, wc3, wc4;
wire [15:0] lossp; wire [7:0] faultp; wire [5:0] warnp; wire [31:0] lrsn, lrc, li1, li4; wire [8:0] rstat; wire [7:0] tne;
command_manager cm(.clk(clk),.rst(rst),.chan_tx_fifo_ready(1'b1),.chan_tx_fifo_valid(tx_valid),.chan_tx_fifo_last(tx_last),.chan_tx_fifo_dest(tx_dest),.chan_tx_fifo_data(tx_data),
  .chan_rx_fifo_valid(rx_valid),.chan_rx_fifo_last(rx_last),.chan_rx_fifo_data(rx_data),.chan_rx_fifo_ready(rx_ready),
  .ipbus_cmd_valid(ipb_valid),.ipbus_cmd_last(ipb_last),.ipbus_cmd_dest(ipb_dest),.ipbus_cmd_data(ipb_data),.ipbus_cmd_ready(ipb_ready),.ipbus_res_ready(1'b1),.ipbus_res_valid(ipb_res_valid),.ipbus_res_last(ipb_res_last),.ipbus_res_data(ipb_res_data),
  .daq_ready(1'b1),.daq_almost_full(1'b0),.daq_valid(daq_valid),.daq_header(daq_header),.daq_trailer(daq_trailer),.daq_data(daq_data),
  .send_empty_event(1'b0),.skip_payload(1'b0),.initiate_readout(initiate_readout),.event_num(event_num),.trig_num(event_num),.trig_type(trig_type),.trig_timestamp(44'd0),.ttc_xadc_alarms(4'd0),
  .curr_trig_type(trig_type),.readout_ready(readout_ready),.readout_done(readout_done),.async_readout_done(async_done),.double_fp_triggers(dfp),.muon_gap_count(mgc),
  .readout_size_chan0(rs0),.readout_size_chan1(rs1),.readout_size_chan2(rs2),.readout_size_chan3(rs3),.readout_size_chan4(rs4),
  .burst_count_chan0(bc0),.burst_count_chan1(bc1),.burst_count_chan2(bc2),.burst_count_chan3(bc3),.burst_count_chan4(bc4),
  .wfm_count_chan0(wc0),.wfm_count_chan1(wc1),.wfm_count_chan2(wc2),.wfm_count_chan3(wc3),.wfm_count_chan4(wc4),
  .total_fp_triggers(total_fp),.pulse_fifo_tvalid(pulse_tvalid),.pulse_fifo_tdata(pulse_tdata),.pulse_fifo_tready(pulse_tready),
  .i2c_mac_adr(16'h0101),.chan_en(chan_en),.endianness_sel(1'b0),.thres_data_corrupt(32'hFFFFFFFF),.async_mode(async_mode),.cbuf_mode(1'b0),.state(state),
  .cs_mismatch_count(csmm),.error_data_corrupt(err_data),.error_trig_num(err_tn),.error_trig_type(err_tt),.chan_error_sn(err_sn),.chan_error_rc(err_rc),
  .trig_num_error_count(tne),.err_loss_pulse(lossp),.err_fault_pulse(faultp),.err_warn_pulse(warnp),
  .last_rsn_word(lrsn),.last_rc_word(lrc),.last_info1_word(li1),.last_info4_word(li4),.retry_status(rstat));
reg [15:0] loss_acc = 0; reg [7:0] fault_acc = 0; reg [5:0] warn_acc = 0; reg clr = 0;
always @(posedge clk) begin loss_acc <= clr ? lossp : (loss_acc | lossp); fault_acc <= clr ? faultp : (fault_acc | faultp); warn_acc <= clr ? warnp : (warn_acc | warnp); end
task clear_acc; begin @(posedge clk); clr <= 1; @(posedge clk); clr <= 0; @(posedge clk); end endtask
// ---- channel model.  Each channel holds a queue of fills (fill number); read fill (CC 0x8) pops the
// head and streams it.  mode: 0 correct (a fill for the current event is queued when asked, if none
// is), 1 silent, 2 holds a stale fill (N-1) in front of N, 3 holds a newer fill (N+1), 4 late,
// 5 wrong trigger type in the header
integer BC = 2, WF = 2;          // burst count and waveforms per fill (configured to match below)
integer WF_CH0 = -1;             // scenario 13: channel 0 sends this waveform count instead of WF
integer mode [0:4]; integer late_delay = 400; integer asked [0:4]; integer fills_served [0:4];
reg [23:0] hq_num [0:4][0:15]; integer hq_rd [0:4], hq_wr [0:4];
task hq_push(input integer ch, input [23:0] num); begin hq_num[ch][hq_wr[ch] & 15] = num; hq_wr[ch] = hq_wr[ch] + 1; end endtask
function integer hq_len(input integer ch); hq_len = hq_wr[ch] - hq_rd[ch]; endfunction
integer late_cnt = 0; reg [31:0] late_csn, late_cc; integer late_ch;
always @(posedge clk) if (late_cnt > 0) begin late_cnt = late_cnt - 1; if (late_cnt == 0) serve(late_ch, late_csn, late_cc); end
reg bad_checksum = 0; reg [2:0] hdr_type_override = 3'd0; reg type_override = 0;
reg [127:0] cs; integer wi, di; reg [31:0] dw, h1, h2, h3, h4;
task fill_reply(input integer ch, input [31:0] csn, input [23:0] num); begin
  if (!async_mode) begin
    h1 = {BC[4:0], (type_override ? hdr_type_override : trig_type[2:0]), num};
    h2 = {14'd0, BC[22:5]};
    h3 = {8'd0, ((ch == 0 && WF_CH0 >= 0) ? WF_CH0[11:0] : WF[11:0]), 12'd0};
    h4 = {6'd0, 12'h0A0 + ch, 14'd0};
  end else begin
    h1 = {BC[4:0], 3'b111, num};
    h2 = {BC[13:0], 18'd0};
    h3 = {WF[19:0], 12'd0};
    h4 = {6'd0, 12'h0A0 + ch, 11'd0, WF[22:20]};
  end
  push(ch, csn, 0); push(ch, 32'h8, 0); push(ch, h1, 0); push(ch, h2, 0); push(ch, h3, 0); push(ch, h4, 0);
  cs = {h4, h3, h2, h1};
  for (wi = 0; wi < ((ch == 0 && WF_CH0 >= 0 && !async_mode) ? WF_CH0 : WF); wi = wi + 1) for (di = 0; di < (BC + 1) * 4; di = di + 1) begin
    dw = 32'hA0000000 + ch * 32'h01000000 + wi * 32'h10000 + di; push(ch, dw, 0); cs[(di % 4) * 32 +: 32] = cs[(di % 4) * 32 +: 32] ^ dw;
  end
  push(ch, cs[31:0] ^ {31'd0, bad_checksum}, 0); push(ch, cs[63:32], 0); push(ch, cs[95:64], 0); push(ch, cs[127:96], 1);
  fills_served[ch] = fills_served[ch] + 1;
end endtask
task ipbus_reply(input integer ch, input [31:0] csn, input [31:0] cc); begin
  push(ch, csn, 0); push(ch, cc, 0); push(ch, 32'hCAFE0000 + ch, 1);
end endtask
task serve(input integer ch, input [31:0] csn, input [31:0] cc); begin
  if (cc == 32'h8) begin
    if (hq_len(ch) == 0) begin
      case (mode[ch]) 2: begin hq_push(ch, event_num - 1); hq_push(ch, event_num); end
                      3: hq_push(ch, event_num + 1);
                      default: hq_push(ch, event_num); endcase
    end
    fill_reply(ch, csn, hq_num[ch][hq_rd[ch] & 15]); hq_rd[ch] = hq_rd[ch] + 1;
  end
  else ipbus_reply(ch, csn, cc);
end endtask
task respond(input integer ch, input [31:0] csn, input [31:0] cc); begin
  asked[ch] = asked[ch] + 1;
  case (mode[ch]) 1: ; 4: begin late_ch = ch; late_csn = csn; late_cc = cc; late_cnt = late_delay; end
                  default: serve(ch, csn, cc); endcase
end endtask
always @(posedge clk) if (tx_valid) begin
  if (tx_widx == 0) tx_csn = tx_data; else tx_cc = tx_data;
  if (tx_last) begin respond(tx_dest, tx_csn, (tx_widx == 0) ? 32'd0 : tx_cc); tx_widx = 0; end else tx_widx = tx_widx + 1;
end
function [19:0] exp_size(input integer nchan); exp_size = ((BC * 2 + 2) * WF + 5) * nchan + 4; endfunction
integer k, i;
task readout(input integer max_clocks); begin
  event_num = event_num + 1;
  @(posedge clk); initiate_readout <= 1; @(posedge clk); initiate_readout <= 0;
  k = 0; while (!readout_done && k < max_clocks) begin @(posedge clk); k = k + 1; end
  if (!readout_done) $display("  readout %0d NOT DONE after %0d clocks: state=%h dest=%0d q0=%0d q1=%0d", event_num, k, state, tx_dest, qlen(0), qlen(1));
end endtask
task expire_reply_wait; begin
  wait (state[11] || state[12] || state[13]); repeat (300) @(posedge clk);
  force cm.rsn_wait_cntr = 30'h3FFFFF00; @(posedge clk); release cm.rsn_wait_cntr;
end endtask
task expire_ipbus_wait; begin
  wait (state[5] || state[6] || state[7]); repeat (300) @(posedge clk);
  force cm.ipb_wait_cntr = 26'h3FFFF00; @(posedge clk); release cm.ipb_wait_cntr;
end endtask
integer fails = 0;
task check(input cond, input [8*72-1:0] what); begin if (!cond) begin fails = fails + 1; $display("  FAIL: %0s", what); end end endtask
integer h0, ask0, srv0; reg [4:0] r0; integer t0;
task configure; begin
  @(negedge clk); for (i=0;i<5;i=i+1) begin cm.chan_burst_count_type1[i] = BC; cm.chan_wfm_count_type1[i] = WF; cm.chan_burst_count_type4[i] = BC; end
  @(posedge clk);
end endtask
task reset_dut; begin
  @(posedge clk); rst <= 1; repeat (5) @(posedge clk); rst <= 0; repeat (5) @(posedge clk);
  for (i=0;i<5;i=i+1) begin q_rd[i] = q_wr[i]; hq_rd[i] = hq_wr[i]; end
  configure;
end endtask
initial begin
  for (i=0;i<5;i=i+1) begin q_wr[i]=0; q_rd[i]=0; mode[i]=0; asked[i]=0; fills_served[i]=0; hq_rd[i]=0; hq_wr[i]=0; end
  repeat(5) @(posedge clk); rst<=0; repeat(5) @(posedge clk);
  // configure the sizes the event-size logic uses (as the IPbus writes of registers 0x02 / 0x0e would)
  configure;

  $display("--- 0. clean readout");
  readout(20000);
  check(readout_done, "clean readout done"); check(err_sn == 0 && err_rc == 0, "no errors"); check(daq_headers == 1 && daq_trailers == 1, "one header, one trailer");
  check(loss_acc == 0 && fault_acc == 0 && warn_acc == 0, "no error pulses");
  check(last_header[19:0] == exp_size(2) && ev_words == exp_size(2), "event size, and the words sent match it");
  check(qlen(0) == 0 && qlen(1) == 0 && fills_served[0] == 1 && fills_served[1] == 1, "each channel read once, FIFOs empty");
  clear_acc;

  $display("--- 1. stale frame in front of channel 0's reply");
  push(0, 32'hdeadbeef, 0); push(0, 32'h12345678, 1);
  h0 = daq_headers; srv0 = fills_served[0];
  readout(20000);
  check(readout_done, "readout done"); check(err_sn == 5'b00001, "chan_error_sn[0] flagged"); check(qlen(0) == 0 && qlen(1) == 0, "FIFOs empty");
  check(fills_served[0] == srv0 + 1, "channel 0 served exactly one fill"); check(daq_headers == h0 + 1 && daq_trailers == daq_headers, "well-formed");
  check(loss_acc == 0 && fault_acc == 0 && warn_acc == 6'b000001, "only the stale-frame warning");
  check(ev_words == exp_size(2), "event complete"); clear_acc;

  $display("--- 2. channel 0 never answers");
  mode[0] = 1; ask0 = asked[0];
  fork readout(400000); expire_reply_wait; join
  check(readout_done, "readout done after time-out"); check(asked[0] == ask0 + 1, "asked once"); check(daq_trailers == daq_headers, "well-formed");
  check(loss_acc == 16'h0001 && fault_acc == 0, "loss pulse: no reply"); check(ev_words == exp_size(2) - exp_size(1) + 4, "channel 1's data only (the event is short: the loss says so)");
  clear_acc;
  mode[0] = 0; readout(20000); check(readout_done && qlen(0) == 0 && loss_acc == 0 && ev_words == exp_size(2), "next readout clean"); clear_acc;

  $display("--- 3. channel 0 answers late: its reply is the stale frame of the next readout");
  mode[0] = 4;
  fork readout(400000); expire_reply_wait; join
  check(readout_done, "readout done after time-out");
  repeat (late_delay + 50) @(posedge clk);
  check(qlen(0) > 6, "the late reply is waiting in channel 0's FIFO");
  mode[0] = 0; srv0 = fills_served[0];
  readout(40000);
  check(readout_done, "next readout done"); check(qlen(0) == 0, "stale reply flushed, FIFO empty");
  check(loss_acc == 16'h0001 && warn_acc[0], "loss (no reply) from the first readout, warning (stale frame) from the second");
  check(ev_words == exp_size(2), "the second event is complete"); clear_acc;
  // the late reply carried the previous event's fill: it was the stale frame, and this event's fill was read
  hq_rd[0] = hq_wr[0];

  $display("--- 4. stale fill: channel 0 holds fill N-1 in front of N -> terminal");
  mode[0] = 2; t0 = tne;
  readout(20000);
  check(!readout_done, "the readout does not complete"); check(cm.state[33], "stopped in ERROR_TRIG_NUM"); check(err_tn, "error_trig_num");
  check(loss_acc == 16'h0010, "loss pulse: fill number (-> TTS sync-lost through the error capture)"); check(tne == t0 + 1, "counted");
  repeat (2000) @(posedge clk); check(cm.state[33], "still there 2000 clocks later");
  mode[0] = 0; reset_dut; clear_acc;
  readout(20000); check(readout_done && ev_words == exp_size(2) && loss_acc == 0, "after a reset the readout works again"); clear_acc;

  $display("--- 5. newer fill: channel 0 holds fill N+1 -> terminal");
  mode[0] = 3;
  readout(20000);
  check(!readout_done && cm.state[33] && err_tn && loss_acc == 16'h0010, "stopped in ERROR_TRIG_NUM with the fill-number loss");
  mode[0] = 0; reset_dut; clear_acc;
  readout(20000); check(readout_done && ev_words == exp_size(2) && loss_acc == 0, "clean after the reset"); clear_acc;

  $display("--- 6. IPbus transaction to a dead channel");
  mode[0] = 1;
  fork begin ipbus_cmd(0, 32'd2, 32'h1f); end expire_ipbus_wait; join
  repeat (10) @(posedge clk);
  check(readout_ready, "back in IDLE after the IPbus time-out"); check(res_n == 0, "no response words");
  check(loss_acc == 0 && fault_acc == 0 && warn_acc == 6'b000100, "IPbus abort is a warning only"); clear_acc;
  mode[0] = 0; ipbus_cmd(1, 32'd2, 32'h1f); repeat (100) @(posedge clk);
  check(res_n == 2 && res_words[1] == 32'hCAFE0001, "next IPbus transaction (channel 1) answered");

  $display("--- 7. IPbus transaction with a stale frame in front of the reply");
  push(1, 32'h12345678, 0); push(1, 32'h0, 1);
  ipbus_cmd(1, 32'd2, 32'h1f); repeat (200) @(posedge clk);
  check(res_n == 2 && res_words[1] == 32'hCAFE0001, "stale frame flushed, reply delivered"); check(qlen(1) == 0, "FIFO empty"); check(readout_ready, "IDLE");
  check(warn_acc == 6'b001000 && loss_acc == 0, "IPbus stale frame is a warning only"); clear_acc;
  r0 = err_rc; readout(20000); check(readout_done && qlen(0) == 0 && qlen(1) == 0 && ev_words == exp_size(2), "readout after IPbus traffic clean"); clear_acc;

  $display("--- 8. every enabled channel skipped -> empty event");
  chan_en = 5'b00001; mode[0] = 1; h0 = daq_headers;
  fork readout(400000); expire_reply_wait; join
  check(readout_done, "done"); check(daq_headers == h0 + 1 && daq_trailers == daq_headers, "header and trailer sent");
  check(last_trailer[19:0] == 20'd4 && last_header[19:0] == 20'd4 && ev_words == 4, "header and trailer say empty event (size 4)");
  check(loss_acc == 16'h0001, "loss pulse: no reply"); clear_acc;
  mode[0] = 0; chan_en = 5'b00011;
  readout(20000); check(readout_done && ev_words == exp_size(2), "clean afterwards"); clear_acc;

  $display("--- 9. checksum mismatch");
  t0 = csmm; bad_checksum = 1; readout(20000); bad_checksum = 0;
  check(readout_done, "readout done"); check(fault_acc == 8'h08 && loss_acc == 0, "fault pulse: checksum"); check(csmm == t0 + 2, "mismatch counted (both channels sent a bad checksum)"); $display("    csmm %0d -> %0d", t0, csmm); clear_acc;

  $display("--- 10. trigger type mismatch");
  type_override = 1; hdr_type_override = 3'd2; readout(20000); type_override = 0;
  check(readout_done, "readout done"); check(loss_acc == 16'h0020, "loss pulse: fill type");
  repeat (5) @(posedge clk); check(err_tt, "error_trig_type flagged (sticky)"); check(cm.state[0], "back in IDLE"); check(qlen(0) == 0 && qlen(1) == 0, "FIFOs empty"); clear_acc;
  readout(20000); check(readout_done && loss_acc == 0 && ev_words == exp_size(2), "clean afterwards"); clear_acc;

  $display("--- 11. async mode: channel 1 skipped, its pulse records drained");
  async_mode = 1; trig_type = 5'b00100; WF = 3; total_fp = 3;
  for (i = 0; i < 3; i = i + 1) begin pq[pq_wr & 255] = {58'd0, 2'b01, 24'd0, 44'h100 + i}; pq_wr = pq_wr + 1; end
  mode[1] = 1;
  fork readout(400000); begin wait (cm.state[11] && tx_dest == 1); repeat (300) @(posedge clk); force cm.rsn_wait_cntr = 30'h3FFFFF00; @(posedge clk); release cm.rsn_wait_cntr; end join
  check(readout_done, "async readout done"); check(pq_rd == pq_wr, "channel 0 took the three pulse records"); check(loss_acc == 16'h0001, "loss pulse: channel 1 no reply");
  repeat (20) @(posedge clk);
  check(cm.m_readout_fifo_tvalid == 0, "the records stored for channel 1 were drained in IDLE"); clear_acc;
  mode[1] = 0; hq_rd[1] = hq_wr[1];
  for (i = 0; i < 3; i = i + 1) begin pq[pq_wr & 255] = {58'd0, 2'b01, 24'd0, 44'h200 + i}; pq_wr = pq_wr + 1; end
  readout(40000);
  check(readout_done && loss_acc == 0 && fault_acc == 0, "next async readout clean"); check(pq_rd == pq_wr && cm.m_readout_fifo_tvalid == 0, "pulse records consumed by both channels");
  check(qlen(0) == 0 && qlen(1) == 0, "FIFOs empty"); clear_acc;
  async_mode = 0; trig_type = 5'b00001; WF = 2; total_fp = 0;

  $display("--- 13. channel 0's fill does not have the configured shape");
  WF_CH0 = 3; readout(20000); WF_CH0 = -1;
  check(readout_done, "readout done"); check(loss_acc == 16'h0080, "loss pulse: size mismatch"); check(qlen(0) == 0 && qlen(1) == 0, "FIFOs empty"); clear_acc;
  readout(20000); check(readout_done && loss_acc == 0 && ev_words == exp_size(2), "clean afterwards (and no false size-mismatch in any earlier scenario)"); clear_acc;

  $display("--- 12. channel 0 stops streaming mid-fill");
  // let the channel answer, then remove the end of its fill from the queue
  fork readout(60000);
    begin wait (cm.state[23]); q_wr[0] = q_rd[0] + 3; repeat (500) @(posedge clk); force cm.data_wait_cntr = 25'h1FFFF00; @(posedge clk); release cm.data_wait_cntr; end
  join
  repeat (10) @(posedge clk);
  check(cm.state[32], "ERROR_DATA_CORRUPTION"); check(err_data, "error_data_corrupt"); check(fault_acc == 8'h01, "fault pulse: data stall");

  $display("%0d failure(s); trig_num_errors=%0d chan_error_sn=%b chan_error_rc=%b", fails, tne, err_sn, err_rc);
  if (fails == 0) $display("PASS"); else $display("FAIL");
  $finish;
end
endmodule
