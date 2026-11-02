// Error capture for the self-triggering master (6.6.10).
//
// Principle: the readout never loses data quietly.  Every condition under which an event is
// delivered incomplete or wrong ("data loss"), or under which the readout path itself failed
// ("fault"), sets a sticky flag here with its cause, freezes a snapshot of the master's state
// machines and key signals at that moment, and drives the TTS line (data loss -> sync lost,
// fault -> error; either makes the FC7 abort the run).  Recovered conditions are recorded as
// warnings without stopping anything.  The flags and the snapshot hold until software clears
// them (SYS.CLEAR_ERRORS, control register bit 29) or the master is reset, so that the frontend
// can read and log them at the end of the run.
//
// Snapshot (status registers 35 to 49, frozen at the FIRST loss or fault after a clear):
//   35  live: {valid, data_loss, fault, warning, snapshot count[3:0], fault bits[7:0], loss bits[15:0]}
//   36  {first cause: fault?[31], index[30:24]}, {channel addressed[23:20]}, {channel-reported error
//       word[19:13], its channel[12:9]}, {warning bits[3:0] at [8:5]}, {reply retries[4:3], 0, reissue retries[1:0]}
//   37  command manager state [31:0]
//   38  {cm state[34:32], ttr state[3:0], cac state[5:0], tp state[6:0], channel dones[4:0], 7'd0}
//   39  {chan_error_rc[4:0], chan_error_sn[4:0], readout pause[4:0], chan_en[4:0], cm_rx_valid[4:0],
//        cm_tx_ready[4:0], cm_rx_ready, cm_tx_valid}
//   40  {skipped channels this event[4:0], 3'd0, event number[23:0]}
//   41  {8'd0, trigger number[23:0]}
//   42  trigger timestamp [31:0]
//   43  {20'd0, trigger timestamp [43:32]}
//   44  last serial-number word received from a channel
//   45  last response-code word
//   46  last fill header word 1 (fill number, waveform count low bits)
//   47  last fill header word 4 (channel tag, type, the channel's error word)
//   48  miscellaneous live flags, see the top level
//   49  {loss bits latched since the snapshot[15:0], fault bits since[7:0], 2'd0, warning bits[5:0]}: what
//       came after the snapshot, and all six warning bits (6.7.0: bits 4 and 5 do not fit in 36)
// All inputs are in clk125 except the two TTC-domain pulses, which are synchronised here; the
// TTC-domain state fields are sampled as the status registers sample them (status only).

