`timescale 1ns/1ps
// standard channel_acq_controller (6.8.0): FILL is bounded; on the time-out the event is stored and
// wait_gave_up pulses once; a normal fill (all dones) does not pulse it.
module tb;
reg clk=0; always #12.5 clk=~clk; reg reset=1; reg trigger=0; reg [4:0] dones=5'b00000;
wire ready, fv; wire [9:0] en; wire [4:0] at; wire [31:0] fd; wire [3:0] st; wire gu;
channel_acq_controller cac(.clk(clk),.reset(reset),.chan_en(5'b00011),.trig_delay(32'd0),.trigger(trigger),.trig_type(5'b00001),.trig_num(24'd5),
  .acq_ready(ready),.acq_dones(dones),.acq_enable(en),.acq_trig(at),.fifo_ready(1'b1),.fifo_valid(fv),.fifo_data(fd),.async_mode(1'b0),.cbuf_mode(1'b0),.state(st),.wait_gave_up(gu));
integer ng=0, nf=0; always @(posedge clk) begin if (gu) ng=ng+1; if (fv) nf=nf+1; end
integer fails=0;
initial begin
  repeat(5) @(posedge clk); reset<=0; repeat(5) @(posedge clk);
  @(posedge clk); trigger<=1; @(posedge clk); trigger<=0; repeat(10) @(posedge clk); dones<=5'b00011; repeat(10) @(posedge clk); dones<=0;
  if (!(nf==1 && ng==0 && st[0])) begin fails=fails+1; $display("FAIL normal"); end
  @(posedge clk); trigger<=1; @(posedge clk); trigger<=0; repeat(10) @(posedge clk); dones<=5'b00001;
  repeat(100) @(posedge clk); if (!st[2]) begin fails=fails+1; $display("FAIL: not waiting in FILL"); end
  force cac.wait_cntr = 24'h800000; @(posedge clk); release cac.wait_cntr; repeat(10) @(posedge clk);
  if (!(nf==2 && ng==1 && st[0])) begin fails=fails+1; $display("FAIL timeout nf=%0d ng=%0d st=%b", nf, ng, st); end
  if (fails==0) $display("PASS"); else $display("FAIL"); $finish;
end
endmodule
