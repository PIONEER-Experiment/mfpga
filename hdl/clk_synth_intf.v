`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/28/2014 10:37:09 AM
// Design Name: 
// Module Name: clk_synth_intf
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module clk_synth_intf(
    input clk,
    input reset,
//    input los1,
//    input los0,
//    input ld,
    output dclk,
    output ddat,
    output reg dlen,
    output goe,
    output sync,
    output [2:0] debug 
);

reg resetS;
//reg los1S;
//reg los0S;
//reg ldS;

//*************************************************************************
// static assignments
//*************************************************************************
assign dclk = slow_clk_180;
assign goe = 1'b1;
assign sync = 1'b1;

//*************************************************************************
// synchronize state machine inputs
//*************************************************************************
always @ (posedge slow_clk)
begin
    resetS <= reset;
//    los1S <= los1;
//    los0S <= los0;
//    ldS <= ld;
end

//*************************************************************************
// generate a low speed clock
//*************************************************************************
reg [2:0] clk_cnt;
wire slow_clk;
wire slow_clk_180;

always @ (posedge clk)
begin
	clk_cnt[2:0] <= clk_cnt[2:0] + 1'b1;
end	

assign slow_clk = clk_cnt[2];
assign slow_clk_180 = !slow_clk;


//*************************************************************************
// shift register with counter, LSB wired to output of module
//
// sreg_strobe - starts the shifting mechanism
// payload - what will be shifted
// sreg_ready - active high status signal
//*************************************************************************
reg sreg_strobe;
reg [31:0] sreg;
wire [31:0] sreg_payload;
reg [5:0] sreg_cnt = 6'b100000;
reg sreg_ready;
parameter IDLE = 2'b00;
parameter LOAD = 2'b01;
parameter SHIFTING = 2'b10;

reg [1:0] shift_state = IDLE;

reg [5:0] sreg_cnt = 6'b000000;
reg sreg_cnt_ena;
reg sreg_cnt_reset;

wire sreg_cnt_max;
assign sreg_cnt_max = (sreg_cnt == 6'b011110) ? 1'b1 : 1'b0;

always @ (posedge slow_clk)
begin
    if (sreg_cnt_reset)
        sreg_cnt[5:0] <= 6'b000000;
    else if (sreg_cnt_ena)
        sreg_cnt[5:0] <= sreg_cnt[5:0] + 6'b000001; 
    else
        sreg_cnt[5:0] <= sreg_cnt[5:0];
end

reg sreg_load;

always @ (posedge slow_clk)
begin
	if (sreg_load)
		sreg[31:0] <= synth_reg[31:0];
	else
		sreg[31:0] <= {sreg[30:0],1'b0};		
end

assign ddat = sreg[31];

always @ (posedge slow_clk)
begin
    if (resetS)
        begin
            sreg_load <= 1'b1;
            sreg_cnt_reset <= 1'b1;
            sreg_cnt_ena <= 1'b0;
            dlen <= 1'b1;
            sreg_ready <= 1'b1;
            shift_state <= IDLE;
        end
    else
        begin
            case (shift_state)
                IDLE : begin
                    sreg_cnt_reset <= 1'b1;
                    sreg_cnt_ena <= 1'b0;
                    sreg_load <= 1'b1;                    
                    dlen <= 1'b1;
                    sreg_ready <= 1'b1;
                    if (sreg_strobe)
                        shift_state <= LOAD;
                    else
                        shift_state <= IDLE;
                end
                
                LOAD : begin
                    sreg_cnt_reset <= 1'b1;
                    sreg_cnt_ena <= 1'b0;
                    sreg_load <= 1'b1;                    
                    dlen <= 1'b1;
                    sreg_ready <= 1'b0;
                    if (sreg_strobe)
                        shift_state <= LOAD;
                    else
                        shift_state <= SHIFTING;                
                end
                
                SHIFTING : begin
                    sreg_cnt_reset <= 1'b0;
                    sreg_cnt_ena <= 1'b1;
                    sreg_load <= 1'b0;
                    dlen <= 1'b0;
                    sreg_ready <= 1'b0;
                    if (sreg_cnt_max)
                        shift_state <= IDLE;
                    else
                        shift_state <= SHIFTING;
                end
            endcase
        end                
end

//*************************************************************************
// array of registers
//*************************************************************************
reg [4:0] synth_reg_addr;
reg [31:0] synth_reg;

always @ (posedge slow_clk)
begin
    case (synth_reg_addr[4:0])
        5'b00000 : synth_reg[31:0] = 32'h00000017;
	5'b00001 : synth_reg[31:0] = 32'h01010000;
	5'b00010 : synth_reg[31:0] = 32'h01010001;
        5'b00011 : synth_reg[31:0] = 32'h01010002;
        5'b00100 : synth_reg[31:0] = 32'h01010003;
        5'b00101 : synth_reg[31:0] = 32'h01010004;
        5'b00110 : synth_reg[31:0] = 32'h00000005;
        5'b00111 : synth_reg[31:0] = 32'h08000076;
        5'b01000 : synth_reg[31:0] = 32'h00000007;
        5'b01001 : synth_reg[31:0] = 32'h00000008;
        5'b01010 : synth_reg[31:0] = 32'h00a22a09;
        5'b01011 : synth_reg[31:0] = 32'h0152000a;
        5'b01100 : synth_reg[31:0] = 32'h00650ccb;
        5'b01101 : synth_reg[31:0] = 32'h200200ac;
        5'b01110 : synth_reg[31:0] = 32'h0a14000d;
        5'b01111 : synth_reg[31:0] = 32'h1900004e;
        5'b10000 : synth_reg[31:0] = 32'h108000ff;
    endcase
end

//*************************************************************************
// automatic configuration of all of the synth registers
//*************************************************************************
parameter S1 = 3'b000;
parameter S2 = 3'b001;
parameter S3 = 3'b010;
parameter S4 = 3'b011;
parameter S5 = 3'b100;

reg [2:0] synth_state = S1;


//************************************************
// loop counter to clock out all registers
//************************************************

reg [5:0] loop_cnt = 6'b000000;
reg loop_cnt_ena;
reg loop_cnt_reset;

wire loop_cnt_max;
assign loop_cnt_max = (loop_cnt == 6'b010001) ? 1'b1 : 1'b0;


always @ (posedge slow_clk)
begin
    if (loop_cnt_reset)
        loop_cnt[5:0] <= 6'b000000;
    else if (loop_cnt_ena)
        loop_cnt[5:0] <= loop_cnt[5:0] + 6'b000001; 
    else
        loop_cnt[5:0] <= loop_cnt[5:0];
end

//************************************************
// state machine to wite the registers
//************************************************
always @ (posedge slow_clk)
begin
	if (resetS)
        begin
            synth_reg_addr[4:0] <= 5'b00000;
            sreg_strobe <= 1'b0;
            loop_cnt_ena <= 1'b0;
            loop_cnt_reset <= 1'b1;
            synth_state <= S1;
        end
	else
	   begin
        case (synth_state)
            // idle
                S1 : begin
                    synth_reg_addr[4:0] <= synth_reg_addr[4:0];
                    sreg_strobe <= 1'b0;
                    loop_cnt_ena <= 1'b0;
                    loop_cnt_reset <= 1'b0; //this makes the loop only fire once
                    if (!loop_cnt_max)						
                         synth_state <= S2;
                    else
                         synth_state <= S1;
                end
        
            // count
             S2 : begin
                synth_reg_addr[4:0] <= synth_reg_addr[4:0];
                sreg_strobe <= 1'b0;
                loop_cnt_ena <= 1'b1;
                loop_cnt_reset <= 1'b0;
                synth_state <= S3;
            end
                           
            // load
            S3 : begin
                synth_reg_addr[4:0] <= synth_reg_addr[4:0];
                sreg_strobe <= 1'b1;
                loop_cnt_ena <= 1'b0;
                loop_cnt_reset <= 1'b0;
                if (sreg_ready)              // wait here until the shift reg starts shifting						
    			     synth_state <= S3;
    			else
    			     synth_state <= S4;
    		end
    		
    		// shift
            S4 : begin
                synth_reg_addr[4:0] <= synth_reg_addr[4:0];
                sreg_strobe <= 1'b0;
                loop_cnt_ena <= 1'b0;
                loop_cnt_reset <= 1'b0;                
                if (sreg_ready)             // wait here until the shift reg stops shifting
                    synth_state <= S5;
                else
                    synth_state <= S4;
            end
            
            // increment
            S5 : begin
                synth_reg_addr[4:0] <= synth_reg_addr[4:0] + 1'b1;
                sreg_strobe <= 1'b0;
                loop_cnt_ena <= 1'b0;
                loop_cnt_reset <= 1'b0;
                synth_state <= S1;
            end
       	 endcase
        end
end

//*************************************************************************
// debug assignments
//*************************************************************************
assign debug[2] = slow_clk;
assign debug[1] = sreg_strobe;
assign debug[0] = loop_cnt[0];
 

endmodule
