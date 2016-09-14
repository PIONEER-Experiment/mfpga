`timescale 1ns / 1ps

// IPbus interface to flash memory
// 
// Written for flash memory chip: Micron N25Q256A
// 
// WBUF = block RAM to hold commands & data to be sent to flash
//        write to this buffer using IPbus address FLASH.WBUF
//        (the MSB will be sent to flash first)
//
// RBUF = block RAM to hold response from flash
//        read from this buffer using IPbus address FLASH.RBUF
//        (the MSB is the first bit of the flash response)
//
// To initiate a transaction with the flash, write a command to IPbus address FLASH.CMD
//        The format of the 32-bit command is 0x0NNN0MMM
//        "NNN" is the number of bytes that will be sent from WBUF to the flash
//        "MMM" is the number of response bytes to store in RBUF from the flash
//        both NNN and MMM are limited to 9 bits
//
// prog_channels.v can also take over the interface to read the channel bitstream

module spi_flash_intf (
	input clk,
    input ipb_clk,
	input reset,
	output spi_clk,
	output spi_mosi,
	input spi_miso,
	output spi_ss,
    input prog_chan_in_progress,
    input read_bitstream,
    output end_bitstream,
    input [8:0] ipb_flash_wr_nBytes,
    input [8:0] ipb_flash_rd_nBytes,
    input ipb_flash_cmd_strobe,
    input ipb_rbuf_rd_en,
    input [6:0] ipb_rbuf_rd_addr,
    output [31:0] ipb_rbuf_data_out,
    input ipb_wbuf_wr_en,
    input [6:0] ipb_wbuf_wr_addr,
    input [31:0] ipb_wbuf_data_in,
    input pc_wbuf_wr_en,
    input [6:0] pc_wbuf_wr_addr,
    input [31:0] pc_wbuf_data_in
);


assign spi_clk = ~clk;

reg [8:0] flash_wr_nBytes;
reg [8:0] flash_rd_nBytes;
wire flash_cmd_strobe;

reg wbuf_wr_en;
reg [6:0] wbuf_wr_addr;
reg [31:0] wbuf_data_in;

wire wbuf_rd_en;
wire [13:0] wbuf_rd_addr;
wire wbuf_data_out;

wire rbuf_wr_en;
wire [13:0] rbuf_wr_addr;
wire rbuf_data_in;

wire rbuf_rd_en;
wire [6: 0] rbuf_rd_addr;
wire [31:0] rbuf_data_out;


// ================================================
// bring IPbus signals into the 50 MHz clock domain 
// ================================================

sync_2stage flash_cmd_sync (
    .clk(clk),
    .in(ipb_flash_cmd_strobe),
    .out(flash_cmd_strobe)
);

reg [8:0] flash_wr_nBytes_sync;
reg [8:0] flash_rd_nBytes_sync;
always @(posedge clk) begin
    flash_wr_nBytes_sync <= ipb_flash_wr_nBytes;
    flash_wr_nBytes <= flash_wr_nBytes_sync;
    flash_rd_nBytes_sync <= ipb_flash_rd_nBytes;
    flash_rd_nBytes <= flash_rd_nBytes_sync;
end


// ===============================================================
// bring prog_channels signals into the IPbus 125 MHz clock domain
// ===============================================================

wire prog_chan_in_progress_125;
wire pc_wbuf_wr_en_125;

sync_2stage prog_chan_sync (
    .clk(ipb_clk),
    .in(prog_chan_in_progress),
    .out(prog_chan_in_progress_125)
);

sync_2stage pc_wbur_wr_en_sync (
    .clk(ipb_clk),
    .in(pc_wbuf_wr_en),
    .out(pc_wbuf_wr_en_125)
);


// ========================================
// determine control of WBUF and RBUF ports
// ========================================

// only IPbus communicates with the read port of RBUF
assign rbuf_rd_en = ipb_rbuf_rd_en;
assign rbuf_rd_addr = ipb_rbuf_rd_addr;
assign ipb_rbuf_data_out = rbuf_data_out;

// select whether IPbus or prog_channels controls the write port of WBUF
always @(posedge ipb_clk) begin
    if (prog_chan_in_progress_125) begin
        wbuf_wr_en <= pc_wbuf_wr_en_125;
        wbuf_wr_addr <= pc_wbuf_wr_addr;
        wbuf_data_in <= pc_wbuf_data_in;
    end
    else begin
        wbuf_wr_en <= ipb_wbuf_wr_en;
        wbuf_wr_addr <= ipb_wbuf_wr_addr;
        wbuf_data_in <= ipb_wbuf_data_in;
    end
end


// ====================================================
// counter for addresses on flash side of WBUF and RBUF
// ====================================================

reg [11:0] bit_cnt = 12'b0;
wire bit_cnt_reset;

wire [11:0] bit_cnt_wr_max;
wire [11:0] bit_cnt_rd_max;
assign bit_cnt_wr_max[11:0] = {flash_wr_nBytes[8:0], 3'b000} - 1'b1;
assign bit_cnt_rd_max[11:0] = {flash_rd_nBytes[8:0], 3'b000} - 1'b1;

always @(posedge clk) begin
    if (bit_cnt_reset)
        bit_cnt[11:0] <= 12'b0;
    else
        bit_cnt[11:0] <= bit_cnt[11:0] + 1'b1;
end


// =========================
// channel bitstream counter
// =========================

reg [24:0] chan_bs_bit_cnt = 25'b0;
wire chan_bs_bit_cnt_reset;

// channel bitstream has 24,090,592 bits, 
//     so counter needs to go from 0 to 24,090,591 = 0x16F97DF
wire [24:0] chan_bs_bit_cnt_max = 25'h16F97DF;

always @(posedge clk) begin
    if (chan_bs_bit_cnt_reset)
        chan_bs_bit_cnt[24:0] <= 12'b0;
    else
        chan_bs_bit_cnt[24:0] <= chan_bs_bit_cnt[24:0] + 1'b1;
end


// ==========================================
// state machine for communicating with flash
// ==========================================

// declare symbolic name for each state
// simplified one-hot encoding (each constant is an index into an array of bits)
parameter [3:0]
    IDLE               = 4'd0,
    START_CMD          = 4'd1,
    SEND_CMD           = 4'd2,
    FINISH_CMD         = 4'd3,
    RECEIVE_RSP        = 4'd4,
    START_CHAN_BS_CMD  = 4'd5,
    SEND_CHAN_BS_CMD   = 4'd6,
    FINISH_CHAN_BS_CMD = 4'd7,
    READ_CHAN_BS       = 4'd8,
    CHAN_BS_DONE       = 4'd9;


// declare current state and next state variables
reg [9:0] CS;
reg [9:0] NS;

// sequential always block for state transitions (use non-blocking [<=] assignments)
always @(posedge clk) begin
    if (reset) begin
        CS <= 5'b0;       // set all state bits to 0
        CS[IDLE] <= 1'b1; // enter IDLE state
    end
    else
        CS <= NS;         // go to the next state
end

// combinational always block to determine next state (use blocking [=] assignments)
always @* begin
    NS = 12'b0; // one bit will be set to 1 by case statement

    case (1'b1)

        CS[IDLE] : begin
            if (flash_cmd_strobe && bit_cnt_wr_max != 12'hFFF && !prog_chan_in_progress)
                                     // stay in IDLE if flash_wr_nBytes = 0
                                     // prog_channels overrides IPbus if there is a conflict
                NS[START_CMD] = 1'b1;
            else if (read_bitstream)
                NS[START_CHAN_BS_CMD] = 1'b1;
            else
                NS[IDLE] = 1'b1;
        end

        CS[START_CMD] : begin
            NS[SEND_CMD] = 1'b1;
        end

        CS[SEND_CMD] : begin
            if (bit_cnt == bit_cnt_wr_max)
                NS[FINISH_CMD] = 1'b1;
            else
                NS[SEND_CMD] = 1'b1;
        end

        CS[FINISH_CMD] : begin
            if (bit_cnt_rd_max == 12'hFFF) // flash_rd_nBytes = 0
                NS[IDLE] = 1'b1;
            else
                NS[RECEIVE_RSP] = 1'b1;
        end

        CS[RECEIVE_RSP] : begin
            if (bit_cnt == bit_cnt_rd_max)
                NS[IDLE] = 1'b1;
            else
                NS[RECEIVE_RSP] = 1'b1;
        end

        CS[START_CHAN_BS_CMD] : begin
            NS[SEND_CHAN_BS_CMD] = 1'b1;
        end

        CS[SEND_CHAN_BS_CMD] : begin
            if (bit_cnt == 12'b11111) // send 4 bytes
                NS[FINISH_CHAN_BS_CMD] = 1'b1;
            else
                NS[SEND_CHAN_BS_CMD] = 1'b1;
        end

        CS[FINISH_CHAN_BS_CMD] : begin
            NS[READ_CHAN_BS] = 1'b1;
        end

        CS[READ_CHAN_BS] : begin
            if (chan_bs_bit_cnt == chan_bs_bit_cnt_max)
                NS[CHAN_BS_DONE] = 1'b1;
            else
                NS[READ_CHAN_BS] = 1'b1;
        end

        CS[CHAN_BS_DONE] : begin
            NS[IDLE] = 1'b1;
        end

    endcase
end

// assign outputs based on states

// bit_cnt_reset is high when the bit counter does not need to increment
assign bit_cnt_reset = (CS[IDLE]               == 1'b1)  || 
                       (CS[FINISH_CMD]         == 1'b1)  || 
                       (CS[FINISH_CHAN_BS_CMD] == 1'b1)  || 
                       (CS[READ_CHAN_BS]       == 1'b1)  || 
                       (CS[CHAN_BS_DONE]       == 1'b1);

// chan_bs_bit_cnt_reset is high whenever the bitstream is not being read
assign chan_bs_bit_cnt_reset = !(CS[READ_CHAN_BS] == 1'b1);

// wbuf_rd_en is high when commands are being read from the WBUF
assign wbuf_rd_en = (CS[START_CMD]         == 1'b1)  || 
                    (CS[SEND_CMD]          == 1'b1)  || 
                    (CS[START_CHAN_BS_CMD] == 1'b1)  || 
                    (CS[SEND_CHAN_BS_CMD]  == 1'b1);

// rbuf_wr_en is high when flash responses are being stored in the RBUF
assign rbuf_wr_en = (CS[RECEIVE_RSP] == 1'b1);

// spi_ss is high when there is no active flash transaction
assign spi_ss = (CS[IDLE]              == 1'b1)  ||
                (CS[START_CMD]         == 1'b1)  ||
                (CS[START_CHAN_BS_CMD] == 1'b1)  ||
                (CS[CHAN_BS_DONE]      == 1'b1);

// end_bitstream is high when we are done reading out the channel bitstream
assign end_bitstream = (CS[CHAN_BS_DONE] == 1'b1);


// ====================
// dual port block RAMs
// ====================

// WBUF: for writing to flash
//      32-bit port = input from IPbus
//       1-bit port = output to flash
// RBUF: for reading from flash
//       1-bit port = input from flash
//      32-bit port = output to IPbus

assign wbuf_rd_addr[13:0] = {2'b00,bit_cnt[11:0]};
assign rbuf_wr_addr[13:0] = {2'b00,bit_cnt[11:0]};
assign spi_mosi = wbuf_data_out;
assign rbuf_data_in = spi_miso;

// reverse the bit order of the IPbus data, so that the MSB will be stored in the lowest 
// address of the block RAMs (i.e., the first bit written to or read from flash)

wire [31:0] wbuf_data_in_r;
wire [31:0] rbuf_data_out_r;

genvar i;
for (i=0; i<32; i=i+1)
begin
    assign wbuf_data_in_r[i] = wbuf_data_in[31-i];
    assign rbuf_data_out[i] = rbuf_data_out_r[31-i];
end 

RAMB18E1 #(
    .RAM_MODE("SDP"),
    .READ_WIDTH_A(1),
    .WRITE_WIDTH_B(36)              // 32 data bits, 4 (unused) parity bits
) wbuf (
    .CLKARDCLK(clk),                // 1-bit input: Read clk (port A)
    .CLKBWRCLK(ipb_clk),            // 1-bit input: Write clk (port B)

    .ENARDEN(wbuf_rd_en),           // 1-bit input: Read enable (port A)
    .ENBWREN(wbuf_wr_en),           // 1-bit input: Write enable (port B)
    .WEBWE(4'b1111),                // 4-bit input: byte-wide write enable

    .RSTREGARSTREG(1'b0),           // 1-bit input: A port register set/reset
    .RSTRAMARSTRAM(1'b0),           // 1-bit input: A port set/reset

    // addresses: 32-bit port has depth = 512, 9-bit address (bits [13:5] are used)
    //             1-bit port has depth = 16384 and uses the full 14-bit address
    //            unused bits are connected high
    .ADDRARDADDR(wbuf_rd_addr[13:0]),                   // 14-bit input: Read address
    .ADDRBWRADDR({2'b00, wbuf_wr_addr[6:0], 5'b11111}), // 14-bit input: Write address

    // data in
    .DIBDI(wbuf_data_in_r[31:16]),  // 16-bit input: DI[31:16]
    .DIADI(wbuf_data_in_r[15:0]),   // 16-bit input: DI[15:0]

    // data out
    .DOADO(wbuf_data_out)           // 16-bit output: we only use DO[0]
);

RAMB18E1 #(
    .RAM_MODE("SDP"),
    .READ_WIDTH_A(36),              // 32 data bits, 4 (unused) parity bits
    .WRITE_WIDTH_B(1)
) rbuf (
    .CLKARDCLK(ipb_clk),            // 1-bit input: Read clk (port A)
    .CLKBWRCLK(clk),                // 1-bit input: Write clk (port B)

    .ENARDEN(rbuf_rd_en),           // 1-bit input: Read enable (port A)
    .ENBWREN(rbuf_wr_en),           // 1-bit input: Write enable (port B)
    .WEBWE(4'b1111),                // 4-bit input: byte-wide write enable

    .RSTREGARSTREG(1'b0),           // 1-bit input: A port register set/reset
    .RSTRAMARSTRAM(1'b0),           // 1-bit input: A port set/reset

    // addresses: 32-bit port has depth = 512, 9-bit address (bits [13:5] are used)
    //             1-bit port has depth = 16384 and uses the full 14-bit address
    //            unused bits are connected high
    .ADDRARDADDR({2'b00, rbuf_rd_addr[6:0], 5'b11111}), // 14-bit input: Read address
    .ADDRBWRADDR(rbuf_wr_addr[13:0]),                   // 14-bit input: Write address

    // data in
    .DIBDI({15'b0, rbuf_data_in}),  // 16-bit input: we only use DI[0]

    // data out
    .DOBDO(rbuf_data_out_r[31:16]), // 16-bit output: DO[31:16]
    .DOADO(rbuf_data_out_r[15:0])   // 16-bit output: DO[15:0]
);

endmodule
