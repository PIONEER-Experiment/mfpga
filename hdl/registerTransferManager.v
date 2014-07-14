
// Created by fizzim.pl version $Revision: 4.44 on 2014:07:13 at 17:51:42 (www.fizzim.com)

module registerTransferManager (
  output reg chan_rx_fifo_ready,
  output reg [31:0] chan_tx_fifo_data,
  output reg [3:0] chan_tx_fifo_dest,
  output reg chan_tx_fifo_last,
  output reg chan_tx_fifo_valid,
  output reg ipbus_cmd_ready,
  output reg [31:0] ipbus_res_data,
  output reg ipbus_res_last,
  output reg ipbus_res_valid,
  output reg rtm_done,
  input wire [31:0] chan_rx_fifo_data,
  input wire chan_rx_fifo_last,
  input wire chan_rx_fifo_valid,
  input wire chan_tx_fifo_ready,
  input wire clk,
  input wire [31:0] csn,
  input wire [31:0] ipbus_cmd_data,
  input wire [3:0] ipbus_cmd_dest,
  input wire ipbus_cmd_last,
  input wire ipbus_cmd_valid,
  input wire ipbus_res_ready,
  input wire rst,
  input wire run_rtm 
);

  // state bits
  parameter 
  IDLE           = 0, 
  CHECK_LAST     = 1, 
  READ_IPBUS_CMD = 2, 
  READ_IPBUS_RES = 3, 
  READ_IPBUS_RSN = 4, 
  SEND_IPBUS_CMD = 5, 
  SEND_IPBUS_CSN = 6, 
  SEND_IPBUS_RES = 7; 

  (* mark_debug = "true" *) reg [7:0] state;
  reg [7:0] nextstate;
  (* mark_debug = "true" *) reg [31:0] ipbus_buf;
  reg [3:0] next_chan_tx_fifo_dest;
  reg next_chan_tx_fifo_last;
  reg [31:0] next_ipbus_buf;
  reg next_ipbus_res_last;

  // comb always block
  always @* begin
    nextstate = 8'b00000000;
    chan_tx_fifo_data[31:0] = 0; // default
    ipbus_res_data[31:0] = 0; // default
    next_chan_tx_fifo_dest[3:0] = chan_tx_fifo_dest[3:0];
    next_chan_tx_fifo_last = chan_tx_fifo_last;
    next_ipbus_buf[31:0] = ipbus_buf[31:0];
    next_ipbus_res_last = ipbus_res_last;
    case (1'b1) // synopsys parallel_case full_case
      state[IDLE]          : begin
        if (ipbus_cmd_valid && run_rtm) begin
          nextstate[SEND_IPBUS_CSN] = 1'b1;
          next_chan_tx_fifo_last = 0;
          next_chan_tx_fifo_dest[3:0] = ipbus_cmd_dest[3:0];
        end
        else begin
          nextstate[IDLE] = 1'b1; // Added because implied_loopback is true
        end
      end
      state[CHECK_LAST]    : begin
        begin
          nextstate[SEND_IPBUS_CMD] = 1'b1;
          next_chan_tx_fifo_last = ipbus_cmd_last;
        end
      end
      state[READ_IPBUS_CMD]: begin
        if (ipbus_cmd_valid) begin
          nextstate[CHECK_LAST] = 1'b1;
          next_ipbus_buf[31:0] = ipbus_cmd_data[31:0];
        end
        else begin
          nextstate[READ_IPBUS_CMD] = 1'b1; // Added because implied_loopback is true
        end
      end
      state[READ_IPBUS_RES]: begin
        if (chan_rx_fifo_valid) begin
          nextstate[SEND_IPBUS_RES] = 1'b1;
          next_ipbus_buf[31:0] = chan_rx_fifo_data[31:0];
          next_ipbus_res_last = chan_rx_fifo_last;
        end
        else begin
          nextstate[READ_IPBUS_RES] = 1'b1; // Added because implied_loopback is true
        end
      end
      state[READ_IPBUS_RSN]: begin
        if (chan_rx_fifo_valid) begin
          nextstate[READ_IPBUS_RES] = 1'b1;
        end
        else begin
          nextstate[READ_IPBUS_RSN] = 1'b1; // Added because implied_loopback is true
        end
      end
      state[SEND_IPBUS_CMD]: begin
        chan_tx_fifo_data[31:0] = ipbus_buf[31:0];
        if (chan_tx_fifo_ready && chan_tx_fifo_last) begin
          nextstate[READ_IPBUS_RSN] = 1'b1;
        end
        else if (chan_tx_fifo_ready) begin
          nextstate[READ_IPBUS_CMD] = 1'b1;
          next_chan_tx_fifo_last = 0;
        end
        else begin
          nextstate[SEND_IPBUS_CMD] = 1'b1; // Added because implied_loopback is true
        end
      end
      state[SEND_IPBUS_CSN]: begin
        chan_tx_fifo_data[31:0] = csn[31:0];
        if (chan_tx_fifo_ready) begin
          nextstate[READ_IPBUS_CMD] = 1'b1;
        end
        else begin
          nextstate[SEND_IPBUS_CSN] = 1'b1; // Added because implied_loopback is true
        end
      end
      state[SEND_IPBUS_RES]: begin
        ipbus_res_data[31:0] = ipbus_buf[31:0];
        if (ipbus_res_ready && ipbus_res_last) begin
          nextstate[IDLE] = 1'b1;
        end
        else if (ipbus_res_ready) begin
          nextstate[READ_IPBUS_RES] = 1'b1;
        end
        else begin
          nextstate[SEND_IPBUS_RES] = 1'b1; // Added because implied_loopback is true
        end
      end
    endcase
  end

  // sequential always block
  always @(posedge clk) begin
    if (rst) begin
      state <= 8'b00000001 << IDLE;
      chan_tx_fifo_dest[3:0] <= 0;
      chan_tx_fifo_last <= 0;
      ipbus_buf[31:0] <= 0;
      ipbus_res_last <= 0;
      end
    else begin
      state <= nextstate;
      chan_tx_fifo_dest[3:0] <= next_chan_tx_fifo_dest[3:0];
      chan_tx_fifo_last <= next_chan_tx_fifo_last;
      ipbus_buf[31:0] <= next_ipbus_buf[31:0];
      ipbus_res_last <= next_ipbus_res_last;
      end
  end

  // datapath sequential always block
  always @(posedge clk) begin
    if (rst) begin
      chan_rx_fifo_ready <= 0;
      chan_tx_fifo_valid <= 0;
      ipbus_cmd_ready <= 0;
      ipbus_res_valid <= 0;
      rtm_done <= 1;
    end
    else begin
      chan_rx_fifo_ready <= 0; // default
      chan_tx_fifo_valid <= 0; // default
      ipbus_cmd_ready <= 0; // default
      ipbus_res_valid <= 0; // default
      rtm_done <= 0; // default
      case (1'b1) // synopsys parallel_case full_case
        nextstate[IDLE]          : begin
          rtm_done <= 1;
        end
        nextstate[CHECK_LAST]    : begin
          ; // case must be complete for onehot
        end
        nextstate[READ_IPBUS_CMD]: begin
          ipbus_cmd_ready <= 1;
        end
        nextstate[READ_IPBUS_RES]: begin
          chan_rx_fifo_ready <= 1;
        end
        nextstate[READ_IPBUS_RSN]: begin
          chan_rx_fifo_ready <= 1;
        end
        nextstate[SEND_IPBUS_CMD]: begin
          chan_tx_fifo_valid <= 1;
        end
        nextstate[SEND_IPBUS_CSN]: begin
          chan_tx_fifo_valid <= 1;
        end
        nextstate[SEND_IPBUS_RES]: begin
          ipbus_res_valid <= 1;
        end
      endcase
    end
  end

  // This code allows you to see state names in simulation
  `ifndef SYNTHESIS
  reg [111:0] statename;
  always @* begin
    case (1'b1)
      state[IDLE]          :
        statename = "IDLE";
      state[CHECK_LAST]    :
        statename = "CHECK_LAST";
      state[READ_IPBUS_CMD]:
        statename = "READ_IPBUS_CMD";
      state[READ_IPBUS_RES]:
        statename = "READ_IPBUS_RES";
      state[READ_IPBUS_RSN]:
        statename = "READ_IPBUS_RSN";
      state[SEND_IPBUS_CMD]:
        statename = "SEND_IPBUS_CMD";
      state[SEND_IPBUS_CSN]:
        statename = "SEND_IPBUS_CSN";
      state[SEND_IPBUS_RES]:
        statename = "SEND_IPBUS_RES";
      default       :
        statename = "XXXXXXXXXXXXXX";
    endcase
  end
  `endif

endmodule

