`include "icap_values.txt"
`include "flash_addresses.txt"

// Module to re-program the FPGA from flash by issuing an IPROG command through the ICAP.
//
// Which image is loaded is selected by a 3-bit trigger from IPbus (one-hot: [0] golden image,
// [1] regular master image, [2] self-triggering master image) or by the front panel switch
// (switch in the 'golden' position forces the golden image).
//
// Robustness, added v6.6.0.  An IPROG with a bad or missing boot address ends in a CRC / ID
// error and a fallback to the golden image, and the original logic had three ways to get there:
//   - the front panel switch was a raw, unsynchronised pin feeding the trigger mux, so a single
//     50 MHz cycle of 'golden' on it, e.g. while the I/O settles right after configuration, sent
//     the freshly loaded master image straight back to golden;
//   - the state machine left IDLE on any non-zero trigger but re-sampled the trigger four cycles
//     later to choose the address, with no default, so a trigger that had vanished by then left
//     the previous ICAP word (the WBSTAR command itself) on the bus as the boot address;
//   - nothing stopped a request in the first moments after configuration.
// Now the switch is synchronised and debounced (SW_DEBOUNCE_CYCLES), every request must be held
// steadily for TRIGGER_QUALIFY_CYCLES before it is acted on, the selection is latched once when
// the request qualifies, nothing is accepted for STARTUP_HOLDOFF_CYCLES after reset, and the
// command sequence always carries a valid address.

module reprog #(
    parameter STARTUP_HOLDOFF_CYCLES = 26,  // 2^26 cycles at 50 MHz = 1.3 s after reset before any request is honoured
    parameter TRIGGER_QUALIFY_CYCLES = 16,  // 2^16 cycles = 1.3 ms of steady request before IPROG
    parameter SW_DEBOUNCE_CYCLES     = 19   // 2^19 cycles = 10 ms of steady switch level before it is believed
) (
    input clk,              // 50 MHz
    input clkb,             // 50 MHz, inverted (ICAP clock)
    input reset,
    input [2:0] ipbus_trigger, // from IPbus, already synchronised to clk: [0] golden, [1] master, [2] self-trigger master
    input fp_sw_master,     // raw front panel switch: 1 = run the master image, 0 = stay in / return to the golden image
    output reprog_done
);

// ===============
// declare signals
// ===============

wire clk_180;
assign clk_180 = clkb;
wire [31:0] ICAP_input;

reg ICAP_enable;
reg [31:0] ICAP_value; // determined by state machine
parameter GOLDEN  = 2'd0;
parameter MASTER  = 2'd1;
parameter STMSTR  = 2'd2;

// ===============================================================
// instantiate ICAPE2 primitive to access FPGA configuration logic
// ===============================================================

// ICAPE2: Internal Configuration Access Port
//		   7 Series
// Xilinx HDL Libraries Guide, version 13.4

