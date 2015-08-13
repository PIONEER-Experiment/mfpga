// Receives the TTC channel B signals
//
// Enables number reset in parallel with time reset or setting of fill type
//
// Notes:
// 1. 2-bit shift between Brcst from TTC_decoder and the chan_b_info we read
// in

module TTC_chanB_receiver (
  // user interface clock and reset
  input wire clk,
  input wire reset,

  // TTC channel B information
  input wire [5:0] chan_b_info, // Brcst from TTC decoder Brcst[7:2] = chan_b_info [5:0]
  input wire evt_count_reset,
  input wire chan_b_valid, // BrcstStr from TTC_decoder

  // Outputs to trigger_manager
  output reg [1:0] fill_type,
  output wire reset_trig_num,
  output wire reset_trig_timestamp
);
  reg [1:0] next_fill_type;
  assign reset_trig_num = evt_count_reset & chan_b_valid;
  assign reset_trig_timestamp = chan_b_valid && chan_b_info[1] && (chan_b_info[5:3] == 3'b001); // Reset trigger timestamp if we get a valid signal of the form 001X1X

  always @* begin
    if (reset) begin
      next_fill_type[1:0] <= 2'b01; // Default to muon fill
    end

    else if (chan_b_valid && chan_b_info[1] == 1'b0 && chan_b_info[5] == 1'b1 && chan_b_info[4:3]) begin // Transfer information on fill type - interpret signal as 1{fill_type[1:0]}x0x and ignore instructions to set fill type to 2'b00
      next_fill_type[1:0] <= chan_b_info[4:3];
    end

    else begin
      next_fill_type[1:0] <= fill_type[1:0];
    end
  end

  always @(posedge clk) begin
    if (reset) begin
      fill_type[1:0] <= 2'b01; //default to muon fill
    end
    else begin
      fill_type[1:0] <= next_fill_type[1:0];
    end
  end
endmodule
