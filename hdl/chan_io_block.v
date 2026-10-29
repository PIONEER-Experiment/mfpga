// This module provides the programmable I/O interface for one channel.

module chan_io_block (
  // programming interface
  // inputs
  input io_clk,              // programming clock
  input io_reset,            // active-high
  input io_sel,              // this module has been selected for an I/O operation
  input io_sync,             // start the I/O operation
  input [3:0] io_addr,      // slave address, memory or register; top 12 bits already consumed
  input io_rd_en,            // this is a read operation
  input io_wr_en,            // this is a write operation
  input [31:0] io_wr_data,   // data to write for write operations
  // outputs
  output [31:0] io_rd_data,  // data returned for read operations
  output io_rd_ack,          // 'read' data from this module is ready
  // write/read register data
  output [2:0] loopback_set, // 3-bit setting for the Aurora loopback port
  // read-only signals
  input frame_err,           // 
  input hard_err,            // 
  input soft_err,            // 
  input channel_up,          // 
  input lane_up,             // 
  input pll_not_locked,      // 
  input tx_resetdone_out,    // 
  input rx_resetdone_out,    // 
  input link_reset_out,      // 
  // diagnostics counters from one_channel (various clock domains, free running):
  input [31:0] rx_word_counts, // {words taken out of the RX FIFO [31:16], words put into it by the Aurora [15:0]}
  input [31:0] tx_err_counts,  // {words put into the TX FIFO [31:16], frame_err count [15:8], soft_err count [7:0]}
  input [31:0] link_event_counts, // {channel_up drops [31:24], lane_up drops [23:16], hard_err [15:8], link_reset [7:0]}, clk50 domain
  input [31:0] pause_counts       // {clk50 periods spent paused [31:16], pause rising edges [15:8], 7'd0, paused now [0]}, clk50 domain
);

  ///////////////////////////////////////////
  // some common address decoding assignments
  assign reg_wr_en  = io_sync & io_wr_en;
  assign live_status_sel  = io_sel & (io_addr[3:0] == 4'b0000);
  assign loopback_reg_sel = io_sel & (io_addr[3:0] == 4'b0001);
  assign rx_counts_sel    = io_sel & (io_addr[3:0] == 4'b0010);
  assign tx_counts_sel    = io_sel & (io_addr[3:0] == 4'b0011);
  assign link_events_sel  = io_sel & (io_addr[3:0] == 4'b0100);
  assign pause_counts_sel = io_sel & (io_addr[3:0] == 4'b0101);

  // the counters are sampled through two register stages; they come from other clock domains and
  // are only meaningful when read while the link is quiet (after a stuck readout, say)
  (* ASYNC_REG = "TRUE" *) reg [31:0] rx_counts_s1 = 32'd0, rx_counts_s2 = 32'd0;
  (* ASYNC_REG = "TRUE" *) reg [31:0] tx_counts_s1 = 32'd0, tx_counts_s2 = 32'd0;
  (* ASYNC_REG = "TRUE" *) reg [31:0] link_ev_s1 = 32'd0, link_ev_s2 = 32'd0;
  (* ASYNC_REG = "TRUE" *) reg [31:0] pause_s1 = 32'd0, pause_s2 = 32'd0;
  always @(posedge io_clk) begin
    rx_counts_s1 <= rx_word_counts;    rx_counts_s2 <= rx_counts_s1;
    tx_counts_s1 <= tx_err_counts;     tx_counts_s2 <= tx_counts_s1;
    link_ev_s1   <= link_event_counts; link_ev_s2   <= link_ev_s1;
    pause_s1     <= pause_counts;      pause_s2     <= pause_s1;
  end

  // live_status register
  // instant state of many status bits; one may be meaningless because they
  // are only valid at particular times; gradually fix up that stuff
  // The status inputs come from the Aurora core's own clock domains; pass them through a
  // two-stage synchroniser rather than sampling them with a single flop.
  (* ASYNC_REG = "TRUE" *) reg [8:0] status_sync1 = 9'd0, status_sync2 = 9'd0;
  always @(posedge io_clk) begin
    status_sync1 <= {link_reset_out,    // [8]
                     rx_resetdone_out,  // [7]
                     tx_resetdone_out,  // [6]
                     pll_not_locked,    // [5]
                     soft_err,          // [4]
                     hard_err,          // [3]
                     frame_err,         // [2]
                     lane_up,           // [1]
                     channel_up};       // [0]
    status_sync2 <= status_sync1;
  end
  wire [31:0] live_status_reg;
  assign live_status_reg = {23'b0, status_sync2};

  // loopback register
  // only the 3 LSBs have meaning and are connected to the Aurora
  wire [31:0] loopback_all; // the full register width
  reg32_ce2 loopback_reg (
    .in(io_wr_data[31:0]),
    .reset(io_reset),
    .def_value(32'd0),
    .out(loopback_all),
    .clk(io_clk),
    .clk_en1(reg_wr_en),
    .clk_en2(loopback_reg_sel)
  );
  assign loopback_set[2:0] = loopback_all[2:0]; // the 3 LSBs

  ///////////////////////////////////////////////////////////////////////////////////////////////
  // readback MUX
  // If a particular register or memory is addressed, connect that register's or memory's signals
  // to the 'io_rd_data' output. At the same time, assert 'io_rd_ack' to tell downstream muxes to
  // use the 'io_rd_data' from this module as their source of data.
  reg [31:0] io_rd_data_reg;
  assign io_rd_data[31:0] = io_rd_data_reg[31:0];

  // assert 'io_rd_ack' if chip select for this module is asserted during a 'read' operation
  reg io_rd_ack_reg;
  assign io_rd_ack = io_rd_ack_reg;

  always @(posedge io_clk) begin
    io_rd_ack_reg <= io_sync & io_sel & io_rd_en;
  end

  // route the selected register to the 'io_rd_data' output
  always @(posedge io_clk) begin
    if (live_status_sel)  io_rd_data_reg[31:0] <= live_status_reg[31:0];
    if (loopback_reg_sel) io_rd_data_reg[31:0] <= loopback_all[31:0];
    if (rx_counts_sel)    io_rd_data_reg[31:0] <= rx_counts_s2[31:0];
    if (tx_counts_sel)    io_rd_data_reg[31:0] <= tx_counts_s2[31:0];
    if (link_events_sel)  io_rd_data_reg[31:0] <= link_ev_s2[31:0];
    if (pause_counts_sel) io_rd_data_reg[31:0] <= pause_s2[31:0];
  end

endmodule
