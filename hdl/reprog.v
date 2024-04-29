`include "icap_values.txt"
`include "flash_addresses.txt"

// Module to re-program FPGA from flash by issuing an IPROG command

module reprog (
	input clk,
	input reset,
	input [2:0] trigger // trigger[0] for golden image, trigger[1] for regular master image
);

// ===============
// declare signals
// ===============

wire clk_180 = ~clk;
wire [31:0] ICAP_input;

reg ICAP_enable;
reg [31:0] ICAP_value; // determined by state machine
//reg bitstream_select;  // 0 for golden image, 1 for regular master image
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
	.DEVICE_ID(0'h3651093),    // specifies the pre-programmed Device ID value to be used for simulation purposes
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

always @(posedge clk) begin
    if (reset) begin
    	ICAP_value  <= `ICAP_DUMMY_WORD;
    	ICAP_enable <= 1'b1; // disabled
        state <= IDLE;
    end
    else begin
        case (state)
            IDLE : begin
                ICAP_value  <= `ICAP_DUMMY_WORD;
                ICAP_enable <= 1'b1; // disabled

                if ( trigger == 3'b0 ) begin
                    state <= IDLE;
                end
                else begin
                    state <= SEND_WORD1;
                end
//                if (trigger[0]) begin
//                    bitstream_select <= 1'b0; // select golden image
//                    state <= SEND_WORD1;
//                end
//                else if (trigger[1]) begin
//                    bitstream_select <= 1'b1; // select regular master image
//                    state <= SEND_WORD1;
//                end
//                else begin
//                    state <= IDLE;
//                end
//            end

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
                case (1'b1)
                    trigger[GOLDEN] : begin
                        ICAP_value <= {8'h00, `GOLDEN_FLASH_ADDR};
                    end
                    trigger[MASTER] : begin
                        ICAP_value <= {8'h00, `MASTER_FLASH_ADDR};
                    end
                    trigger[STMSTR] : begin
                        ICAP_value <= {8'h00, `STMSTR_FLASH_ADDR};
                    end
                endcase
                //if (bitstream_select == 0)
                //    ICAP_value <= {8'h00, `GOLDEN_FLASH_ADDR};
                //else
                //    ICAP_value <= {8'h00, `MASTER_FLASH_ADDR};
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
        endcase
    end
end

endmodule
