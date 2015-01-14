`timescale 1ns / 1ps


module prog_channels(
	input clk,
	(* mark_debug = "true" *) input reset,
    input prog_chan_start,
    (* mark_debug = "true" *) output reg c_progb,         // configuration signal to all five channels
    output c_clk,           // configuration clock to all five channels
    (* mark_debug = "true" *) output reg c_din,           // configuration bitstream to all five channels
    input [4:0] initb,      // configuration signals from each channel
    input [4:0] prog_done,  // configuration signals from each channel
    input bitstream,        // from SPI flash
    output reg read_bitstream, // start command to spi_flash_intf
    input end_bitstream     // done signal from spi_flash_intf
);

assign c_clk = !clk;

(* mark_debug = "true" *) reg [4:0] initb_sync;
(* mark_debug = "true" *) reg [4:0] prog_done_sync;

always @ (posedge clk)
begin
    initb_sync[4:0] <= initb[4:0];
    prog_done_sync[4:0] <= prog_done[4:0];
end

parameter IDLE = 3'b000;
parameter START = 3'b001;
parameter INIT1 = 3'b010;
parameter INIT2 = 3'b011;
parameter LOAD = 3'b100;
parameter WAIT_FOR_DONE = 3'b101;
parameter DONE = 3'b110;

(* mark_debug = "true" *) reg [2:0] state = IDLE;

(* mark_debug = "true" *) reg [3:0] counter = 4'h0;


always @ (posedge clk)
begin
    if (reset)
        begin
            c_progb <= 1'b1;
            c_din <= 1'b0;
            state <= IDLE;
        end
    else
        begin
            case (state)
                IDLE : begin
                    c_progb <= 1'b1;
                    c_din <= 1'b1;
                    read_bitstream <= 1'b0;
                    if (prog_chan_start)
                        state <= START;
                    else
                        state <= IDLE;
                end
                
                START : begin
                    c_progb <= 1'b0;
                    c_din <= 1'b1;
                    read_bitstream <= 1'b0;
                    counter <= 4'h0;
                    if (initb_sync[4:0] == 5'b00000)
                        state <= INIT1;
                    else
                        state <= START;                
                end
                
                INIT1 : begin
                    c_progb <= 1'b0; // progb still low (required Tprogram >= 250 ns)
                    c_din <= 1'b1;
                    read_bitstream <= 1'b0;
                    if (counter[3:0] == 4'hF)
                        state <= INIT2;
                    else
                        begin
                            counter[3:0] <= counter[3:0] + 1'h1;
                            state <= INIT1;
                        end
                end

                INIT2 : begin
                    c_progb <= 1'b1; // release progb back to normal high state
                    c_din <= 1'b1;
                    read_bitstream <= 1'b0;
                    if (initb_sync[4:0] == 5'b11111)
                        state <= LOAD;
                    else
                        state <= INIT2;
                end

                LOAD : begin
                    c_progb <= 1'b1;
                    c_din <= bitstream;
                    read_bitstream <= 1'b1; // initiate read command to SPI flash
                    if (end_bitstream)
                        state <= WAIT_FOR_DONE;
                    else
                        state <= LOAD;
                end

                WAIT_FOR_DONE : begin
                    c_progb <= 1'b1;
                    c_din <= 1'b1;
                    read_bitstream <= 1'b0;
                    if (prog_done == 5'b11111)
                        state <= DONE;
                    else
                        state <= WAIT_FOR_DONE;
                end

                DONE : begin
                    c_progb <= 1'b1;
                    c_din <= 1'b1;
                    state <= DONE; // stay here forever (or until reset)
                end

            endcase
        end
end




endmodule

