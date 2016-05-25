// This state machine reads the entire contents of the I2C EEPROM and stores it in a RAM block.

// synopsys translate_off
`timescale 1ns / 10ps
// synopsys translate_on

module i2c_read_eeprom_sm(
	// inputs
	input clk,					// 125 MHz clock for IPbus 
    input reset,				// synchronous, active-hi reset from 'rst_from_ipb'
    input i2c_byte_rdy,			// a byte has been retrieved from the EEPROM
	// outputs
	output reg i2c_start_read,		// start the sequence to read a byte
	output reg [7:0] image_wr_adr,	// the 'wr' address
	output reg image_wr_en,			// memory 'wr' port enable
    output reg image_copy_done		// the entire EEPROM has been read
);

// Create an address counter used for writing the EEPROM contents to the image memory
reg init_image_wr_adr, inc_image_wr_adr;	// 'wr' address controls
always @ (posedge clk) begin
	if (reset || init_image_wr_adr)
		// always start at the beginning of the EEPROM
		image_wr_adr[7:0] <= 8'h00;
	else if (inc_image_wr_adr)
		// increment the address
		image_wr_adr[7:0] <= image_wr_adr[7:0] + 1;
end

// Create an counter used for pausing between bytes. This is mainly for
// separating activity during simulation.
reg init_pause_cntr, dec_pause_cntr;
reg [15:0] pause_cntr;
always @ (posedge clk) begin
	if (reset || init_pause_cntr)
		// initialize the counter
		pause_cntr[15:0] <= 16'd12500;	// 12500 = 100 usec @ 125 MHz, 500 = 100 usec @ 5 MHz
	else if (dec_pause_cntr)
		// decrement the counter
		pause_cntr[15:0] <= pause_cntr[15:0] - 1;
end

/////////////////////////////////////////////////////////////////////////////////////////////
// Connect a state machine that will copy the entire EEPROM contents to the image memory.
// We use 4 states to read each byte.
// The first initializes the transfer.
// The second waits for the data to be ready.
// The third stores the data.
// The fourth checks to see if we have copied all of the data.

// Declare the symbolic names for states
// Simplified one-hot encoding (each constant is an index into an array of bits)
parameter [4:0]
    IDLE		= 5'd0,
    INIT		= 5'd1,
    REQ_BYTE	= 5'd2,
    WAIT_BYTE	= 5'd3,
    STORE_BYTE	= 5'd4,
    CHECK_CNT	= 5'd5,
    INC_ADR		= 5'd6,
    PAUSE		= 5'd7,
    DONE       	= 5'd8;
    
// Declare current state and next state variables
reg [8:0] /* synopsys enum STATE_TYPE */ CS;
reg [8:0] /* synopsys enum STATE_TYPE */ NS;
//synopsys state_vector CS
 
// sequential always block for state transitions (use non-blocking [<=] assignments)
always @ (posedge clk) begin
    if (reset) begin
        CS <= 9'b0;	// set all state bits to 0
        CS[IDLE] <= 1'b1;	// set IDLE state bit to 1
    end
    else
        CS <= NS;         // set state bits to next state
end


// combinational always block to determine next state  (use blocking [=] assignments) 
always @ (CS or i2c_byte_rdy or image_wr_adr[7:0] or pause_cntr[15:0])    begin
    NS = 9'b0; // default all bits to zero; will overrride one bit

    case (1'b1) // synopsys full_case parallel_case

        // Leave the IDLE state as soon as 'reset' is negated.
        CS[IDLE]: begin
               NS[INIT] = 1'b1;
        end

        // Need a single state after IDLE to isolate NS[GET_00] outputs
        CS[INIT]: begin
               NS[REQ_BYTE] = 1'b1;
        end

		// request a byte		  
        CS[REQ_BYTE]: begin
                NS[WAIT_BYTE] = 1'b1;
        end

        // Wait for the byte 
        CS[WAIT_BYTE]: begin
        	if (i2c_byte_rdy)
                NS[STORE_BYTE] = 1'b1;
			else
				NS[WAIT_BYTE] = 1'b1;
        end

        // Store the byte 
        CS[STORE_BYTE]: begin
                NS[CHECK_CNT] = 1'b1;
        end

        // See if all bytes have been read 
        CS[CHECK_CNT]: begin
        	if (image_wr_adr[7:0] == 8'hff)
                NS[DONE] = 1'b1;
			else
				NS[INC_ADR] = 1'b1;
        end

        // Increment the EEPROM address 
        CS[INC_ADR]: begin
                NS[REQ_BYTE] = 1'b1; // no delay between bytes
                // NS[PAUSE] = 1'b1; // uncomment if you want delay between btyes
        end

       // Insert a delay between bytes
        CS[PAUSE]: begin
        	if (pause_cntr[15:0] == 16'h0000)
                NS[REQ_BYTE] = 1'b1;
			else
				NS[PAUSE] = 1'b1;
        end

		// Stay here for now. Eventually become a loop reading temperature 
        CS[DONE]: begin
                NS[DONE] = 1'b1;
        end
    endcase
end // combinational always block to determine next state

// Drive outputs for each state at the same time as when we enter the state.
// Use the NS[] array.
always @ (posedge clk) begin
    // defaults
	i2c_start_read		<= 1'b0;
    image_wr_en			<= 1'b0;
	image_copy_done		<= 1'b0;
	init_image_wr_adr	<= 1'b0;
	inc_image_wr_adr	<= 1'b0;
	init_pause_cntr		<= 1'b0;
	dec_pause_cntr		<= 1'b0;
			
    // next states
    if (NS[IDLE]) begin
    end

    if (NS[INIT]) begin
		// initialize the EEPROM address to 0x00
		init_image_wr_adr	<= 1'b1;
    end
   
    if (NS[REQ_BYTE]) begin
		// kick off an I2C read
		i2c_start_read		<= 1'b1;
    end

    if (NS[WAIT_BYTE]) begin
		// kick off an I2C read
    	i2c_start_read		<= 1'b1;
    end

    if (NS[STORE_BYTE]) begin
       // store the byte in the image memory
       image_wr_en        <= 1'b1;
    end

    if (NS[CHECK_CNT]) begin
    end

    if (NS[INC_ADR]) begin
		// increment the EEPROM address
    	inc_image_wr_adr	<= 1'b1;
		init_pause_cntr	<= 1'b1;
    end

    if (NS[PAUSE]) begin
    	dec_pause_cntr		<= 1'b1;
    end

    if (NS[DONE]) begin
        // signal that we are done
		image_copy_done		<= 1'b1;
    end

end

endmodule