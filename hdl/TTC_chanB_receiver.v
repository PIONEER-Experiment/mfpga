// Receiver for TTC Channel B signals.
//
// Enables number reset in parallel with time reset or setting of fill type.

module ttc_chanb_receiver (
  // clock and reset
  input wire clk,
  input wire reset,

  // TTC Channel B information
  input wire [5:0] chan_b_info, // Brcst from TTC decoder, Brcst[7:2] = chan_b_info [5:0]
  input wire evt_count_reset,
  input wire chan_b_valid,      // BrcstStr from TTC_decoder
  input wire ttc_loopback,

  // outputs to trigger logic
  output reg [2:0] fill_type,
  output reg accept_pulse_triggers,
  output wire reset_trig_num,
  output wire reset_trig_timestamp,

  // status information
  input wire [31:0] thres_unknown_ttc, // threshold for unknown TTC broadcast command instances
  output reg [31:0] unknown_cmd_count, // number of unknown TTC broadcast commands
  output wire error_unknown_ttc        // hard error flag for unknown TTC broadcast commands
);

  // valid broadcast commands:
  //
  // xxxxxx1x -> event-count reset
  // 001x1xxx -> counter reset
  //
  // 100x0xxx -> asynchronous fill type
  // 101x0xxx -> muon fill type
  // 110x0xxx -> laser fill type
  // 111x0xxx -> pedestal fill type
  //
  // 100x1xxx -> start asynchronous pulse storage
  // 101x1xxx -> stop asynchronous pulse storage


  reg [ 2:0] next_fill_type;
  reg next_accept_pulse_triggers;
  reg [31:0] next_unknown_cmd_count;

  assign reset_trig_num       = evt_count_reset;
  assign reset_trig_timestamp = chan_b_valid & chan_b_info[1] & (chan_b_info[5:3] == 3'b001); // reset trigger timestamp for valid signals of form 001X1X
  assign error_unknown_ttc    = (unknown_cmd_count[31:0] > thres_unknown_ttc[31:0]);


  // combinational always block
  always @* begin
    // default
    next_fill_type[2:0]          = fill_type[2:0];
    next_accept_pulse_triggers   = accept_pulse_triggers;
    next_unknown_cmd_count[31:0] = unknown_cmd_count[31:0];

    // transfer information on synchronous fill type
    if (chan_b_valid & (chan_b_info[1] == 1'b0) & (chan_b_info[5] == 1'b1) & chan_b_info[4:3]) begin
      next_fill_type[2:0]          = {1'b0, chan_b_info[4:3]};
      next_accept_pulse_triggers   = accept_pulse_triggers;
      next_unknown_cmd_count[31:0] = unknown_cmd_count[31:0];
    end
    // transfer information on asynchronous fill type
    else if (chan_b_valid & (chan_b_info[1] == 1'b0) & (chan_b_info[5:3] == 3'b100)) begin
      next_fill_type[2:0]          = 3'b111;
      next_accept_pulse_triggers   = accept_pulse_triggers;
      next_unknown_cmd_count[31:0] = unknown_cmd_count[31:0];
    end
    // transfer information on asynchronous pulse storage
    else if (chan_b_valid & (chan_b_info[1] == 1'b1) & (chan_b_info[5:4] == 2'b10)) begin
      next_fill_type[2:0]          = fill_type[2:0];
      next_accept_pulse_triggers   = ~chan_b_info[3];
      next_unknown_cmd_count[31:0] = unknown_cmd_count[31:0];
    end
    // invalid broadcast command
    else if (chan_b_valid & ~evt_count_reset & ~reset_trig_timestamp) begin
      next_fill_type[1:0]          <= fill_type[1:0];
      next_accept_pulse_triggers   <= accept_pulse_triggers;
      next_unknown_cmd_count[31:0] <= unknown_cmd_count[31:0] + 1; // increment soft error counter
    end
  end


  // sequential always block
  always @(posedge clk) begin
    if (reset | ttc_loopback) begin
      fill_type[2:0]          <= 3'b001; // default to muon fill
      accept_pulse_triggers   <= 1'b0;
      unknown_cmd_count[31:0] <= 32'd0;
    end
    else begin
      fill_type[2:0]          <= next_fill_type[2:0];
      accept_pulse_triggers   <= next_accept_pulse_triggers;
      unknown_cmd_count[31:0] <= next_unknown_cmd_count[31:0];
    end
  end

endmodule
