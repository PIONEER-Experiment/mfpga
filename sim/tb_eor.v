`timescale 1ns/1ps
module tb;
reg clk40=0, clk125=0; always #12.5 clk40=~clk40; always #4 clk125=~clk125;
reg reset=1;
reg ttc_trigger=0; reg [4:0] trig_type=5'b00100;
reg accept=0, chan_acq_en=0;
wire acq_ready = 1'b1;
wire acq_activated, acq_trigger; wire [4:0] acq_trig_type; wire [23:0] acq_trig_num;
wire tf_valid; wire [127:0] tf_data; reg tf_ready=1;
wire [3:0] ttr_state; wire [23:0] trig_num; wire [43:0] trig_ts; wire err_rate;
ttc_trigger_receiver_selftrigc ttr(.clk(clk40),.reset(reset),.reset_trig_num(1'b0),.reset_trig_timestamp(1'b0),
  .ttc_trigger(ttc_trigger),.trig_type(trig_type),.acq_ready(acq_ready),.acq_activated(acq_activated),
  .acq_trigger(acq_trigger),.acq_trig_type(acq_trig_type),.acq_trig_num(acq_trig_num),.channel_acq_enabled(chan_acq_en),
  .fifo_ready(tf_ready),.fifo_valid(tf_valid),.fifo_data(tf_data),.xadc_alarms(4'd0),.state(ttr_state),.trig_num(trig_num),.trig_timestamp(trig_ts),.error_trig_rate(err_rate),.triggers_downgraded(downgraded),.run_active(accept),.empty_midrun(empty_midrun));
wire [7:0] downgraded; wire empty_midrun, cac_gave_up;
integer n_empty_midrun = 0; always @(posedge clk40) if (empty_midrun) n_empty_midrun = n_empty_midrun + 1;
integer n_gave_up = 0; always @(posedge clk40) if (cac_gave_up) n_gave_up = n_gave_up + 1;
wire nfpt, stf_wr, cac_ready; wire [4:0] acq_enable; wire af_valid; wire [31:0] af_data; reg af_ready=1; wire [5:0] cac_state;
channel_acq_controller_selftrigc cac(.clk(clk40),.reset(reset),.chan_en(5'b00011),.accept_self_triggers(accept),
  .new_fill_pause_triggers(nfpt),.ttc_trigger(acq_trigger),.ttc_trig_type(acq_trig_type),.ttc_trig_num(acq_trig_num),
  .ttc_acq_ready(cac_ready),.ttc_acq_activated(acq_activated),.acq_dones(5'b11111),.acq_enable(acq_enable),
  .fifo_ready(af_ready),.fifo_valid(af_valid),.fifo_data(af_data),.state(cac_state),.wait_gave_up(cac_gave_up));
// FIFO models (40 MHz write, 125 MHz read)
reg [102:0] tq [0:63]; integer tw=0, tr=0;
reg [28:0]  aq [0:63]; integer aw=0, ar=0;
always @(posedge clk40) begin if (tf_valid && tf_ready) begin tq[tw]=tf_data[102:0]; tw=tw+1; end
                              if (af_valid && af_ready) begin aq[aw]=af_data[28:0]; aw=aw+1; end end
wire tfv = (tr<tw); wire afv = (ar<aw); wire tfr, afr; wire send_empty, skip, initiate; wire [6:0] tp_state; wire etn, ett;
wire [23:0] ev_num, ttc_tn; wire [4:0] ttc_tt; wire [43:0] ttc_ts; wire [3:0] xa;
reg readout_done=0; reg [5:0] rd_cnt=0; integer n_readouts=0, n_empty=0;
trigger_processor tp(.clk(clk125),.reset(reset),.trig_fifo_valid(tfv),.trig_fifo_data(tq[tr]),.trig_fifo_ready(tfr),
  .acq_fifo_valid(afv),.acq_fifo_data(aq[ar]),.acq_fifo_ready(afr),.readout_ready(1'b1),.readout_done(readout_done),
  .send_empty_event(send_empty),.skip_payload(skip),.initiate_readout(initiate),.ttc_event_num(ev_num),.ttc_trig_num(ttc_tn),.ttc_trig_type(ttc_tt),.ttc_trig_timestamp(ttc_ts),.ttc_xadc_alarms(xa),.state(tp_state),.error_trig_num(etn),.error_trig_type(ett));
always @(posedge clk125) begin
  if (tfr) tr=tr+1; if (afr) ar=ar+1;
  readout_done<=0;
  if (initiate) begin rd_cnt<=20; n_readouts=n_readouts+1; if (send_empty) n_empty=n_empty+1; $display("%0t readout trig %0d empty=%0d", $time, ttc_tn, send_empty); end
  else if (rd_cnt>1) rd_cnt<=rd_cnt-1; else if (rd_cnt==1) begin rd_cnt<=0; readout_done<=1; end
end
task trig; begin @(posedge clk40); ttc_trigger<=1; @(posedge clk40); ttc_trigger<=0; repeat(200) @(posedge clk40); end endtask
initial begin
  repeat(5) @(posedge clk40); reset<=0; repeat(5) @(posedge clk40);
  accept<=1; chan_acq_en<=1; repeat(5) @(posedge clk40);
  trig; trig;                         // two normal triggers
  // a trigger arriving while the controller is still flushing the previous one (3 TTC clocks later)
  @(posedge clk40); ttc_trigger<=1; @(posedge clk40); ttc_trigger<=0; repeat(3) @(posedge clk40);
  ttc_trigger<=1; @(posedge clk40); ttc_trigger<=0; repeat(400) @(posedge clk40);
  $display("after back-to-back triggers: ttr state %b (0001=IDLE, 1000=ERROR) downgraded=%0d empty_midrun pulses=%0d", ttr_state, downgraded, n_empty_midrun);
  if (n_empty_midrun != 1) $display("FAIL: the mid-run empty event should raise exactly one empty_midrun pulse");
  accept<=0; $display("--- FC7 stop (accept_self_triggers=0), acquisition still enabled (TRIG_ACQ_GAP)");
  trig;                               // first trigger after the stop: real readout
  $display("cac state after first post-stop trigger: %b  acq_activated=%0d", cac_state, acq_activated);
  trig;                               // FC7 final async trigger
  trig;                               // and one more for good measure
  chan_acq_en<=0; repeat(50) @(posedge clk40);
  $display("tp state %b (0000001=IDLE)  readouts=%0d empty=%0d  err_trig_num=%0d  trig fifo unread=%0d acq fifo unread=%0d", tp_state, n_readouts, n_empty, etn, tw-tr, aw-ar);
  $display("empty_midrun pulses %0d (the two post-stop empty events must not count), controller gave up %0d", n_empty_midrun, n_gave_up);
  if (tp_state==7'b0000001 && n_readouts==7 && !etn && ttr_state==4'b0001 && n_empty_midrun==1 && n_gave_up==0) $display("PASS"); else $display("FAIL");
  $finish;
end
endmodule
