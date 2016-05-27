// State machine for programming the Channel FPGAs
// using a bitstream stored in the flash memory
//
// The address for the start of the channel bitstream is 0xCE0000
// (this is currently hard-coded in wfd_top.v, at the instatiation of 
// the spi_flash_intf module)
//
// To start state machine, write '1' to the appropriate IPbus address

module prog_channels (
	input clk,
	input reset,
    input prog_chan_start,            // start signal from IPbus
    output reg c_progb,               // configuration signal to all five channels
    output c_clk,                     // configuration clock to all five channels
    output reg c_din,                 // configuration bitstream to all five channels
    input [4:0] initb,                // configuration signals from each channel
    input [4:0] prog_done,            // configuration signals from each channel
    input bitstream,                  // from SPI flash
    output reg prog_chan_in_progress, // signal to spi_flash_intf
    output reg store_flash_command,   // signal to spi_flash_intf
    output reg read_bitstream,        // start command to spi_flash_intf
    input end_bitstream,              // done signal from spi_flash_intf
    output reg prog_chan_done         // done programming the channels
);

assign c_clk = ~clk;

reg [4:0] initb_sync;
reg [4:0] prog_done_sync;

always @ (posedge clk)
begin
    initb_sync[4:0]     <= initb[4:0];
    prog_done_sync[4:0] <= prog_done[4:0];
end


parameter IDLE          = 3'b000;
parameter STORE_CMD     = 3'b001;
parameter START         = 3'b010;
parameter INIT1         = 3'b011;
parameter INIT2         = 3'b100;
parameter LOAD          = 3'b101;
parameter WAIT_FOR_DONE = 3'b110;
parameter DONE          = 3'b111;

reg [2:0] state = IDLE;

reg [3:0] counter = 4'h0;


always @ (posedge clk)
begin
    if (reset) begin
        c_progb <= 1'b1;
        c_din   <= 1'b0;

        state <= IDLE;
    end
    else begin
        case (state)
            IDLE : begin
                c_progb <= 1'b1;
                c_din   <= 1'b1;
                prog_chan_in_progress <= 1'b0;
                store_flash_command   <= 1'b0;
                read_bitstream        <= 1'b0;

                if (prog_chan_start)
                    state <= STORE_CMD;
                else
                    state <= IDLE;
            end

            STORE_CMD : begin
                c_progb <= 1'b1;
                c_din   <= 1'b1;
                prog_chan_in_progress <= 1'b1;
                store_flash_command   <= 1'b1;
                read_bitstream        <= 1'b0;
                prog_chan_done        <= 1'b0;

                state <= START;
            end
            
            START : begin
                c_progb <= 1'b0;
                c_din   <= 1'b1;
                prog_chan_in_progress <= 1'b1;
                store_flash_command   <= 1'b0;
                read_bitstream        <= 1'b0;
                prog_chan_done        <= 1'b0;
                counter               <= 4'h0;

                if (initb_sync[4:0] == 5'b00000)
                    state <= INIT1;
                else
                    state <= START;                
            end
            
            INIT1 : begin
                c_progb <= 1'b0; // progb still low (required Tprogram >= 250 ns)
                c_din   <= 1'b1;
                prog_chan_in_progress <= 1'b1;
                store_flash_command   <= 1'b0;
                read_bitstream        <= 1'b0;
                prog_chan_done        <= 1'b0;

                if (counter[3:0] == 4'hf)
                    state <= INIT2;
                else begin
                    counter[3:0] <= counter[3:0] + 1'h1;
                    state <= INIT1;
                end
            end

            INIT2 : begin
                c_progb <= 1'b1; // release progb back to normal high state
                c_din   <= 1'b1;
                prog_chan_in_progress <= 1'b1;
                store_flash_command   <= 1'b0;
                read_bitstream        <= 1'b0;
                prog_chan_done        <= 1'b0;

                if (initb_sync[4:0] == 5'b11111)
                    state <= LOAD;
                else
                    state <= INIT2;
            end

            LOAD : begin
                c_progb <= 1'b1;
                c_din   <= bitstream;
                prog_chan_in_progress <= 1'b1;
                store_flash_command   <= 1'b0;
                read_bitstream        <= 1'b1; // initiate read command to SPI flash
                prog_chan_done        <= 1'b0;

                if (end_bitstream)
                    state <= WAIT_FOR_DONE;
                else
                    state <= LOAD;
            end

            WAIT_FOR_DONE : begin
                c_progb <= 1'b1;
                c_din  <= 1'b1;
                prog_chan_in_progress <= 1'b1;
                store_flash_command   <= 1'b0;
                read_bitstream        <= 1'b0;
                prog_chan_done        <= 1'b0;

                if (prog_done_sync == 5'b11111)
                    state <= DONE;
                else
                    state <= WAIT_FOR_DONE;
            end

            DONE : begin
                c_progb <= 1'b1;
                c_din   <= 1'b1;
                prog_chan_in_progress <= 1'b0;
                store_flash_command   <= 1'b0;
                read_bitstream        <= 1'b0;
                prog_chan_done        <= 1'b1;

                state <= DONE; // stay here until reset
            end

        endcase
    end
end

endmodule
