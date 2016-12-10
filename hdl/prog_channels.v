`include "flash_addresses.txt"

// State machine for programming the Channel FPGAs using a bitstream stored in the flash memory
//
// Address for the start of the  synchronous channel bitstream is 0x0100_0000
// Address for the start of the asynchronous channel bitstream is 0x012E_0000
//
// To start state machine, assert the 'prog_chan_start' input signal

module prog_channels (
	input  clk,
	input  reset,
    input  async_mode,                // asychronous mode enable
    input  prog_chan_start,           // start signal from IPbus
    output reg c_progb,               // configuration signal to all five channels
    output c_clk,                     // configuration clock to all five channels
    output reg c_din,                 // configuration bitstream to all five channels
    input  [4:0] initb,               // configuration signals from each channel
    input  [4:0] prog_done,           // configuration signals from each channel
    input  bitstream,                 // from SPI flash
    output reg prog_chan_in_progress, // signal to spi_flash_intf
    output reg store_flash_command,   // signal to spi_flash_intf
    output reg [ 6:0] wbuf_address,   // signal to spi_flash_intf
    output reg [31:0] flash_command,  // signal to spi_flash_intf
    output reg [11:0] flash_wr_nBits, // signal to spi_flash_intf
    output reg send_write_command,    // start command to spi_flash_intf
    output reg read_bitstream,        // start command to spi_flash_intf
    input  end_write_command,         // done signal from spi_flash_intf
    input  end_bitstream,             // done signal from spi_flash_intf
    output reg prog_chan_done = 1'b0, // done programming the channels
    output reg async_channels = 1'b0  // flag for if the channels are sync or async
);


assign c_clk = ~clk;

reg [4:0] initb_sync;
reg [4:0] prog_done_sync;

always @(posedge clk) begin
    initb_sync[4:0]     <= initb[4:0];
    prog_done_sync[4:0] <= prog_done[4:0];
end

reg [3:0] counter = 4'h0;
reg [3:0] state   = 4'h0;

parameter IDLE          = 4'd0;
parameter STORE_CMD1    = 4'd1;
parameter LOAD1         = 4'd2;
parameter STORE_CMD2    = 4'd3;
parameter LOAD2         = 4'd4;
parameter STORE_CMD3    = 4'd5;
parameter START         = 4'd6;
parameter INIT1         = 4'd7;
parameter INIT2         = 4'd8;
parameter LOAD3         = 4'd9;
parameter WAIT_FOR_DONE = 4'd10;
parameter STORE_CMD4    = 4'd11;
parameter LOAD4         = 4'd12;
parameter STORE_CMD5    = 4'd13;
parameter LOAD5         = 4'd14;
parameter DONE          = 4'd15;


// CMD1 : WRITE_ENABLE = 1
// CMD2 : WRITE_EXTENDED_ADDRESS_REGISTER = 1
// CMD3 : READ
// CMD4 : WRITE_ENABLE = 1
// CMD5 : WRITE_EXTENDED_ADDRESS_REGISTER = 0

always @(posedge clk) begin
    if (reset) begin
        c_progb <= 1'b1;
        c_din   <= 1'b0;

        prog_chan_in_progress <=  1'b0;
        store_flash_command   <=  1'b0;
        read_bitstream        <=  1'b0;
        send_write_command    <=  1'b0;
        wbuf_address[6:0]     <=  7'd0;
        flash_command[31:0]   <= 32'd0;
        flash_wr_nBits[11:0]  <= 12'd0;
        counter[3:0]          <=  4'd0;

        state <= IDLE;
    end
    else begin
        case (state)
            // idle state
            IDLE : begin
                c_progb <= 1'b1;
                c_din   <= 1'b1;

                prog_chan_in_progress <=  1'b0;
                store_flash_command   <=  1'b0;
                read_bitstream        <=  1'b0;
                send_write_command    <=  1'b0;
                wbuf_address[6:0]     <=  7'd0;
                flash_command[31:0]   <= 32'd0;
                flash_wr_nBits[11:0]  <= 12'd0;

                if (prog_chan_start)
                    state <= STORE_CMD1;
                else
                    state <= IDLE;
            end

            // store command in WBUF
            STORE_CMD1 : begin
                c_progb <= 1'b1;
                c_din   <= 1'b1;

                prog_chan_in_progress <=  1'b1;
                store_flash_command   <=  1'b1; // store write command in WBUF
                read_bitstream        <=  1'b0;
                prog_chan_done        <=  1'b0;
                send_write_command    <=  1'b0;
                wbuf_address[6:0]     <=  7'd0;
                flash_command[31:0]   <= 32'h0600_0000; // WRITE_ENABLE = 1
                flash_wr_nBits[11:0]  <= 12'd0;

                state <= LOAD1;
            end

            // initiate command to SPI flash
            LOAD1 : begin
                c_progb <= 1'b1;
                c_din   <= 1'b1;

                prog_chan_in_progress <=  1'b1;
                store_flash_command   <=  1'b0;
                read_bitstream        <=  1'b0;
                prog_chan_done        <=  1'b0;
                wbuf_address[6:0]     <=  7'd0;
                flash_command[31:0]   <= 32'd0;
                flash_wr_nBits[11:0]  <= 12'd7;

                if (end_write_command) begin
                    send_write_command <= 1'b0;
                    state <= STORE_CMD2;
                end
                else begin
                    send_write_command <= 1'b1; // initiate write command to SPI flash
                    state <= LOAD1;
                end
            end

            // store command in WBUF
            STORE_CMD2 : begin
                c_progb <= 1'b1;
                c_din   <= 1'b1;

                prog_chan_in_progress <=  1'b1;
                store_flash_command   <=  1'b1; // store write command in WBUF
                read_bitstream        <=  1'b0;
                prog_chan_done        <=  1'b0;
                send_write_command    <=  1'b0;
                wbuf_address[6:0]     <=  7'd0;
                flash_command[31:0]   <= 32'hC501_0000; // WRITE_EXTENDED_ADDRESS_REGISTER = 1
                flash_wr_nBits[11:0]  <= 12'd0;
                
                state <= LOAD2;
            end

            // initiate command to SPI flash
            LOAD2 : begin
                c_progb <= 1'b1;
                c_din   <= 1'b1;

                prog_chan_in_progress <=  1'b1;
                store_flash_command   <=  1'b0;
                read_bitstream        <=  1'b0;
                prog_chan_done        <=  1'b0;
                wbuf_address[6:0]     <=  7'd0;
                flash_command[31:0]   <= 32'd0;
                flash_wr_nBits[11:0]  <= 12'd15;

                if (end_write_command) begin
                    send_write_command <= 1'b0;
                    state <= STORE_CMD3;
                end
                else begin
                    send_write_command <= 1'b1; // initiate write command to SPI flash
                    state <= LOAD2;
                end
            end

            // store command in WBUF
            STORE_CMD3 : begin
                c_progb <= 1'b1;
                c_din   <= 1'b1;

                prog_chan_in_progress <=  1'b1;
                store_flash_command   <=  1'b1; // store read command in WBUF
                read_bitstream        <=  1'b0;
                prog_chan_done        <=  1'b0;
                send_write_command    <=  1'b0;
                wbuf_address[6:0]     <=  7'd0;
                flash_wr_nBits[11:0]  <= 12'd0;

                if (~async_mode)
                    flash_command[31:0] <= {8'h03, `CHANNEL_FLASH_ADDR}; // READ, SYNCHRONOUS MODE
                else
                    flash_command[31:0] <= {8'h03, `ASYNC_FLASH_ADDR};   // READ, ASYNCHRONOUS MODE

                state <= START;
            end
            
            START : begin
                c_progb <= 1'b0;
                c_din   <= 1'b1;

                prog_chan_in_progress <=  1'b1;
                store_flash_command   <=  1'b0;
                read_bitstream        <=  1'b0;
                prog_chan_done        <=  1'b0;
                send_write_command    <=  1'b0;
                wbuf_address[6:0]     <=  7'd0;
                flash_command[31:0]   <= 32'd0;
                flash_wr_nBits[11:0]  <= 12'd0;
                counter[3:0]          <=  4'h0;

                if (initb_sync[4:0] == 5'b00000)
                    state <= INIT1;
                else
                    state <= START;
            end

            INIT1 : begin
                c_progb <= 1'b0; // progb still low (required Tprogram >= 250 ns)
                c_din   <= 1'b1;

                prog_chan_in_progress <=  1'b1;
                store_flash_command   <=  1'b0;
                read_bitstream        <=  1'b0;
                prog_chan_done        <=  1'b0;
                send_write_command    <=  1'b0;
                wbuf_address[6:0]     <=  7'd0;
                flash_command[31:0]   <= 32'd0;
                flash_wr_nBits[11:0]  <= 12'd0;

                if (counter[3:0] == 4'hf)
                    state <= INIT2;
                else begin
                    counter[3:0] <= counter[3:0] + 1'b1;
                    state <= INIT1;
                end
            end

            INIT2 : begin
                c_progb <= 1'b1; // release progb back to normal high state
                c_din   <= 1'b1;

                prog_chan_in_progress <=  1'b1;
                store_flash_command   <=  1'b0;
                read_bitstream        <=  1'b0;
                prog_chan_done        <=  1'b0;
                send_write_command    <=  1'b0;
                wbuf_address[6:0]     <=  7'd0;
                flash_command[31:0]   <= 32'd0;
                flash_wr_nBits[11:0]  <= 12'd0;

                if (initb_sync[4:0] == 5'b11111)
                    state <= LOAD3;
                else
                    state <= INIT2;
            end

            // initiate command to SPI flash
            LOAD3 : begin
                c_progb <= 1'b1;
                c_din   <= bitstream;

                prog_chan_in_progress <=  1'b1;
                store_flash_command   <=  1'b0;
                read_bitstream        <=  1'b1; // initiate read command to SPI flash
                prog_chan_done        <=  1'b0;
                send_write_command    <=  1'b0;
                wbuf_address[6:0]     <=  7'd0;
                flash_command[31:0]   <= 32'd0;
                flash_wr_nBits[11:0]  <= 12'd0;

                if (end_bitstream)
                    state <= WAIT_FOR_DONE;
                else
                    state <= LOAD3;
            end

            WAIT_FOR_DONE : begin
                c_progb <= 1'b1;
                c_din   <= 1'b1;

                prog_chan_in_progress <=  1'b1;
                store_flash_command   <=  1'b0;
                read_bitstream        <=  1'b0;
                prog_chan_done        <=  1'b0;
                send_write_command    <=  1'b0;
                wbuf_address[6:0]     <=  7'd0;
                flash_command[31:0]   <= 32'd0;
                flash_wr_nBits[11:0]  <= 12'd0;

                if (prog_done_sync[4:0] == 5'b11111)
                    state <= STORE_CMD4;
                else
                    state <= WAIT_FOR_DONE;
            end

            // store command in WBUF
            STORE_CMD4 : begin
                c_progb <= 1'b1;
                c_din   <= 1'b1;

                prog_chan_in_progress <=  1'b1;
                store_flash_command   <=  1'b1; // store write command in WBUF
                read_bitstream        <=  1'b0;
                prog_chan_done        <=  1'b0;
                send_write_command    <=  1'b0;
                wbuf_address[6:0]     <=  7'd0;
                flash_command[31:0]   <= 32'h0600_0000; // WRITE_ENABLE = 1
                flash_wr_nBits[11:0]  <= 12'd0;
                
                state <= LOAD4;
            end

            // initiate command to SPI flash
            LOAD4 : begin
                c_progb <= 1'b1;
                c_din   <= 1'b1;

                prog_chan_in_progress <=  1'b1;
                store_flash_command   <=  1'b0;
                read_bitstream        <=  1'b0;
                prog_chan_done        <=  1'b0;
                wbuf_address[6:0]     <=  7'd0;
                flash_command[31:0]   <= 32'd0;
                flash_wr_nBits[11:0]  <= 12'd7;

                if (end_write_command) begin
                    send_write_command <= 1'b0;
                    state <= STORE_CMD5;
                end
                else begin
                    send_write_command <= 1'b1; // initiate write command to SPI flash
                    state <= LOAD4;
                end
            end

            // store command in WBUF
            STORE_CMD5 : begin
                c_progb <= 1'b1;
                c_din   <= 1'b1;

                prog_chan_in_progress <=  1'b1;
                store_flash_command   <=  1'b1; // store write command in WBUF
                read_bitstream        <=  1'b0;
                prog_chan_done        <=  1'b0;
                send_write_command    <=  1'b0;
                wbuf_address[6:0]     <=  7'd0;
                flash_command[31:0]   <= 32'hC500_0000; // WRITE_EXTENDED_ADDRESS_REGISTER = 0
                flash_wr_nBits[11:0]  <= 12'd0;
                
                state <= LOAD5;
            end

            // initiate command to SPI flash
            LOAD5 : begin
                c_progb <= 1'b1;
                c_din   <= 1'b1;

                prog_chan_in_progress <=  1'b1;
                store_flash_command   <=  1'b0;
                read_bitstream        <=  1'b0;
                prog_chan_done        <=  1'b0;
                send_write_command    <=  1'b1; // initiate write command to SPI flash
                wbuf_address[6:0]     <=  7'd0;
                flash_command[31:0]   <= 32'd0;
                flash_wr_nBits[11:0]  <= 12'd15;
                
                if (end_write_command)
                    state <= DONE;
                else
                    state <= LOAD5;
            end

            // done state
            DONE : begin
                c_progb <= 1'b1;
                c_din   <= 1'b1;

                prog_chan_in_progress <=  1'b0;
                store_flash_command   <=  1'b0;
                read_bitstream        <=  1'b0;
                prog_chan_done        <=  1'b1; // done programming channels
                send_write_command    <=  1'b0;
                wbuf_address[6:0]     <=  7'd0;
                flash_command[31:0]   <= 32'd0;
                flash_wr_nBits[11:0]  <= 12'd0;

                if (~async_mode)
                    async_channels <= 1'b0; //  synchronous channel image loaded
                else
                    async_channels <= 1'b1; // asynchronous channel image loaded

                if (~prog_chan_start) begin
                    state <= IDLE;
                end
                else
                    state <= DONE; // stay here until 'prog_chan_start' signal is negated
            end
        endcase
    end
end

endmodule
