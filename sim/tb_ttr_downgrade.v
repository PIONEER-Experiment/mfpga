`timescale 1ns/1ps
// A readout trigger downgraded in SEND_TRIGGER (the acquisition controller stayed busy past the bound)
// must reach the trigger FIFO marked empty.
module tb;
reg clk40=0; always #12.5 clk40=~clk40; reg reset=1;
reg ttc_trigger=0; reg acq_ready=0;
wire acq_trigger; wire [4:0] att; wire [23:0] atn; wire tf_valid; wire [127:0] tf_data; wire [3:0] st; wire [23:0] tn; wire [43:0] ts; wire er; wire [7:0] dg; wire em;
ttc_trigger_receiver_selftrigc ttr(.clk(clk40),.reset(reset),.reset_trig_num(1'b0),.reset_trig_timestamp(1'b0),
  .ttc_trigger(ttc_trigger),.trig_type(5'b00100),.acq_ready(acq_ready),.acq_activated(1'b1),
  .acq_trigger(acq_trigger),.acq_trig_type(att),.acq_trig_num(atn),.channel_acq_enabled(1'b1),
  .fifo_ready(1'b1),.fifo_valid(tf_valid),.fifo_data(tf_data),.xadc_alarms(4'd0),.state(st),.trig_num(tn),.trig_timestamp(ts),.error_trig_rate(er),.triggers_downgraded(dg),.run_active(1'b1),.empty_midrun(em));
reg seen=0, empty_bit=0, passed=0;
always @(posedge clk40) if (tf_valid) begin seen=1; empty_bit=tf_data[97]; end
always @(posedge clk40) if (acq_trigger) passed=1;
initial begin
  repeat(5) @(posedge clk40); reset<=0; repeat(5) @(posedge clk40);
  @(posedge clk40); ttc_trigger<=1; @(posedge clk40); ttc_trigger<=0;
  wait (st[1]); repeat (10) @(posedge clk40); force ttr.ready_wait_cntr = 17'h10000; @(posedge clk40); release ttr.ready_wait_cntr;
  repeat (20) @(posedge clk40);
  $display("written=%0d empty bit=%0d passed to the controller=%0d downgraded=%0d", seen, empty_bit, passed, dg);
  if (seen && empty_bit && !passed && dg == 1) $display("PASS"); else $display("FAIL");
  $finish;
end
endmodule
