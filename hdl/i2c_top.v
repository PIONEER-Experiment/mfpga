// First, this module will read the full EEPROM contents from the I2C temperature/memory chip,
// and store an image of it in a dual-port memory.
// Then it will extract the MAC and IP addresses from the image.
// Finally, it will periodically read the temperature from the chip.

// Since the MAC and IP address are used with IPbus, we will run the state machines with 'clk125'.

// synopsys translate_off
`timescale 1ns / 10ps
// synopsys translate_on

module i2c_top (
    // inputs
    input clk,                  // 125 MHz clock for IPbus 
    input reset,                // synchronous, active-hi reset from 'rst_from_ipb'
    // outputs
    output i2c_startup_done,    // MAC and IP will be valid when this is asserted
    output [47:0] i2c_mac_adr,  // MAC address read from I2C EEPROM
    output [31:0] i2c_ip_adr,   // IP  address read from I2C EEPROM
    output reg [11:0] i2c_temp, // latest temperature reading
    // I2C signals
    input  scl_pad_i,           // 'clock' input from external pin
    output scl_pad_o,           // 'clock' output to tri-state driver
    output scl_padoen_o,        // 'clock' enable signal for tri-state driver
    input  sda_pad_i,           // 'data' input from external pin
    output sda_pad_o,           // 'data' output to tri-state driver
    output sda_padoen_o         // 'data' enable signal for tri-state driver
);

///////////////////////////////////////////////////////////////////////////////////
// Create a dual-port memory that will hold an image of the entire EEPROM contents.
// At startup, the EEPROM will be copied to this memory. We will then extract data
// from specific addresses.
wire [7:0] image_wr_adr, image_rd_adr; // 'wr' and 'rd' addresses
wire [7:0] image_wr_dat, image_rd_dat; // 'wr' and 'rd' data
wire image_wr_en;                      // 'wr' port enable
i2c_eeprom_image i2c_eeprom_image (
    // 'wr' port
    .clka(clk),                // input wire clka
    .wea(image_wr_en),         // input wire [0:0] wea
    .addra(image_wr_adr[7:0]), // input wire [7:0] addra
    .dina(image_wr_dat[7:0]),  // input wire [7:0] dina
    // 'rd' port
    .clkb(clk),                // input  wire clkb
    .addrb(image_rd_adr[7:0]), // input  wire [7:0] addrb
    .doutb(image_rd_dat[7:0])  // output wire [7:0] doutb
);

////////////////////////////////
// Create a temperature register
wire i2c_temp_rdy;
wire [11:0] i2c_temp_read;
always @ (posedge clk) begin
    // update the temperature
    if (i2c_temp_rdy) i2c_temp[11:0] <= i2c_temp_read[11:0];
end

////////////////////////////////////////////////////////////////////////////////////////////
// Create a MUX that will provide either the EEPROM device address or the temperature sensor
// device address to the 'i2c_read_byte' controller
wire [6:0] i2c_dev_adr;
wire image_copy_done; // if 0 read EEPROM, if 1 read temperature
// if done, send temperature sensor address, otherwise send EEPROM address
assign i2c_dev_adr[6:0] = image_copy_done ? 7'b0011_000 : 7'b1010_000;

// Temperature sensor register
wire [7:0] i2c_reg_adr;
assign i2c_reg_adr[7:0] = 8'h05;

// Create a MUX that will provide either the EEPROM address or a sensor register address
wire [7:0] i2c_internal_adr;
// If done, send sensor register address, otherwise send EEPROM address
assign i2c_internal_adr[7:0] = image_copy_done ? i2c_reg_adr[7:0] : image_wr_adr[7:0];

// Error handing signals
wire i2c_error;

/////////////////////////////////////////////////////////////////////////////////////////
// Connect the controller that reads 1 byte from the EEPROM. It will be called repeatedly
wire i2c_start_read; // trigger reading a byte from the I2C device
i2c_read_byte i2c_read_byte (
    // inputs
    .clk(clk),
    .reset(reset),
    .i2c_dev_adr(i2c_dev_adr[6:0]),      // address of a device on the I2C bus
    .i2c_mem_adr(i2c_internal_adr[7:0]), // either memory location within the EEPROM or an internal register
    .i2c_start_read(i2c_start_read),     // initiate a byte read
    .image_copy_done(image_copy_done),   // EEPROM image copy is done
    // outputs
    .i2c_byte_rdy(i2c_byte_rdy),         // the byte is ready
    .i2c_rd_dat(image_wr_dat[7:0]),      // byte read from I2C device
    .i2c_temp_rdy(i2c_temp_rdy),         // the temperature is ready
    .i2c_temp(i2c_temp_read[11:0]),      // temperature read from I2C device
    .i2c_error(i2c_error),               // an error occurred
    // I2C signals
    .scl_pad_i(scl_pad_i),
    .scl_pad_o(scl_pad_o),
    .scl_padoen_o(scl_padoen_o),
    .sda_pad_i(sda_pad_i),
    .sda_pad_o(sda_pad_o),
    .sda_padoen_o(sda_padoen_o)
);

////////////////////////////////////////////////////////////////////////////////////////
// Connect a state machine that will copy the entire EEPROM contents to the image memory
i2c_read_eeprom_sm i2c_read_eeprom_sm (
    // inputs
    .clk(clk),                        // 125 MHz clock for IPbus 
    .reset(reset),                    // synchronous, active-hi reset from 'rst_from_ipb'
    .i2c_byte_rdy(i2c_byte_rdy),      // a byte has been retrieved from the EEPROM
    .i2c_temp_rdy(i2c_temp_rdy),      // temperature has been retrieved from the EEPROM
    .i2c_error(i2c_error),
    // outputs
    .i2c_start_read(i2c_start_read),  // start the sequence to read a byte
    .image_wr_adr(image_wr_adr[7:0]), // the 'wr' address
    .image_wr_en(image_wr_en),        // memory 'wr' port enable
    .image_copy_done(image_copy_done) // the entire EEPROM has been read
);

///////////////////////////////////////////////////////////////////////////////////
// Connect a state machine that pull the MAC and IP addresses from the image memory
i2c_get_from_image_sm i2c_get_from_image_sm (
    // inputs
    .clk(clk),                          // 125 MHz clock for IPbus 
    .reset(reset),                      // synchronous, active-hi reset from 'rst_from_ipb'
    .image_copy_done(image_copy_done),  // the entire EEPROM has been read
    .image_rd_dat(image_rd_dat[7:0]),   // data from the image memory
    // outputs
    .image_rd_adr(image_rd_adr[7:0]),   // address to the image memory
    .i2c_mac_adr(i2c_mac_adr[47:0]),    // MAC address read from I2C EEPROM
    .i2c_ip_adr(i2c_ip_adr[31:0]),      // IP  address read from I2C EEPROM
    .i2c_startup_done(i2c_startup_done) // MAC and IP will be valid when this is asserted
);

endmodule
