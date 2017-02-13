// This state machine extracts MAC and IP address from the EEPROM image.

// synopsys translate_off
`timescale 1ns / 10ps
// synopsys translate_on

module i2c_get_from_image_sm (
	// inputs
	input clk,					   // 125 MHz clock for IPbus 
    input reset,				   // synchronous, active-hi reset from 'rst_from_ipb'
    input image_copy_done,		   // the entire EEPROM has been read
    input [7:0] image_rd_dat,	   // data from the image memory
    // outputs
    output reg [7:0] image_rd_adr, // address to the image memory
    output [47:0] i2c_mac_adr,	   // MAC address read from I2C EEPROM
    output [31:0] i2c_ip_adr,	   // IP  address read from I2C EEPROM
    output reg i2c_startup_done	   // MAC and IP will be valid when this is asserted
);

//////////////////////////////////////////////////////////////////////////////////////////////
// Create registers for the low two bytes of the MAC address and the 4 bytes of the IP address
reg [7:0] mac0_, mac1_, ip0_, ip1_, ip2_, ip3_;
reg store_mac0, store_mac1, store_ip0, store_ip1, store_ip2, store_ip3;
// The upper 4 bytes of the MAC address are always 00:60:55:00:01:XX
assign i2c_mac_adr[47:0] = {8'h00, 8'h60, 8'h55, 8'h00, mac1_[7:0], mac0_[7:0]};
assign i2c_ip_adr[31:0]  = {ip3_[7:0], ip2_[7:0], ip1_[7:0], ip0_[7:0]};

// control retrieval of the MAC and IP registers
always @(posedge clk) begin
	if (store_mac0) mac0_[7:0] <= image_rd_dat[7:0];
	if (store_mac1) mac1_[7:0] <= image_rd_dat[7:0];
	if (store_ip0)   ip0_[7:0] <= image_rd_dat[7:0];
	if (store_ip1)   ip1_[7:0] <= image_rd_dat[7:0];
	if (store_ip2)   ip2_[7:0] <= image_rd_dat[7:0];
	if (store_ip3)   ip3_[7:0] <= image_rd_dat[7:0];
end

///////////////////////////////////////////////////////////////////////////////////////////////
// Connect a state machine that will extract data from the EEPROM image and put it in registers

// Declare the symbolic names for states
// Simplified one-hot encoding (each constant is an index into an array of bits)
parameter [4:0]
    IDLE   = 5'd0,
	INIT   = 5'd1,
    GET_00 = 5'd2,
    USE_00 = 5'd3,
    GET_01 = 5'd4,
    USE_01 = 5'd5,
    GET_02 = 5'd6,
    USE_02 = 5'd7,
    GET_80 = 5'd8,
    USE_80 = 5'd9,
    GET_81 = 5'd10,
    USE_81 = 5'd11,
    GET_82 = 5'd12,
    USE_82 = 5'd13,
    GET_83 = 5'd14,
    USE_83 = 5'd15,
    GET_84 = 5'd16,
    USE_84 = 5'd17,
    PAUSE  = 5'd18,
    DONE   = 5'd19;
    
// Declare current state and next state variables
reg [19:0] /* synopsys enum STATE_TYPE */ CS;
reg [19:0] /* synopsys enum STATE_TYPE */ NS;
// synopsys state_vector CS
 
// sequential always block for state transitions (use non-blocking [<=] assignments)
always @ (posedge clk) begin
    if (reset) begin
        CS <= 20'b0;	  // set all state bits to 0
        CS[IDLE] <= 1'b1; // set IDLE state bit to 1
    end
    else
        CS <= NS;         // set state bits to next state
end

// combinational always block to determine next state (use blocking [=] assignments) 
always @ (CS or image_copy_done)    begin
    NS = 20'b0; // default all bits to zero; will overrride one bit

    case (1'b1) // synopsys full_case parallel_case
        // Leave the IDLE state as soon as 'reset' is negated.
        CS[IDLE]: begin
            NS[INIT] = 1'b1;
        end

        // Wait for the EEPROM image to be copied to internal memory
        CS[INIT]: begin
        	if (image_copy_done)
                NS[GET_00] = 1'b1;
			else
				NS[INIT] = 1'b1;
        end

        // Get a byte 
        CS[GET_00]: begin
            NS[USE_00] = 1'b1;
        end

        // Use the byte 
        CS[USE_00]: begin
            NS[GET_01] = 1'b1;
        end

        // Get a byte 
        CS[GET_01]: begin
            NS[USE_01] = 1'b1;
        end

        // Use the byte 
        CS[USE_01]: begin
            NS[GET_02] = 1'b1;
        end

        // Get a byte 
        CS[GET_02]: begin
            NS[USE_02] = 1'b1;
        end

        // Use the byte 
        CS[USE_02]: begin
            NS[GET_80] = 1'b1;
        end

        // Get a byte 
        CS[GET_80]: begin
            NS[USE_80] = 1'b1;
        end

        // Use the byte 
        CS[USE_80]: begin
            NS[GET_81] = 1'b1;
        end

        // Get a byte 
        CS[GET_81]: begin
            NS[USE_81] = 1'b1;
        end

        // Use the byte 
        CS[USE_81]: begin
            NS[GET_82] = 1'b1;
        end

        // Get a byte 
        CS[GET_82]: begin
            NS[USE_82] = 1'b1;
        end

        // Use the byte 
        CS[USE_82]: begin
            NS[GET_83] = 1'b1;
        end

        // Get a byte 
        CS[GET_83]: begin
            NS[USE_83] = 1'b1;
        end

        // Use the byte 
        CS[USE_83]: begin
            NS[GET_84] = 1'b1;
        end

        // Get a byte 
        CS[GET_84]: begin
            NS[USE_84] = 1'b1;
        end

        // Use the byte 
        CS[USE_84]: begin
            NS[PAUSE] = 1'b1;
        end

        CS[PAUSE]: begin
			NS[DONE] = 1'b1;
        end

		// Stay here for ever 
        CS[DONE]: begin
            NS[DONE] = 1'b1;
        end
    endcase
end // combinational always block to determine next state

// Drive outputs for each state at the same time as when we enter the state.
// Use the NS[] array.
always @ (posedge clk) begin
    // defaults
	store_mac0		 <= 1'b0;
	store_mac1		 <= 1'b0;
	store_ip0		 <= 1'b0;
	store_ip1		 <= 1'b0;
	store_ip2		 <= 1'b0;
	store_ip3		 <= 1'b0;
	i2c_startup_done <= 1'b0;
			
    // next states
    if (NS[IDLE]) begin
    end

    if (NS[INIT]) begin
    end
   
    if (NS[GET_00]) begin
		image_rd_adr[7:0] <= 8'h00;
    end

    if (NS[USE_00]) begin
		store_mac0 <= 1'b1;
    end

    if (NS[GET_01]) begin
		image_rd_adr[7:0] <= 8'h01;
    end

    if (NS[USE_01]) begin
		store_mac1 <= 1'b1;
    end

    if (NS[GET_02]) begin
		image_rd_adr[7:0] <= 8'h02;
    end

    if (NS[USE_02]) begin
    end

    if (NS[GET_80]) begin
		image_rd_adr[7:0] <= 8'h80;
    end

    if (NS[USE_80]) begin
		store_ip0 <= 1'b1;
    end

    if (NS[GET_81]) begin
		image_rd_adr[7:0] <= 8'h81;
    end

    if (NS[USE_81]) begin
		store_ip1 <= 1'b1;
    end

    if (NS[GET_82]) begin
		image_rd_adr[7:0] <= 8'h82;
    end

    if (NS[USE_82]) begin
		store_ip2 <= 1'b1;
    end

    if (NS[GET_83]) begin
		image_rd_adr[7:0] <= 8'h83;
    end

    if (NS[USE_83]) begin
		store_ip3 <= 1'b1;
    end

    if (NS[GET_84]) begin
		image_rd_adr[7:0] <= 8'h84;
    end

    if (NS[USE_84]) begin
    end

    if (NS[PAUSE]) begin
    end

    if (NS[DONE]) begin
        // signal that we are done
		i2c_startup_done <= 1'b1;
    end

end

endmodule
