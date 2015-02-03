`timescale 1ns / 1ps

// Based on Nate's ADC interface. Right now only suitable for reading the channel bitstream. Needs to be cleaned up & turned into a more general interface. 

// TODO: figure out miso synchronization delay

module spi_flash_intf(
	input clk,
    input ipb_clk,
	input reset,
	input [31:0] data_in,
	output [31:0] data_out,
	output spi_clk,
	output spi_mosi,
	input spi_miso,
	output reg spi_ss,
    input read_bitstream,
    output reg end_bitstream,
    (* mark_debug = "true" *) input [8:0] ipb_flash_wr_nBytes,
    input ipb_flash_cmd_strobe,
    output reg flash_cmd_ack,
    input rbuf_rd_en,
    input [6:0] rbuf_rd_addr,
    output [31:0] rbuf_data_out,
    input wbuf_wr_en,
    input [6:0] wbuf_wr_addr,
    input [31:0] wbuf_data_in
);


assign spi_clk = !clk;

//*************************************************************************
// dual shift register with counter, MSB wired to output of module
//  
// sreg_strobe - starts the shifting mechanism
// payload - what will be shifted
// sreg_ready - active high status signal
//*************************************************************************
reg sreg_strobe;
reg [63:0] sreg_in;
reg [63:0] sreg_out;
reg [24:0] sreg_cnt = 25'b0;
reg sreg_ready;
parameter IDLE = 2'b00;
parameter LOAD = 2'b01;
parameter SHIFTING = 2'b10;
parameter DONE = 2'b11;

reg [1:0] shift_state = IDLE;

reg sreg_cnt_ena;
reg sreg_cnt_reset;

wire sreg_cnt_max;
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

reg sreg_load;

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

reg [2:0] spi_state = S1;

wire [63:0] payload;

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


(* mark_debug = "true" *) reg wbuf_rd_en;
(* mark_debug = "true" *) reg [13:0] wbuf_rd_addr;
(* mark_debug = "true" *) wire wbuf_data_out;
(* mark_debug = "true" *) reg rbuf_wr_en;
(* mark_debug = "true" *) reg [13:0] rbuf_wr_addr;
// wire rbuf_data_in;

// state machine for reading WBUF and writing RBUF using the 1-bit ports
// (to test operation of block RAMs before hooking them up to the flash memory SPI interface)

(* mark_debug = "true" *) wire flash_cmd_strobe;
(* mark_debug = "true" *) reg [8:0] flash_wr_nBytes;

// bring IPbus signals into the 50 MHz clk domain

sync_2stage flash_cmd_sync(
    .clk(clk),
    .in(ipb_flash_cmd_strobe),
    .out(flash_cmd_strobe)
);

reg [8:0] flash_wr_nBytes_sync;
always @ (posedge clk)
begin
    flash_wr_nBytes_sync <= ipb_flash_wr_nBytes;
    flash_wr_nBytes <= flash_wr_nBytes_sync;
end

(* mark_debug = "true" *) reg [11:0] bit_cnt = 12'b0;
(* mark_debug = "true" *) reg bit_cnt_reset;
(* mark_debug = "true" *) reg trans_en;

(* mark_debug = "true" *) wire [11:0] bit_cnt_max;
assign bit_cnt_max[11:0] = {flash_wr_nBytes[8:0],3'b000} - 1'b1;

always @ (posedge clk)
begin
    if (bit_cnt_reset)
        bit_cnt[11:0] <= 12'b0;
    else if (trans_en)
        bit_cnt[11:0] <= bit_cnt[11:0] + 1'b1; 
    else
        bit_cnt[11:0] <= bit_cnt[11:0];
end

parameter S_IDLE = 3'b000;
parameter S_TRANSFER = 3'b001;
parameter S_CMD_ACK = 3'b010;

(* mark_debug = "true" *) reg [2:0] buf_state = S_IDLE;

always @ (posedge clk)
begin
    if (reset)
        begin
            bit_cnt_reset <= 1'b1;
            trans_en <= 1'b0;
            flash_cmd_ack <= 1'b0;
            buf_state <= S_IDLE;
        end
    else
        begin
            case (buf_state)

                S_IDLE : begin
                    bit_cnt_reset <= 1'b1;
                    trans_en <= 1'b0;
                    flash_cmd_ack <= 1'b0;
                    if (flash_cmd_strobe) // time to start data transfer!
                        buf_state <= S_TRANSFER;
                    else
                        buf_state <= S_IDLE;
                end
      
                S_TRANSFER : begin
                    if (bit_cnt == bit_cnt_max) // we're done
                        begin
                            trans_en <= 1'b0;
                            buf_state <= S_CMD_ACK;
                        end
                    else
                        begin
                            trans_en <= 1'b1;
                            bit_cnt_reset <= 1'b0;
                            buf_state <= S_TRANSFER;
                        end
                end

                S_CMD_ACK : begin
                    bit_cnt_reset <= 1'b1;
                    trans_en <= 1'b0;
                    flash_cmd_ack <= 1'b1;
                    buf_state <= S_IDLE;
                end

            endcase
        end
end

always @ (posedge clk)
begin
    wbuf_rd_addr <= {2'b00, bit_cnt[11:0]};
    wbuf_rd_en <= trans_en;
    rbuf_wr_addr <= wbuf_rd_addr;
    rbuf_wr_en <= wbuf_rd_en;
end


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



// ======== dual port block RAMs ========
// WBUF: for writing to flash
//      32-bit port = input from IPbus
//       1-bit port = output to flash
// RBUF: for reading from flash
//       1-bit port = input from flash
//      32-bit port = output to IPbus

RAMB18E1 #(
    .RAM_MODE("SDP"),
    .READ_WIDTH_A(1),
    .WRITE_WIDTH_B(36) // 32 data bits, 4 (unused) parity bits
)
wbuf (
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
    .READ_WIDTH_A(36),  // 32 data bits, 4 (unused) parity bits
    .WRITE_WIDTH_B(1)
)
rbuf (
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
    // .DIBDI({15'b0, rbuf_data_in}),  // 16-bit input: we only use DI[0]
    .DIBDI({15'b0, wbuf_data_out}), // 16-bit input: we only use DI[0]

    // data out
    .DOBDO(rbuf_data_out_r[31:16]), // 16-bit output: DO[31:16]
    .DOADO(rbuf_data_out_r[15:0])   // 16-bit output: DO[15:0]

);

endmodule