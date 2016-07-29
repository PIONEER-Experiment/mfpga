// This module will read 1 byte from the I2C temperature/memory chip.

// synopsys translate_off
`timescale 1ns / 10ps
// synopsys translate_on

module i2c_read_byte (
	// inputs
	input clk,				    // 125 MHz clock for IPbus 
    input reset,			    // reset from 'rst_from_ipb'
	input [6:0] i2c_dev_adr,    // EEPROM section of device #0
    input [7:0] i2c_mem_adr,    // memory location within the EEPROM
    input i2c_start_read,	    // initiate a byte read
    input image_copy_done,      // EEPROM image copy is done
    // outputs
    output reg i2c_byte_rdy,    // the byte is ready
    output [7:0] i2c_rd_dat,    // byte read from EEPROM
    output reg i2c_temp_rdy,    // the temperature is ready
    output reg [11:0] i2c_temp, // temperature read from EEPROM
	// I2C signals
	input  scl_pad_i,		    // 'clock' input from external pin
	output scl_pad_o,		    // 'clock' output to tri-state driver
	output scl_padoen_o,	    // 'clock' enable signal for tri-state driver
	input  sda_pad_i,		    // 'data' input from external pin
	output sda_pad_o,		    // 'data' output to tri-state driver
	output sda_padoen_o		    // 'data' enable signal for tri-state driver
);

// Create an counter used for pausing between bytes
reg init_pause_cntr, dec_pause_cntr;
reg [15:0] pause_cntr;
always @ (posedge clk) begin
	if (reset || init_pause_cntr)
		pause_cntr[15:0] <= 16'd6250; // 6250 = 50 usec @ 125 MHz
	else if (dec_pause_cntr)
		pause_cntr[15:0] <= pause_cntr[15:0] - 1;
end

// Create registers for the state machine outputs
reg tx_reg_init1, tx_reg_init2, tx_reg_init3;
reg core_en;
reg i2c_start;
reg i2c_stop;
reg i2c_write;
reg i2c_read;
reg itxack;

// Create a transmit register to hold the byte that we send out on the I2C link
reg [7:0] tx_reg;
always @(posedge clk) begin
	if (tx_reg_init1) tx_reg <= {i2c_dev_adr, 1'b0}; // address phase for a WRITE
	if (tx_reg_init2) tx_reg <= i2c_mem_adr;		 // EEPROM address
	if (tx_reg_init3) tx_reg <= {i2c_dev_adr, 1'b1}; // address phase for a READ
end

// Create a temperature register
reg update_temp_msb;
reg update_temp_lsb;
always @(posedge clk) begin
    if (update_temp_msb) i2c_temp[11:0] <= {i2c_rd_dat[3:0], i2c_temp[7:0]};  // update MSB
    if (update_temp_lsb) i2c_temp[11:0] <= {i2c_temp[11:8], i2c_rd_dat[7:0]}; // update LSB
end

wire cmd_ack;

// Connect the I2C controller module
// This came from the 'opencores' website at http://opencores.org/project,i2c
// The 'wishbone' interface was eliminated, and direct connections made to the 'byte controller' block
i2c_master_byte_ctrl byte_controller (
	// inputs
	.clk(clk),				// master clock
	.rst(reset),			// synchronous active high reset
	.nReset(1'b1),			// asynchronous active low reset, NOT USED SO HELD HIGH
	.ena(core_en),			// core enable signal
    .clk_cnt(16'd249),      // = (clk/(5*SCL)) - 1, so for 125 MHz 'clk' and 100 kHz SCL, need 249
	.start(i2c_start),		// prepend an I2C 'start' cycle
	.stop(i2c_stop),		// post-pend an I2C 'stop' cycle
	.read(i2c_read),		// do an I2C 'read' operation
	.write(i2c_write),		// do an I2C 'write' operation
	.ack_in(itxack),		// ACK/NACK to send out on I2C bus after a READ
	.din(tx_reg[7:0]),		// byte that we send out on the EEPROM
	// outputs
	.cmd_ack(cmd_ack),		// the command is complete
	.ack_out(irxack),		// status of the ACK bit from the I2C bus
	.dout(i2c_rd_dat[7:0]), // byte read from EEPROM
	.i2c_busy(i2c_busy),
	.i2c_al(i2c_al),
	// I2C signals
	.scl_i(scl_pad_i),		// 'clock' input from external pin
	.scl_o(scl_pad_o),		// 'clock' output to tri-state driver
	.scl_oen(scl_padoen_o),	// 'clock' enable signal for tri-state driver
	.sda_i(sda_pad_i),		// 'data' input from external pin
	.sda_o(sda_pad_o),		// 'data' output to tri-state driver
	.sda_oen(sda_padoen_o)	// 'data' enable signal for tri-state driver
);

// Connect a state machine that will drive the 'byte_controller' through the whole
// sequence required to read a byte from the EEPROM. This is replacing the 'wishbone'
// interface of the original 'opencores' project.

// Declare the symbolic names for states
// Simplified one-hot encoding (each constant is an index into an array of bits)
parameter [4:0]
    IDLE	   = 5'd0,
    ENABLE	   = 5'd1,
	WAIT1	   = 5'd2,
    DEV_INIT1  = 5'd3,
    DEV_INIT2  = 5'd4,
    DEV_INIT3  = 5'd5,
    DEV_INIT4  = 5'd6,
    PAUSE1	   = 5'd7,
    ADR_INIT1  = 5'd8,
    ADR_INIT2  = 5'd9,
    ADR_INIT3  = 5'd10,
    ADR_INIT4  = 5'd11,
    PAUSE2	   = 5'd12,
    DEV_INIT5  = 5'd13,
    DEV_INIT6  = 5'd14,
    DEV_INIT7  = 5'd15,
    DEV_INIT8  = 5'd16,
    PAUSE3	   = 5'd17,
    READ_INIT1 = 5'd18,
    READ_WAIT1 = 5'd19,
    READ_INIT2 = 5'd20,
    READ_WAIT2 = 5'd21,
    ERROR	   = 5'd22,
    DONE       = 5'd23;
    
// Declare current state and next state variables
reg [23:0] /* synopsys enum STATE_TYPE */ CS;
reg [23:0] /* synopsys enum STATE_TYPE */ NS;
// synopsys state_vector CS
 
// sequential always block for state transitions (use non-blocking [<=] assignments)
always @ (posedge clk) begin
    if (reset) begin
        CS <= 24'b0;	  // set all state bits to 0
        CS[IDLE] <= 1'b1; // set IDLE state bit to 1
    end
    else
        CS <= NS;         // set state bits to next state
end


// combinational always block to determine next state (use blocking [=] assignments)
always @ (CS or i2c_start_read or cmd_ack or irxack or pause_cntr[15:0] or image_copy_done) begin
    NS = 24'b0; // default all bits to zero; will override one bit

    case (1'b1) // synopsys full_case parallel_case
        // Leave the IDLE state as soon as 'reset' is negated
        CS[IDLE]: begin
            NS[ENABLE] = 1'b1;
        end

		// Enable the I2C controller; it will start up using the counter pre-scale value
        CS[ENABLE]: begin
            NS[WAIT1] = 1'b1;
        end

		// Wait for a request to read a byte
        CS[WAIT1]: begin
        	if (i2c_start_read)
                NS[DEV_INIT1] = 1'b1;
            else
                NS[WAIT1] = 1'b1;        	
        end

		// Initialize the device address and the WR bit
        CS[DEV_INIT1]: begin
            NS[DEV_INIT2] = 1'b1;
        end

		// Send the device address and the WR bit
        CS[DEV_INIT2]: begin
            NS[DEV_INIT3] = 1'b1;
        end

		// Wait for completion of the transfer
        CS[DEV_INIT3]: begin
        	if (cmd_ack)
                NS[DEV_INIT4] = 1'b1;
            else
                NS[DEV_INIT3] = 1'b1;
		end

		// Check the state of the ACK bit on the I2C bus
        CS[DEV_INIT4]: begin
        	if (irxack)
                NS[ERROR] = 1'b1;
            else
                NS[PAUSE1] = 1'b1;
        end

       // Insert a delay between bytes
        CS[PAUSE1]: begin
        	if (pause_cntr[15:0] == 16'h0000)
                NS[ADR_INIT1] = 1'b1;
			else
				NS[PAUSE1] = 1'b1;
        end
        
		// Send the EEPROM memory address and the WR bit
        CS[ADR_INIT1]: begin
            NS[ADR_INIT2] = 1'b1;
        end

        // Send the EEPROM address and the WR bit
        CS[ADR_INIT2]: begin
            NS[ADR_INIT3] = 1'b1;
        end

        // Wait for completion of the transfer
        CS[ADR_INIT3]: begin
        	if (cmd_ack)
                NS[ADR_INIT4] = 1'b1;
            else
                NS[ADR_INIT3] = 1'b1;
        end

        // Check the state of the ACK bit on the I2C bus
        CS[ADR_INIT4]: begin
        	if (irxack)
                NS[ERROR] = 1'b1;
            else
                NS[PAUSE2] = 1'b1;
        end

       // Insert a delay between bytes
        CS[PAUSE2]: begin
        	if (pause_cntr[15:0] == 16'h0000)
                NS[DEV_INIT5] = 1'b1;
			else
				NS[PAUSE2] = 1'b1;
        end

		// Initialize the device address and the RD bit
        CS[DEV_INIT5]: begin
            NS[DEV_INIT6] = 1'b1;
        end

		// Send the device address and the RD bit
        CS[DEV_INIT6]: begin
            NS[DEV_INIT7] = 1'b1;
        end

		// Wait for completion of the transfer
        CS[DEV_INIT7]: begin
        	if (cmd_ack)
                NS[DEV_INIT8] = 1'b1;
            else
                NS[DEV_INIT7] = 1'b1;
		end

		// Set RD bit, set ACK to '1' (NACK), set STO bit
        CS[DEV_INIT8]: begin
        	if (irxack)
                NS[ERROR] = 1'b1;
            else
                NS[PAUSE3] = 1'b1;
        end

        // Insert a delay between bytes
        CS[PAUSE3]: begin
        	if (pause_cntr[15:0] == 16'h0000)
                NS[READ_INIT1] = 1'b1;
			else
				NS[PAUSE3] = 1'b1;
        end

		// Start a read
        CS[READ_INIT1]: begin
            NS[READ_WAIT1] = 1'b1;
        end

		// Wait for completion of the transfer
        CS[READ_WAIT1]: begin
            if (cmd_ack) begin
                // reading temperature
                if (image_copy_done)
                    NS[READ_INIT2] = 1'b1;
                // reading image
                else
                    NS[DONE] = 1'b1;
            end
            else
                NS[READ_WAIT1] = 1'b1;
		end

        // Start another read
        CS[READ_INIT2]: begin
            NS[READ_WAIT2] = 1'b1;
        end

        // Wait for completion of the transfer
        CS[READ_WAIT2]: begin
            if (cmd_ack)
                NS[DONE] = 1'b1;
            else
                NS[READ_WAIT2] = 1'b1;
        end

		// Do some type of error reporting
        CS[ERROR]: begin
            NS[DONE] = 1'b1;
        end

		// Done
        CS[DONE]: begin
            NS[IDLE] = 1'b1;
        end
    endcase
end // combinational always block to determine next state

// Drive outputs for each state at the same time as when we enter the state.
// Use the NS[] array.
always @ (posedge clk) begin
    // defaults
	core_en			<= 1'b1; // enabled except when explicitly disabled
	tx_reg_init1	<= 1'b0;
	tx_reg_init2	<= 1'b0;
	tx_reg_init3	<= 1'b0;
    i2c_start		<= 1'b0;
    i2c_stop		<= 1'b0;
	i2c_write		<= 1'b0;
	i2c_read		<= 1'b0;
 	i2c_byte_rdy	<= 1'b0;
 	itxack			<= 1'b0;
 	init_pause_cntr	<= 1'b0;
 	dec_pause_cntr	<= 1'b0;
    i2c_temp_rdy    <= 1'b0;
    update_temp_msb <= 1'b0;
    update_temp_lsb <= 1'b0;
	
    // next states
    if (NS[IDLE]) begin
    	// disable the core when idle
        core_en <= 1'b0;	
    end
    
    if (NS[ENABLE]) begin
    end

    if (NS[WAIT1]) begin
    end

    if (NS[DEV_INIT1]) begin
        // set the transmit register to the device address and RD/WR=0
        tx_reg_init1 <= 1'b1;
    end

    if (NS[DEV_INIT2]) begin
        // set the byte controller's STA and WR bits
        i2c_start <= 1'b1;
        i2c_write <= 1'b1;
    end

    if (NS[DEV_INIT3]) begin
    end

    if (NS[DEV_INIT4]) begin
 		init_pause_cntr <= 1'b1;
    end

    if (NS[PAUSE1]) begin
 		dec_pause_cntr <= 1'b1;
    end

    if (NS[ADR_INIT1]) begin
        // set the transmit register to the EEPROM address
        tx_reg_init2 <= 1'b1;
    end

    if (NS[ADR_INIT2]) begin
        // set the byte controller's WR bit
        i2c_write <= 1'b1;
    end

    if (NS[ADR_INIT3]) begin
    end

    if (NS[ADR_INIT4]) begin
		init_pause_cntr <= 1'b1;
    end

    if (NS[PAUSE2]) begin
 		dec_pause_cntr <= 1'b1;
    end

    if (NS[DEV_INIT5]) begin
        // set the transmit register to the device address and RD/WR=1
        tx_reg_init3 <= 1'b1;
    end

    if (NS[DEV_INIT6]) begin
        // set the byte controller's STA and WR bits
        i2c_start <= 1'b1;
        i2c_write <= 1'b1;
    end

    if (NS[DEV_INIT7]) begin
    end

    if (NS[DEV_INIT8]) begin
		init_pause_cntr <= 1'b1;
    end

    if (NS[PAUSE3]) begin
 		dec_pause_cntr <= 1'b1;
    end

    if (NS[READ_INIT1]) begin
       	i2c_read <= 1'b1;
    end

    if (NS[READ_WAIT1]) begin
		// set ACK to '1' (NACK), set STO bit
        // when reading the EEPROM image copy
	 	if (~image_copy_done) begin
            itxack   <= 1'b1;
	        i2c_stop <= 1'b1;
        end
    end

    if (NS[READ_INIT2]) begin
        i2c_read        <= 1'b1;
        update_temp_msb <= 1'b1;
    end

    if (NS[READ_WAIT2]) begin
        // set ACK to '1' (NACK), set STO bit
        itxack   <= 1'b1;
        i2c_stop <= 1'b1;
    end

    if (NS[DONE]) begin
        if (image_copy_done) begin
            i2c_temp_rdy    <= 1'b1;
            update_temp_lsb <= 1'b1;
        end
        else
            i2c_byte_rdy <= 1'b1;
    end
end


// Read from the first 2 memory locations
// Slave address = 1010 0000 : bits [7:4] access EEPROM, bits [3:1] address the chip, bit 0 is RD/WR bit

// write 0xA0 to transmit register
// set STA bit, set WR bit
// wait for TIP flag to negate
// check RxACK = 0

// write 0x00 to transmit register
// set WR bit
// wait for TIP flag to negate
// check RxACK = 0

// write 0xA1 to transmit register - RD/WR bit = 1
// set STA bit, set WR bit
// wait for TIP flag to negate
// set RD bit, set ACK to '1' (NACK), set STO bit

//==================================================================
//// from the I2C testbench
//// access slave (read)

//// drive slave address
//u0.wb_write(1, TXR,{SADR,WR} ); // present slave address, set write-bit
//u0.wb_write(0, CR,     8'h90 ); // set command (start, write)

//// check tip bit
//u0.wb_read(1, SR, q);
//while(q[1])
//     u0.wb_read(1, SR, q); // poll it until it is zero

//// send memory address
//u0.wb_write(1, TXR,     8'h01); // present slave's memory address
//u0.wb_write(0, CR,      8'h10); // set command (write)

//// check tip bit
//u0.wb_read(1, SR, q);
//while(q[1])
//     u0.wb_read(1, SR, q); // poll it until it is zero

//// drive slave address
//u0.wb_write(1, TXR, {SADR,RD} ); // present slave's address, set read-bit
//u0.wb_write(0, CR,      8'h90 ); // set command (start, write)

//// check tip bit
//u0.wb_read(1, SR, q);
//while(q[1])
//     u0.wb_read(1, SR, q); // poll it until it is zero

//// read data from slave
//u0.wb_write(1, CR,      8'h20); // set command (read, ack_read)

//// check tip bit
//u0.wb_read(1, SR, q);
//while(q[1])
//     u0.wb_read(1, SR, q); // poll it until it is zero

//// check data just received
//u0.wb_read(1, RXR, qq);
//if(qq !== 8'ha5)
//  $display("\nERROR: Expected a5, received %x at time %t", qq, $time);
//else
//  $display("status: %t received %x", $time, qq);

endmodule
