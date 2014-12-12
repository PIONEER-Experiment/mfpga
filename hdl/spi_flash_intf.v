`timescale 1ns / 1ps

// TODO: figure out miso synchronization delay

module spi_flash_intf(
	input clk,
	(* mark_debug = "true" *) input reset,
	input [31:0] data_in,
	output reg [31:0] data_out,
	output spi_clk,
	output spi_mosi,
	input spi_miso,
	output reg spi_ss
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
(* mark_debug = "true" *) reg [5:0] sreg_cnt = 6'b000000;
(* mark_debug = "true" *) reg sreg_ready;
parameter IDLE = 2'b00;
parameter LOAD = 2'b01;
parameter SHIFTING = 2'b10;

(* mark_debug = "true" *) reg [1:0] shift_state = IDLE;

(* mark_debug = "true" *) reg sreg_cnt_ena;
(* mark_debug = "true" *) reg sreg_cnt_reset;

(* mark_debug = "true" *) wire sreg_cnt_max;
assign sreg_cnt_max = (sreg_cnt == 6'b111110) ? 1'b1 : 1'b0;

always @ (posedge clk)
begin
    if (sreg_cnt_reset)
        sreg_cnt[5:0] <= 6'b000000;
    else if (sreg_cnt_ena)
        sreg_cnt[5:0] <= sreg_cnt[5:0] + 6'b000001; 
    else
        sreg_cnt[5:0] <= sreg_cnt[5:0];
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
                    if (sreg_cnt_max)
                        shift_state <= IDLE;
                    else
                        shift_state <= SHIFTING;
                end
            endcase
        end                
end

//*************************************************************************
// latch to offload the shift register
//*************************************************************************
always @ (posedge clk)
begin
	if (sreg_ready)
		data_out[31:0] <= {sreg_in[31:0]};
	else
		data_out[31:0] <= data_out[31:0];
end	

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

(* mark_debug = "true" *) reg [6:0] delay_counter = 7'b0000000;

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
                    if (delay_counter[6])   // time to start!
                	    begin
                		  delay_counter[6:0] <= 7'b0000000;						
                		  spi_state <= S2;
                	    end
                    else
                	    begin
                		  delay_counter[6:0] <= delay_counter[6:0] + 7'b0000001;
                		  spi_state <= S1;
                	    end
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


endmodule