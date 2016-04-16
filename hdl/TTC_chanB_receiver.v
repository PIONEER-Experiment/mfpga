// Receiver for TTC Channel B signals.
//
// Enables number reset in parallel with time reset or setting of fill type.

module TTC_chanB_receiver (
  // clock and reset
  input wire clk,
  input wire reset,

  // TTC Channel B information
  input wire [5:0] chan_b_info, // Brcst from TTC decoder, Brcst[7:2] = chan_b_info [5:0]
  input wire evt_count_reset,
  input wire chan_b_valid,      // BrcstStr from TTC_decoder

  // outputs to trigger logic
  output reg [1:0] fill_type,
  output wire reset_trig_num,
  output wire reset_trig_timestamp,

  // status information
  input wire [31:0] thres_unknown_ttc, // threshold for unknown TTC broadcast command instances
  output reg [31:0] unknown_cmd_count, // number of unknown TTC broadcast commands
  output wire error_unknown_ttc        // hard error flag for unknown TTC broadcast commands
);

  reg [ 1:0] next_fill_type;
  reg [31:0] next_unknown_cmd_count;

  assign reset_trig_num = evt_count_reset & chan_b_valid;
  // reset trigger timestamp for valid signals of form 001X1X
  assign reset_trig_timestamp = chan_b_valid && chan_b_info[1] && (chan_b_info[5:3] == 3'b001);
  assign error_unknown_ttc = (unknown_cmd_count[31:0] > thres_unknown_ttc[31:0]);


  always @* begin
    // reset
    if (reset) begin
      next_fill_type[1:0] <= 2'b01; // default to muon fill
      next_unknown_cmd_count[31:0] <= 32'd0;
    end
    // transfer information on fill type
    // interpret signal as 1{fill_type[1:0]}X0X and ignore instructions to set fill type to 2'b00
    else if (chan_b_valid && (chan_b_info[1] == 1'b0) && (chan_b_info[5] == 1'b1) && chan_b_info[4:3]) begin
      next_fill_type[1:0] <= chan_b_info[4:3];
      next_unknown_cmd_count[31:0] <= unknown_cmd_count[31:0];
    end
    // invalid broadcast command
    else if (chan_b_valid) begin
      next_fill_type[1:0] <= fill_type[1:0];
      next_unknown_cmd_count[31:0] <= unknown_cmd_count[31:0] + 1; // increment soft error counter
    end
    // no broadcast command sent
    else begin
      next_fill_type[1:0] <= fill_type[1:0];
      next_unknown_cmd_count[31:0] <= unknown_cmd_count[31:0];
    end
  end


  always @(posedge clk) begin
    if (reset) begin
      fill_type[1:0] <= 2'b01; // default to muon fill
      unknown_cmd_count[31:0] <= 32'd0;
    end
    else begin
      fill_type[1:0] <= next_fill_type[1:0];
      unknown_cmd_count[31:0] <= next_unknown_cmd_count[31:0];
    end
  end

endmodule
