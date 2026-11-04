`timescale 1ns/1ps
// standard ttc_trigger_receiver (6.8.0): a trigger while the channels are still acquiring is
// answered with an empty event at once (not passed on, not delayed), counted, pulses empty_midrun,
// latches error_trig_rate; the receiver stays in service and the next trigger is passed normally.
module tb;
reg clk=0; always #12.5 clk=~clk; reg reset=1; reg trigger=0; reg acq_ready=1;
wire acq_trigger; wire [4:0] att; wire [23:0] atn; wire fv; wire [127:0] fd; wire [3:0] st; wire [23:0] tn; wire [43:0] ts;
wire [22:0] sb0,sb1,sb2,sb3,sb4; wire [31:0] ovc; wire af, er; wire [7:0] dg; wire em;
ttc_trigger_receiver ttr(.clk(clk),.reset(reset),.reset_trig_num(1'b0),.reset_trig_timestamp(1'b0),.trigger(trigger),.trig_type(5'b00001),
  .trig_settings(32'h2),.thres_ddr3_overflow(23'h7fffff),.chan_en(5'b00011),.pulse_trig_num(24'd0),.pulse_trigger(1'b0),.readout_done(1'b0),
  .readout_size_chan0(23'd0),.readout_size_chan1(23'd0),.readout_size_chan2(23'd0),.readout_size_chan3(23'd0),.readout_size_chan4(23'd0),
  .burst_count_chan0(23'd1),.burst_count_chan1(23'd1),.burst_count_chan2(23'd1),.burst_count_chan3(23'd1),.burst_count_chan4(23'd1),
  .wfm_count_chan0(12'd1),.wfm_count_chan1(12'd1),.wfm_count_chan2(12'd1),.wfm_count_chan3(12'd1),.wfm_count_chan4(12'd1),
  .acq_ready(acq_ready),.acq_activated(1'b1),.acq_trigger(acq_trigger),.acq_trig_type(att),.acq_trig_num(atn),
  .fifo_ready(1'b1),.fifo_valid(fv),.fifo_data(fd),.async_mode(1'b0),.cbuf_mode(1'b0),.cbuf_primed(1'b1),.accept_pulse_triggers(1'b0),.xadc_alarms(4'd0),
  .state(st),.trig_num(tn),.trig_timestamp(ts),.stored_bursts_chan0(sb0),.stored_bursts_chan1(sb1),.stored_bursts_chan2(sb2),.stored_bursts_chan3(sb3),.stored_bursts_chan4(sb4),
  .ddr3_overflow_count(ovc),.ddr3_almost_full(af),.error_trig_rate(er),.triggers_downgraded(dg),.empty_midrun(em));
integer nw=0, ne=0, np=0, nem=0; always @(posedge clk) begin if (fv) begin nw=nw+1; if (fd[97]) ne=ne+1; end if (acq_trigger) np=np+1; if (em) nem=nem+1; end
task trig; begin @(posedge clk); trigger<=1; @(posedge clk); trigger<=0; repeat(20) @(posedge clk); end endtask
integer fails=0;
initial begin
  repeat(5) @(posedge clk); reset<=0; repeat(5) @(posedge clk);
  trig; if (!(nw==1 && ne==0 && np==1 && !er)) begin fails=fails+1; $display("FAIL: normal trigger"); end
  acq_ready<=0; trig;
  if (!(nw==2 && ne==1 && np==1 && nem==1 && dg==1 && er && st[0])) begin fails=fails+1; $display("FAIL: busy trigger: nw=%0d ne=%0d np=%0d nem=%0d dg=%0d er=%0d st=%b", nw, ne, np, nem, dg, er, st); end
  acq_ready<=1; trig;
  if (!(nw==3 && ne==1 && np==2 && er)) begin fails=fails+1; $display("FAIL: trigger after"); end
  if (fails==0) $display("PASS"); else $display("FAIL");
  $finish;
end
endmodule
