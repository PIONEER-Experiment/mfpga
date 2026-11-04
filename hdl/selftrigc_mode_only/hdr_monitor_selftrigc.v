// Per-channel fill-size monitor from the fill headers (6.8.0).
//
// Until 6.7.x the master counted each channel's trigger-line pulses (channel_triggerc_receiver):
// a running total per channel (status registers 29-33), the bursts stored in the open fill
// (status registers 21-25), and the DDR3 overflow warning to the TTS (OFW) when one channel's
// open fill passed the IPbus threshold.  The trigger line is gone, and every one of those numbers
// is now taken from the fill headers the command manager sees:
//
//   wfms_read[ch]   waveforms read out of channel ch since the last reset or TTC event-number
//                   reset (one count per header read with its fill: the waveforms actually sent
//                   to the DAQ).  24 bits, wraps.  Status registers 29-33, as before.
//   fill_bursts[ch] the bursts in the most recent fill peeked from channel ch:
//                   waveforms * (burst_count + 1), saturating at 2^23-1.  Status registers 21-25.
//   ddr3_almost_full  any enabled channel's fill_bursts above 'thres_ddr3_overflow'.  Evaluated
//                   at every peek and held until the next one (or 'clear'), so it now comes one
//                   fill late: it says "the fill just read was over the threshold", not "the fill
//                   being written is".  The channel itself bounds a fill (trigger-FIFO
//                   back-pressure, error latch), so this is a warning, as it always was.
//
// clk125 domain throughout (the command manager's).

module hdr_monitor_selftrigc (
  input  wire         clk,
  input  wire         rst,                 // rst_from_ipb
  input  wire         reset_totals,        // TTC event-number reset (synchronised), clears wfms_read
  input  wire         clear,               // end of run (acq_encode2 clear_trigger_counts): clears fill_bursts and the warning
  input  wire         hdr_peek_strobe,     // from command_manager_selftrigc
  input  wire         hdr_read_strobe,
  input  wire [ 2:0]  hdr_chan,
  input  wire [22:0]  hdr_wfms,
  input  wire [22:0]  burst_count,         // bursts per waveform minus one (burst_count_selftrig)
  input  wire [22:0]  thres_ddr3_overflow,
  input  wire [ 4:0]  chan_en,
  output wire [119:0] wfms_read,           // {ch4, ch3, ch2, ch1, ch0}, 24 bits each
  output wire [114:0] fill_bursts,         // {ch4, ch3, ch2, ch1, ch0}, 23 bits each
  output reg          ddr3_almost_full
);

  reg [23:0] wfms_read_r   [0:4];
  reg [22:0] fill_bursts_r [0:4];

  // the product is pipelined: inputs registered, product registered, then stored
  reg        peek_d1 = 1'b0, peek_d2 = 1'b0;
  reg [ 2:0] chan_d1, chan_d2;
  reg [22:0] wfms_d1;
  reg [23:0] bpw_d1;                       // bursts per waveform
  reg [46:0] prod_d2;
  always @(posedge clk) begin
    peek_d1 <= hdr_peek_strobe & ~rst;
    chan_d1 <= hdr_chan;
    wfms_d1 <= hdr_wfms;
    bpw_d1  <= {1'b0, burst_count} + 24'd1;
    peek_d2 <= peek_d1 & ~rst;
    chan_d2 <= chan_d1;
    prod_d2 <= wfms_d1 * bpw_d1;
  end
  wire [22:0] prod_sat = (|prod_d2[46:23]) ? 23'h7FFFFF : prod_d2[22:0];

  integer k;
  always @(posedge clk) begin
    for (k = 0; k < 5; k = k + 1) begin
      if (rst || reset_totals)                                  wfms_read_r[k] <= 24'd0;
      else if (hdr_read_strobe && hdr_chan == k)                wfms_read_r[k] <= wfms_read_r[k] + {1'b0, hdr_wfms};
      if (rst || clear)                                         fill_bursts_r[k] <= 23'd0;
      else if (peek_d2 && chan_d2 == k)                         fill_bursts_r[k] <= prod_sat;
    end
  end

  // registered compare (one more clock after the store is immaterial)
  wire [4:0] over;
  genvar g;
  generate for (g = 0; g < 5; g = g + 1) begin : ov
    assign over[g] = chan_en[g] && (fill_bursts_r[g] > thres_ddr3_overflow);
    assign wfms_read  [24*g +: 24] = wfms_read_r[g];
    assign fill_bursts[23*g +: 23] = fill_bursts_r[g];
  end endgenerate
  always @(posedge clk) ddr3_almost_full <= !rst && (|over);

endmodule
