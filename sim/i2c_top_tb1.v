`timescale 1ns / 1ps

////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer:
//
// Create Date:   17:16:54 04/29/2016
// Design Name:   i2c_top
// Module Name:   C:/TEMP/junk/i2c_top_tb1.v
// Project Name:  junk
// Target Device:  
// Tool versions:  
// Description: 
//
// Verilog Test Fixture created by ISE for module: i2c_top
//
// Dependencies:
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
////////////////////////////////////////////////////////////////////////////////

module i2c_top_tb1;

	// Inputs
	reg clk;
	reg reset;

	// Outputs
	wire i2c_startup_done;
	wire [47:0] i2c_mac_adr;
	wire [31:0] i2c_ip_adr;

	// internal
	wire scl, scl_o, scl_oen;
	wire sda, sda_o, sda_oen;

	parameter SADR    = 7'b1010_000;

	// generate clock
	// 5 MHz for simulation
	//always #100 clk = ~clk;
	// 125 MHz for final check
	always #4 clk = ~clk;

	// Instantiate the Unit Under Test (UUT)
	i2c_top uut (
		.clk(clk), 
		.reset(reset), 
		.i2c_startup_done(i2c_startup_done), 
		.i2c_mac_adr(i2c_mac_adr), 
		.i2c_ip_adr(i2c_ip_adr), 
		.scl_pad_i(scl), 
		.scl_pad_o(scl_o), 
		.scl_padoen_o(scl_oen), 
		.sda_pad_i(sda), 
		.sda_pad_o(sda_o), 
		.sda_padoen_o(sda_oen)
	);

	// hookup i2c slave model
	i2c_slave_model #(SADR) i2c_slave (
		.WP(1'b0),
		.RESET(1'b0),
		.SCL(scl),
		.SDA(sda)
	);

    // create i2c lines
	delay m0_scl (scl_oen ? 1'bz : scl_o, scl),
	      m0_sda (sda_oen ? 1'bz : sda_o, sda);

	pullup p1(scl); // pullup scl line
	pullup p2(sda); // pullup sda line

	initial begin
		// Initialize Inputs
		clk = 0;
		reset = 1;

		// Wait 100 ns for global reset to finish
		#100;
        #1000 reset = 0;
        
		// Add stimulus here

	end
      
endmodule

module delay (in, out);
  input  in;
  output out;

  assign out = in;

  specify
    (in => out) = (600,600);
  endspecify
endmodule


