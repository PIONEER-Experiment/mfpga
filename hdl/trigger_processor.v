// Finite state machine to handle readout of processed TTC triggers

module trigger_processor (
  // clock and reset
  input wire clk,   // 125 MHz clock
  input wire reset,

  // interface to TTC Trigger FIFO
  input wire trig_fifo_valid,
  input wire [127:0] trig_fifo_data,
  output reg trig_fifo_ready,

  // interface to Acquisition Event FIFO
  input wire acq_fifo_valid,
  input wire [31:0] acq_fifo_data,
  output reg acq_fifo_ready,

  // interface to command manager
  input wire readout_ready,    // command manager is idle
  input wire readout_done,     // initiated readout has finished
  output reg send_empty_event, // request an empty event
  output reg initiate_readout, // request for the channels to be read out

  output reg [23:0] ttc_event_num,      // channel's trigger number
  output reg [23:0] ttc_trig_num,       // global trigger number
  output reg [ 4:0] ttc_trig_type,      // trigger type
  output reg [43:0] ttc_trig_timestamp, // trigger timestamp

  // status connections
  output reg [6:0] state,     // state of finite state machine
  output wire error_trig_num, // trigger number mismatch between FIFOs
  output wire error_trig_type // trigger type mismatch between FIFOs
);

  // state bits
  parameter IDLE             = 0;
  parameter READ_TRIG_FIFO   = 1;
  parameter SEND_EMPTY_EVENT = 2;
  parameter READ_ACQ_FIFO    = 3;
  parameter READOUT          = 4;
  parameter ERROR_TRIG_NUM   = 5;
  parameter ERROR_TRIG_TYPE  = 6;
  

  // latched data from TTC Trigger FIFO
  reg ttc_empty_event;

  // latched data from Acquisition Event FIFO
  reg [ 4:0] acq_trig_type;
  reg [23:0] acq_trig_num;

  // 'next' signals
  reg [ 6:0] nextstate;
  reg        next_ttc_empty_event;
  reg [ 4:0] next_ttc_trig_type;
  reg [23:0] next_ttc_event_num;
  reg [23:0] next_ttc_trig_num;
  reg [43:0] next_ttc_trig_timestamp;
  reg [ 4:0] next_acq_trig_type;
  reg [23:0] next_acq_trig_num;


  // comb always block
  always @* begin
    nextstate = 7'd0;

    next_ttc_empty_event          = ttc_empty_event;
    next_ttc_trig_type     [ 4:0] = ttc_trig_type     [ 4:0];
    next_ttc_event_num     [23:0] = ttc_event_num     [23:0];
    next_ttc_trig_num      [23:0] = ttc_trig_num      [23:0];
    next_ttc_trig_timestamp[43:0] = ttc_trig_timestamp[43:0];

    next_acq_trig_type[ 4:0] = acq_trig_type[ 4:0];
    next_acq_trig_num [23:0] = acq_trig_num [23:0];

    trig_fifo_ready = 1'b0; // default
    acq_fifo_ready  = 1'b0; // default

    send_empty_event = 1'b0; // default
    initiate_readout = 1'b0; // default

    case (1'b1) // synopsys parallel_case full_case
      // idle state
      state[IDLE] : begin
        // watch for unread triggers
        if (trig_fifo_valid) begin
          next_ttc_empty_event          = trig_fifo_data[   97];
          next_ttc_trig_type     [ 4:0] = trig_fifo_data[96:92];
          next_ttc_event_num     [23:0] = trig_fifo_data[91:68];
          next_ttc_trig_num      [23:0] = trig_fifo_data[67:44];
          next_ttc_trig_timestamp[43:0] = trig_fifo_data[43: 0];

          trig_fifo_ready = 1'b1; // acknowledge the data word
          nextstate[READ_TRIG_FIFO] = 1'b1;
        end
        else begin
          nextstate[IDLE] = 1'b1;
        end
      end
      // get TTC trigger information
      state[READ_TRIG_FIFO] : begin
        // check whether to send an empty event
        if (ttc_empty_event & readout_ready) begin
          send_empty_event = 1'b1;
          initiate_readout = 1'b1;
          nextstate[SEND_EMPTY_EVENT] = 1'b1;
        end
        // watch for unread acquisitions
        else if (acq_fifo_valid & ~ttc_empty_event) begin
          next_acq_trig_type[ 4:0] = acq_fifo_data[28:24];
          next_acq_trig_num [23:0] = acq_fifo_data[23: 0];

          acq_fifo_ready = 1'b1; // acknowledge the data word
          nextstate[READ_ACQ_FIFO] = 1'b1;
        end
        else begin
          nextstate[READ_TRIG_FIFO] = 1'b1;
        end
      end
      // initiate an empty event readout in command manager
      state[SEND_EMPTY_EVENT] : begin
        // wait for readout to finish
        if (readout_done) begin
          nextstate[IDLE] = 1'b1;
        end
        else begin
          nextstate[SEND_EMPTY_EVENT] = 1'b1;
        end
      end
      // get acquisition event information
      state[READ_ACQ_FIFO] : begin
        // verify that the trigger numbers match
        if (ttc_trig_num[23:0] != acq_trig_num[23:0]) begin
          nextstate[ERROR_TRIG_NUM] = 1'b1;
        end
        // verify that the trigger types match
        else if (ttc_trig_type[4:0] != acq_trig_type[4:0]) begin
          nextstate[ERROR_TRIG_TYPE] = 1'b1;
        end
        // check if we're ready for a readout
        else if (readout_ready) begin
          initiate_readout = 1'b1;
          nextstate[READOUT] = 1'b1;
        end
        else begin
          nextstate[READ_ACQ_FIFO] = 1'b1;
        end
      end
      // initiate event readout in command manager
      state[READOUT] : begin
        // wait for readout to finish
        if (readout_done) begin
          nextstate[IDLE] = 1'b1;
        end
        else begin
          nextstate[READOUT] = 1'b1;
        end
      end
      // trigger number mismatch between FIFOs
      state[ERROR_TRIG_NUM] : begin
        nextstate[ERROR_TRIG_NUM] = 1'b1; // hard error, stay here until reset
      end
      // trigger type mismatch between FIFOs
      state[ERROR_TRIG_TYPE] : begin
        nextstate[ERROR_TRIG_TYPE] = 1'b1; // hard error, stay here until reset
      end
    endcase
  end
  

  // sequential always block
  always @(posedge clk) begin
    // reset state machine
    if (reset) begin
      state <= 7'd1 << IDLE;

      ttc_empty_event          <=  1'd0;
      ttc_trig_type     [ 4:0] <=  5'd0;
      ttc_event_num     [23:0] <= 24'd0;
      ttc_trig_num      [23:0] <= 24'd0;
      ttc_trig_timestamp[43:0] <= 24'd0;

      acq_trig_type[ 4:0] <=  5'd0;
      acq_trig_num [23:0] <= 24'd0;
    end
    else begin
      state <= nextstate;

      ttc_empty_event          <= next_ttc_empty_event;
      ttc_trig_type     [ 4:0] <= next_ttc_trig_type     [ 4:0];
      ttc_event_num     [23:0] <= next_ttc_event_num     [23:0];
      ttc_trig_num      [23:0] <= next_ttc_trig_num      [23:0];
      ttc_trig_timestamp[43:0] <= next_ttc_trig_timestamp[43:0];

      acq_trig_type[ 4:0] <= next_acq_trig_type[ 4:0];
      acq_trig_num [23:0] <= next_acq_trig_num [23:0];
    end
  end

  // outputs based on states
  assign error_trig_num  = (state[ERROR_TRIG_NUM]  == 1'b1);
  assign error_trig_type = (state[ERROR_TRIG_TYPE] == 1'b1);

endmodule
