`timescale 1ns / 1ps

// Based on Nate's ADC interface. Right now only suitable for reading the channel bitstream. Needs to be cleaned up & turned into a more general interface. 

// TODO: figure out miso synchronization delay

module spi_flash_intf(
	input clk,
    ipb_clk,
	(* mark_debug = "true" *) input reset,
	input [31:0] data_in,
	output [31:0] data_out,
	output spi_clk,
	output spi_mosi,
	input spi_miso,
	output reg spi_ss,
    input read_bitstream,
    output reg end_bitstream
);


(* mark_debug = "true" *) reg test = 1'b0;  
(* mark_debug = "true" *) reg test_clk = 1'b0;

always @ (posedge clk)
begin
    if (reset)
    begin
        test <= 1'b1;
        test_clk <= !test_clk;
    end
end

assign spi_clk = !clk;

//*************************************************************************
// dual shift register with counter, MSB wired to output of module
//  
// sreg_strobe - starts the shifting mechanism
// payload - what will be shifted
// sreg_ready - active high status signal
//*************************************************************************
(* mark_debug = "true" *) reg sreg_strobe;
(* mark_debug = "true" *) reg [63:0] sreg_in;
(* mark_debug = "true" *) reg [63:0] sreg_out;
(* mark_debug = "true" *) reg [24:0] sreg_cnt = 25'b0;
(* mark_debug = "true" *) reg sreg_ready;
parameter IDLE = 2'b00;
parameter LOAD = 2'b01;
parameter SHIFTING = 2'b10;
parameter DONE = 2'b11;

(* mark_debug = "true" *) reg [1:0] shift_state = IDLE;

(* mark_debug = "true" *) reg sreg_cnt_ena;
(* mark_debug = "true" *) reg sreg_cnt_reset;

(* mark_debug = "true" *) wire sreg_cnt_max;
assign sreg_cnt_max = (sreg_cnt == 25'h16F97FE) ? 1'b1 : 1'b0;

always @ (posedge clk)
begin
    if (sreg_cnt_reset)
        sreg_cnt[24:0] <= 25'b0;
    else if (sreg_cnt_ena)
        sreg_cnt[24:0] <= sreg_cnt[24:0] + 1'b1; 
    else
        sreg_cnt[24:0] <= sreg_cnt[24:0];
end

(* mark_debug = "true" *) reg sreg_load;

always @ (posedge clk)
begin
	if (sreg_load)
		begin
			sreg_out[63:0] <= payload[63:0];
			sreg_in[63:0] <= sreg_in[63:0];
		end
	else
		begin
			sreg_out[63:0] <= {sreg_out[62:0],1'b0};
			sreg_in[63:0] <= {sreg_in[62:0],spi_miso};
		end		
end

assign spi_mosi = sreg_out[63];


always @ (posedge clk)
begin
    if (reset)
        begin
            sreg_load <= 1'b1;
            sreg_cnt_reset <= 1'b1;
            sreg_cnt_ena <= 1'b0;
            spi_ss <= 1'b1;
            sreg_ready <= 1'b1;
            end_bitstream <= 1'b0;
            shift_state <= IDLE;
        end
    else
        begin
            case (shift_state)
                IDLE : begin
                    sreg_cnt_reset <= 1'b1;
                    sreg_cnt_ena <= 1'b0;
                    sreg_load <= 1'b1;                    
                    spi_ss <= 1'b1;
                    sreg_ready <= 1'b1;
                    end_bitstream <= 1'b0;
                    if (sreg_strobe)
                        shift_state <= LOAD;
                    else
                        shift_state <= IDLE;
                end
                
                LOAD : begin
                    sreg_cnt_reset <= 1'b1;
                    sreg_cnt_ena <= 1'b0;
                    sreg_load <= 1'b1;                    
                    spi_ss <= 1'b1;
                    sreg_ready <= 1'b0;
                    end_bitstream <= 1'b0;
                    if (sreg_strobe)
                        shift_state <= LOAD;
                    else
                        shift_state <= SHIFTING;                
                end
                
                SHIFTING : begin
                    sreg_cnt_reset <= 1'b0;
                    sreg_cnt_ena <= 1'b1;
                    sreg_load <= 1'b0;
                    spi_ss <= 1'b0;
                    sreg_ready <= 1'b0;
                    end_bitstream <= 1'b0;
                    if (sreg_cnt_max)
                        shift_state <= IDLE;
                    else
                        shift_state <= SHIFTING;
                end

                DONE : begin
                    sreg_cnt_reset <= 1'b1;
                    sreg_cnt_ena <= 1'b0;
                    sreg_load <= 1'b1;
                    spi_ss <= 1'b1;
                    sreg_ready <= 1'b1;
                    end_bitstream <= 1'b1; // tell prog_channels this is the end
                    shift_state <= IDLE; // stay here one clock cycle, then go to IDLE
                end
            endcase
        end                
end

//*************************************************************************
// latch to offload the shift register
//*************************************************************************
//always @ (posedge clk)
//begin
//	if (sreg_ready)
//		data_out[31:0] <= {sreg_in[31:0]};
//	else
//		data_out[31:0] <= data_out[31:0];
//end	

//*************************************************************************
// command state machine
//   - controls the shift register to read and write      
//************************************************************************
parameter S1 = 3'b000;
parameter S2 = 3'b001;
parameter S3 = 3'b010;

(* mark_debug = "true" *) reg [2:0] spi_state = S1;

(* mark_debug = "true" *) wire [63:0] payload;

assign payload = {data_in[31:0],32'h00000000};

always @ (posedge clk)
begin
	if (reset)
        begin
            sreg_strobe <= 1'b0;
            spi_state <= S1;
        end
	else
	    begin
            case (spi_state)
                // idle
                S1 : begin
            	    sreg_strobe <= 1'b0;
                    if (read_bitstream)   // time to start!
                		spi_state <= S2;
                    else
                	    spi_state <= S1;
                end
        
                // load & shift
                S2 : begin
                    sreg_strobe <= 1'b1;
                    if (sreg_ready)       // wait here until the shift reg starts shifting
    		     	    spi_state <= S3;
    			    else
    		     	    spi_state <= S2;
    		    end
    		
    	       // done
                S3 : begin
                    sreg_strobe <= 1'b0;
                    spi_state <= S3;      // stay here forever
        	   end  
	        endcase
        end
end

// block RAM -- for practice right now (make sure can communicate via IPbus)

RAMB18E1 #(
    .RAM_MODE("SDP"),
    .READ_WIDTH_A(36),
    .WRITE_WIDTH_B(36)
)
RAMB18E1_inst (
    .CLKARDCLK(ipb_clk),           // 1-bit input: Read clk (port A)
    .CLKBWRCLK(ipb_clk),           // 1-bit input: Write clk (port B)

    .ENARDEN(1'b0),                // 1-bit input: Read enable (port A)
    .ENBWREN(1'b0),                // 1-bit input: Write enable (port B)
    .WEBWE(4'b1111),               // 4-bit input: byte-wide write enable

    .RSTREGARSTREG(1'b0),          // 1-bit input: A port register set/reset
    .RSTRAMARSTRAM(1'b0),          // 1-bit input: A port set/reset

    // addresses: 36-bit port has depth = 512, 9-bit address (bits [13:5] are used)
    .ADDRARDADDR(14'h0000),        // 14-bit input: Read address
    .ADDRBWRADDR(14'h0000),        // 14-bit input: Write address

    // data in (and parity bits)
    .DIBDI(data_in[31:16]),        // 16-bit input: DI[31:16]
    .DIADI(data_in[15:0]),         // 16-bit input: DI[15:0]
    .DIPBDIP(2'b00),               // 2-bit input: DIP[3:2]
    .DIPADIP(2'b00),               // 2-bit input: DIP[1:0]

    // data out (and parity bits)
    .DOBDO(data_out[31:16]),       // 16-bit output: DO[31:16]
    .DOADO(data_out[15:0]),        // 16-bit output: DO[15:0]
    .DOPBDOP(),                    // 2-bit output: DOP[3:2]
    .DOPADOP()                     // 2-bit output: DOP[1:0]
);

endmodule