module error_capture_selftrigc (
  input wire clk,                       // clk125
  input wire rst,
  input wire clear,                     // level, from the control register; a rising edge clears
  // causes
  input wire [15:0] err_loss_pulse,     // command manager (clk125), one clock each
  input wire [ 7:0] err_fault_pulse,
  input wire [ 5:0] err_warn_pulse,
  input wire        empty_midrun,       // ttc_clk: readout trigger answered empty while the run was active
  input wire        cac_wait_gave_up,   // ttc_clk: the acquisition controller stopped waiting for a done
  input wire [ 6:0] chan_err_word,      // the error word a channel put in its fill header, with
  input wire        chan_err_valid,     // ... a one-clock strobe when it was non-zero
  // live state to freeze
  input wire [34:0] cm_state,
  input wire [ 3:0] ttr_state,
  input wire [ 5:0] cac_state,
  input wire [ 6:0] tp_state,
  input wire [ 4:0] acq_dones,
  input wire [ 4:0] chan_error_rc,
  input wire [ 4:0] chan_error_sn,
  input wire [ 4:0] acq_readout_pause,
  input wire [ 4:0] chan_en,
  input wire [ 4:0] cm_rx_valid,
  input wire [ 4:0] cm_tx_ready,
  input wire        cm_rx_ready,
  input wire        cm_tx_valid,
  input wire [ 3:0] cm_tx_dest,
  input wire [23:0] event_num,
  input wire [23:0] trig_num,
  input wire [43:0] trig_timestamp,
  input wire [31:0] last_rsn_word,
  input wire [31:0] last_rc_word,
  input wire [31:0] last_info1_word,
  input wire [31:0] last_info4_word,
  input wire [ 8:0] retry_status,       // {reply_retries[1:0], reissue_retries[1:0], skipped_mask[4:0]}
  input wire [31:0] misc_live,
  // outputs
  output reg         data_loss,         // sticky: drives TTS sync-lost
  output reg         hw_fault,          // sticky: drives TTS error
  output reg         warning,           // sticky: status only
  output wire [ 2:0] err_summary,       // {data_loss, hw_fault, warning}, for the WFD5 header word
  output wire [31:0] status_reg35, status_reg36, status_reg37, status_reg38, status_reg39,
  output wire [31:0] status_reg40, status_reg41, status_reg42, status_reg43, status_reg44,
  output wire [31:0] status_reg45, status_reg46, status_reg47, status_reg48, status_reg49
);

  localparam ERR_L_EMPTY_MIDRUN = 9, ERR_L_CAC_GAVE_UP = 10;

  // the two TTC-domain pulses (25 ns, at least three clk125 periods): synchronise and edge-detect
  (* ASYNC_REG = "TRUE" *) reg [1:0] em_s = 2'd0, cw_s = 2'd0;
  reg em_s3 = 1'b0, cw_s3 = 1'b0;
  always @(posedge clk) begin
    em_s <= {em_s[0], empty_midrun};     em_s3 <= em_s[1];
    cw_s <= {cw_s[0], cac_wait_gave_up}; cw_s3 <= cw_s[1];
  end
  wire [15:0] loss_now  = err_loss_pulse | {5'd0, (cw_s[1] & ~cw_s3), (em_s[1] & ~em_s3), 9'd0};
  wire [ 7:0] fault_now = err_fault_pulse;
  wire [ 5:0] warn_now  = err_warn_pulse;

  reg clear_d = 1'b0;
  wire do_clear = clear & ~clear_d;

  reg [15:0] loss_bits, loss_since;
  reg [ 7:0] fault_bits, fault_since;
  reg [ 5:0] warn_bits;
  reg        snap_valid;
  reg [ 3:0] snap_count;
  reg [ 7:0] first_cause;           // {fault?, index[6:0]}
  reg [ 6:0] snap_chan_err_word;  reg [3:0] snap_chan_err_src;
  reg [31:0] s36, s37, s38, s39, s40, s41, s42, s43, s44, s45, s46, s47, s48;

  // first-cause encoder: the lowest set loss bit, else the lowest set fault bit
  function [7:0] first_of;
    input [15:0] l; input [7:0] f;
    integer i; reg found;
    begin
      first_of = 8'hFF; found = 0;
      for (i = 0; i < 16; i = i + 1) if (!found && l[i]) begin first_of = {1'b0, i[6:0]}; found = 1; end
      for (i = 0; i <  8; i = i + 1) if (!found && f[i]) begin first_of = {1'b1, i[6:0]}; found = 1; end
    end
  endfunction

  wire take = (|loss_now | |fault_now) & ~snap_valid;

  always @(posedge clk) begin
    clear_d <= clear;
    if (rst || do_clear) begin
      data_loss <= 1'b0; hw_fault <= 1'b0; warning <= 1'b0;
      loss_bits <= 16'd0; fault_bits <= 8'd0; warn_bits <= 6'd0; loss_since <= 16'd0; fault_since <= 8'd0;
      snap_valid <= 1'b0;
      first_cause <= 8'hFF;
      if (rst) snap_count <= 4'd0;
      snap_chan_err_word <= 7'd0; snap_chan_err_src <= 4'd0;
    end
    else begin
      if (|loss_now)  data_loss <= 1'b1;
      if (|fault_now) hw_fault  <= 1'b1;
      if (|warn_now)  warning   <= 1'b1;
      loss_bits  <= loss_bits  | loss_now;
      fault_bits <= fault_bits | fault_now;
      warn_bits  <= warn_bits  | warn_now;
      if (snap_valid) begin loss_since <= loss_since | loss_now; fault_since <= fault_since | fault_now; end
      // the channel's own error word, kept from the first non-zero one after a clear
      if (chan_err_valid && snap_chan_err_word == 7'd0) begin snap_chan_err_word <= chan_err_word; snap_chan_err_src <= cm_tx_dest; end
      if (take) begin
        snap_valid  <= 1'b1;
        snap_count  <= snap_count + 4'd1;
        first_cause <= first_of(loss_now, fault_now);
        s37 <= cm_state[31:0];
        s38 <= {cm_state[34:32], ttr_state, cac_state, tp_state, acq_dones, 7'd0};
        s39 <= {chan_error_rc, chan_error_sn, acq_readout_pause, chan_en, cm_rx_valid, cm_tx_ready, cm_rx_ready, cm_tx_valid};
        s40 <= {retry_status[4:0], 3'd0, event_num};
        s41 <= {8'd0, trig_num};
        s42 <= trig_timestamp[31:0];
        s43 <= {20'd0, trig_timestamp[43:32]};
        s44 <= last_rsn_word;
        s45 <= last_rc_word;
        s46 <= last_info1_word;
        s47 <= last_info4_word;
        s48 <= misc_live;
        s36 <= {8'd0, cm_tx_dest, 7'd0, 4'd0, 4'd0, retry_status[8:7], 1'b0, retry_status[6:5]};
      end
    end
  end

  assign err_summary  = {data_loss, hw_fault, warning};
  assign status_reg35 = {snap_valid, data_loss, hw_fault, warning, snap_count, fault_bits, loss_bits};
  // 36 is assembled live from the frozen first cause and the later-arriving channel word / warnings
  assign status_reg36 = {first_cause, s36[23:20], snap_chan_err_word, snap_chan_err_src, warn_bits[3:0], s36[4:0]};
  assign status_reg37 = s37;
  assign status_reg38 = s38;
  assign status_reg39 = s39;
  assign status_reg40 = s40;
  assign status_reg41 = s41;
  assign status_reg42 = s42;
  assign status_reg43 = s43;
  assign status_reg44 = s44;
  assign status_reg45 = s45;
  assign status_reg46 = s46;
  assign status_reg47 = s47;
  assign status_reg48 = s48;
  assign status_reg49 = {loss_since, fault_since, 2'd0, warn_bits};

endmodule
