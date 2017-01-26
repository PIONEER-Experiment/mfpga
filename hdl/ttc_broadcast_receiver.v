// Receiver for TTC Channel B signals.
//
// Enables number reset in parallel with time reset or setting of fill type.

module ttc_broadcast_receiver (
  // clock and reset
  input wire clk,
  input wire reset,

  // TTC Channel B information
  input wire [5:0] chan_b_info, // Brcst from TTC decoder, Brcst[7:2] = chan_b_info[5:0]
  input wire evt_count_reset,
  input wire chan_b_valid,      // BrcstStr from TTC_decoder
  input wire ttc_loopback,

  // outputs to trigger logic
  output reg [4:0] fill_type,
  output reg accept_pulse_triggers,
  output wire reset_trig_num,
  output wire reset_trig_timestamp,

  // status information
  input wire [31:0] thres_unknown_ttc, // threshold for unknown TTC broadcast command instances
  output reg [31:0] unknown_cmd_count, // number of unknown TTC broadcast commands
  output wire error_unknown_ttc        // hard error flag for unknown TTC broadcast commands
);

  // recognized broadcast commands:
  //
  // 00000_0_01 -> bunch count reset
  // 00000_0_10 -> event count reset
  //
  // 00001_1_00 -> switch to muon trigger type
  // 00010_1_00 -> switch to laser trigger type
  // 00011_1_00 -> switch to pedestal trigger type
  // 00111_1_00 -> switch to asynchronous trigger type
  //
  // 00101_0_00 -> timestamp reset
  // 11000_0_00 -> start asynchronous pulse storage
  // 10000_0_00 -> stop asynchronous pulse storage


  reg [ 4:0] next_fill_type;
  reg next_accept_pulse_triggers;
  reg [31:0] next_unknown_cmd_count;

  assign reset_trig_num       = evt_count_reset;
  assign reset_trig_timestamp = chan_b_valid & (chan_b_info[5:0] == 6'b001010);
  assign error_unknown_ttc    = (unknown_cmd_count[31:0] > thres_unknown_ttc[31:0]);


  // combinational always block
  always @* begin
    // default
    next_fill_type[4:0]          = fill_type[4:0];
    next_accept_pulse_triggers   = accept_pulse_triggers;
    next_unknown_cmd_count[31:0] = unknown_cmd_count[31:0];

    // transfer information on trigger type switch
    if (chan_b_valid & chan_b_info[0]) begin
      next_fill_type[4:0]          = chan_b_info[5:1];
      next_accept_pulse_triggers   = accept_pulse_triggers;
      next_unknown_cmd_count[31:0] = unknown_cmd_count[31:0];
    end
    // transfer information on asynchronous pulse storage
    else if (chan_b_valid & (chan_b_info[5] == 1'b1) & (chan_b_info[3:0] == 4'b0000)) begin
      next_fill_type[4:0]          = fill_type[4:0];
      next_accept_pulse_triggers   = chan_b_info[4];
      next_unknown_cmd_count[31:0] = unknown_cmd_count[31:0];
    end
    // invalid broadcast command
    else if (chan_b_valid & ~evt_count_reset & ~reset_trig_timestamp) begin
      next_fill_type[4:0]          <= fill_type[4:0];
      next_accept_pulse_triggers   <= accept_pulse_triggers;
      next_unknown_cmd_count[31:0] <= unknown_cmd_count[31:0] + 1; // increment soft error counter
    end
  end


  // sequential always block
  always @(posedge clk) begin
    if (reset | ttc_loopback) begin
      fill_type[4:0]          <=  5'b00001; // default to muon fill
      accept_pulse_triggers   <=  1'b0;
      unknown_cmd_count[31:0] <= 32'd0;
    end
    else begin
      fill_type[4:0]          <= next_fill_type[4:0];
      accept_pulse_triggers   <= next_accept_pulse_triggers;
      unknown_cmd_count[31:0] <= next_unknown_cmd_count[31:0];
    end
  end

endmodule