ICAPE2 #(
	.DEVICE_ID(32'h03651093),    // specifies the pre-programmed Device ID value to be used for simulation purposes
	.ICAP_WIDTH("X32"),        // specifies the input and output data width
	.SIM_CFG_FILE_NAME("NONE") // specifies the Raw Bitstream (RBT) file to be parsed by the simulation model
) ICAPE2_inst (
	.O(),               // 32-bit output: Configuration data output bus (not used here)
	.CLK(clk_180),      //  1-bit  input: Clock Input
	.CSIB(ICAP_enable), //  1-bit  input: Active-Low ICAP Enable
	.I(ICAP_input),     // 32-bit  input: Configuration data input bus
	.RDWRB(1'b0)        //  1-bit  input: Read/Write Select input (tie low to select "write")
);

// End of ICAPE2_inst instantiation


// ====================================
// create bit ordering required by ICAP
// ====================================

assign ICAP_input[31] = ICAP_value[24];
assign ICAP_input[30] = ICAP_value[25];
assign ICAP_input[29] = ICAP_value[26];
assign ICAP_input[28] = ICAP_value[27];
assign ICAP_input[27] = ICAP_value[28];
assign ICAP_input[26] = ICAP_value[29];
assign ICAP_input[25] = ICAP_value[30];
assign ICAP_input[24] = ICAP_value[31];

assign ICAP_input[23] = ICAP_value[16];
assign ICAP_input[22] = ICAP_value[17];
assign ICAP_input[21] = ICAP_value[18];
assign ICAP_input[20] = ICAP_value[19];
assign ICAP_input[19] = ICAP_value[20];
assign ICAP_input[18] = ICAP_value[21];
assign ICAP_input[17] = ICAP_value[22];
assign ICAP_input[16] = ICAP_value[23];

assign ICAP_input[15] = ICAP_value[ 8];
assign ICAP_input[14] = ICAP_value[ 9];
assign ICAP_input[13] = ICAP_value[10];
assign ICAP_input[12] = ICAP_value[11];
assign ICAP_input[11] = ICAP_value[12];
assign ICAP_input[10] = ICAP_value[13];
assign ICAP_input[ 9] = ICAP_value[14];
assign ICAP_input[ 8] = ICAP_value[15];

assign ICAP_input[7]  = ICAP_value[0];
assign ICAP_input[6]  = ICAP_value[1];
assign ICAP_input[5]  = ICAP_value[2];
assign ICAP_input[4]  = ICAP_value[3];
assign ICAP_input[3]  = ICAP_value[4];
assign ICAP_input[2]  = ICAP_value[5];
assign ICAP_input[1]  = ICAP_value[6];
assign ICAP_input[0]  = ICAP_value[7];


// =================================================
// front panel switch: synchronise, then debounce
// =================================================

(* ASYNC_REG = "TRUE" *) reg sw_sync1, sw_sync2;
always @(posedge clk) begin
    sw_sync1 <= fp_sw_master;
    sw_sync2 <= sw_sync1;
end

// sw_master is only updated after the synchronised level has been steady for 2^SW_DEBOUNCE_CYCLES.
// It comes out of reset in the 'master' position so that a freshly configured master image can
// never be sent back to golden by the switch before the switch has been read properly.
reg sw_master = 1'b1;
reg [SW_DEBOUNCE_CYCLES:0] sw_cntr;
always @(posedge clk) begin
    if (reset) begin
        sw_master <= 1'b1;
        sw_cntr   <= 0;
    end
    else if (sw_sync2 == sw_master) begin
        sw_cntr <= 0;
    end
    else if (sw_cntr[SW_DEBOUNCE_CYCLES]) begin
        sw_master <= sw_sync2;
        sw_cntr   <= 0;
    end
    else begin
        sw_cntr <= sw_cntr + 1;
    end
end

// =================================================
// start-up hold-off: ignore everything for a while
// =================================================

reg [STARTUP_HOLDOFF_CYCLES:0] holdoff_cntr;
wire holdoff_done;
assign holdoff_done = holdoff_cntr[STARTUP_HOLDOFF_CYCLES];
always @(posedge clk) begin
    if (reset)
        holdoff_cntr <= 0;
    else if (!holdoff_done)
        holdoff_cntr <= holdoff_cntr + 1;
end

// =================================================
// the request, and its qualification
// =================================================

// the switch in the 'golden' position is a request for the golden image; otherwise IPbus decides
wire [2:0] request;
assign request = sw_master ? ipbus_trigger : 3'b001;

// request must be exactly one image, unchanged for 2^TRIGGER_QUALIFY_CYCLES cycles
reg  [2:0] request_d;
reg  [TRIGGER_QUALIFY_CYCLES:0] qualify_cntr;
wire request_valid;
assign request_valid = holdoff_done && (request == request_d) &&
                       ((request == 3'b001) || (request == 3'b010) || (request == 3'b100));
wire request_qualified;
assign request_qualified = qualify_cntr[TRIGGER_QUALIFY_CYCLES];
always @(posedge clk) begin
    request_d <= request;
    if (reset || !request_valid)
        qualify_cntr <= 0;
    else if (!request_qualified)
        qualify_cntr <= qualify_cntr + 1;
end

// ==========================================
// state machine for sending commands to ICAP
// ==========================================

parameter IDLE       = 4'd0;
parameter SEND_WORD1 = 4'd1;
parameter SEND_WORD2 = 4'd2;
parameter SEND_WORD3 = 4'd3;
parameter SEND_WORD4 = 4'd4;
parameter SEND_WORD5 = 4'd5;
parameter SEND_WORD6 = 4'd6;
parameter SEND_WORD7 = 4'd7;
parameter SEND_WORD8 = 4'd8;
parameter DONE       = 4'd9;

reg [3:0] state = IDLE;
reg [23:0] boot_address;   // latched when the request qualifies; the only thing SEND_WORD5 uses

always @(posedge clk) begin
    if (reset) begin
    	ICAP_value   <= `ICAP_DUMMY_WORD;
    	ICAP_enable  <= 1'b1; // disabled
        boot_address <= `GOLDEN_FLASH_ADDR;
        state        <= IDLE;
    end
    else begin
        case (state)
            IDLE : begin
                ICAP_value  <= `ICAP_DUMMY_WORD;
                ICAP_enable <= 1'b1; // disabled

                if (request_qualified) begin
                    // latch the address now; the request is not looked at again
                    case (1'b1)
                        request[GOLDEN] : boot_address <= `GOLDEN_FLASH_ADDR;
                        request[MASTER] : boot_address <= `MASTER_FLASH_ADDR;
                        request[STMSTR] : boot_address <= `STMSTR_FLASH_ADDR;
                        default         : boot_address <= `GOLDEN_FLASH_ADDR;
                    endcase
                    state <= SEND_WORD1;
                end
                else begin
                    state <= IDLE;
                end
            end

            SEND_WORD1 : begin
                ICAP_value  <= `ICAP_DUMMY_WORD;
                ICAP_enable <= 1'b0; // enabled
                state <= SEND_WORD2;
            end

            SEND_WORD2 : begin
                ICAP_value  <= `ICAP_SYNC_WORD;
                ICAP_enable <= 1'b0; // enabled
                state <= SEND_WORD3;
            end

            SEND_WORD3 : begin
                ICAP_value  <= `ICAP_NO_OP;
                ICAP_enable <= 1'b0; // enabled
                state <= SEND_WORD4;
            end

            SEND_WORD4 : begin
                ICAP_value  <= `ICAP_WRITE_WBSTAR;
                ICAP_enable <= 1'b0; // enabled
                state <= SEND_WORD5;
            end

            SEND_WORD5 : begin
                ICAP_value  <= {8'h00, boot_address};
                ICAP_enable <= 1'b0; // enabled
                state <= SEND_WORD6;
            end

            SEND_WORD6 : begin
                ICAP_value  <= `ICAP_WRITE_CMD;
                ICAP_enable <= 1'b0; // enabled
                state <= SEND_WORD7;
            end

            SEND_WORD7 : begin
                ICAP_value  <= `ICAP_IPROG;
                ICAP_enable <= 1'b0; // enabled
                state <= SEND_WORD8;
            end

            SEND_WORD8 : begin
                ICAP_value  <= `ICAP_NO_OP;
                ICAP_enable <= 1'b0; // enabled
                state <= DONE;
            end

            DONE : begin
                ICAP_value  <= `ICAP_NO_OP;
                ICAP_enable <= 1'b1; // disabled
                state <= DONE; // stay here (except not, because FPGA should re-configure now)
            end

            default : begin
                ICAP_value  <= `ICAP_DUMMY_WORD;
                ICAP_enable <= 1'b1; // disabled
                state <= IDLE;
            end
        endcase
    end
end

assign reprog_done = (state == DONE);

endmodule
