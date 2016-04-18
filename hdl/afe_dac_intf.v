`include "afe_dac_regs.txt"

// ============================================
// Interface between Master FPGA and AFE's DACs
// ============================================

module afe_dac_intf (
    input clk50,
    input clk50_reset,

    // inputs from IPbus
    input io_clk,             // ipbus interface clock
    input io_reset,           // ipbus interface reset    
    input io_sel,             // this module has been selected for an I/O operation
    input io_sync,            // start the I/O operation
    input [19:0] io_addr,     // local slave address, memory or register
    input io_wr_en,           // this is a write operation, enable target for one clock
    input [31:0] io_wr_data,  // data to write for write operations

    // unused
    input io_rd_en,           // this is a read operation, enable readback logic
    output [31:0] io_rd_data, // data returned for read operations
    output io_rd_ack,         // 'write' data has been stored, 'read' data is ready

    // outputs to chip(s)
    output sclk,              // serial clock input
    output sdi,               // serial data input
    output reg sync_n,        // active-low control input, '/sync' signal

    // debugs
    output [2:0] debug
);


// ==================
// static assignments
// ==================
assign sclk = slow_clk_180;


// ================================
// synchronize state machine inputs
// ================================
reg resetS;

always @ (posedge slow_clk)
begin
    resetS <= clk50_reset;
end


// ===================================================
// startup state machine to configure default settings
// ===================================================
parameter STARTUP_IDLE   = 3'b001;
parameter STARTUP_WAIT   = 3'b010;
parameter STARTUP_RESET  = 3'b100;
parameter STARTUP_STROBE = 3'b101;
parameter STARTUP_DONE   = 3'b110;

reg [2:0] startup_state = STARTUP_IDLE;

reg [15:0] startup_cnt = 16'd0; // counter to wait >3 ms after power up
reg startup_rst_level_cntrl;    // flag to drive startup_reset wire to either low (1'b0) or high (1'b1) for cntrl
reg startup_rst_level_reg;      // flag to drive startup_reset wire to either low (1'b0) or high (1'b1) for regs
reg startup_done;               // flag to tell other state machines that the startup procedure is complete

wire startup_rst_cntrl;
wire startup_rst_reg;
assign startup_rst_cntrl = (startup_rst_level_cntrl) ? 1'b1 : 1'b0;
assign startup_rst_reg   = (startup_rst_level_reg)   ? 1'b1 : 1'b0;

always @ (posedge slow_clk)
begin
    // no reset is allowed for startup state machine
    // this state machine will only run once, after that IPbus needs to be used for configuration

    case (startup_state)
        STARTUP_IDLE : begin
            startup_cnt[15:0] <= 16'd0;
            startup_rst_level_cntrl <= 1'b0;
            startup_rst_level_reg <= 1'b0;
            startup_done <= 1'b0;

            startup_state <= STARTUP_WAIT;
        end
        
        // wait for >3 ms after power is delivered to AFE's DACs
        STARTUP_WAIT : begin
            startup_cnt[15:0] <= startup_cnt[15:0] + 1'b1;
            startup_rst_level_cntrl <= 1'b0;
            startup_rst_level_reg <= 1'b0;
            startup_done <= 1'b0;

            if (startup_cnt[15])
                startup_state <= STARTUP_RESET;
            else
                startup_state <= STARTUP_WAIT;
        end
        
        // reset the s[#]_reg reg32_ce2 blocks to their default values
        // this will load the default register values into s[#]_reg_out wires
        STARTUP_RESET : begin
            startup_cnt[15:0] <= startup_cnt[15:0] + 1'b1;
            startup_rst_level_cntrl <= 1'b0;
            startup_rst_level_reg <= 1'b1;
            startup_done <= 1'b0;

            if (startup_cnt[5])
                startup_state <= STARTUP_STROBE;
            else
                startup_state <= STARTUP_RESET;
        end

        // reset the scntrl_reg reg32_ce2 block to its default value
        // this will initiate the configuration to the DACs
        STARTUP_STROBE : begin
            startup_cnt[15:0] <= 16'd0;
            startup_rst_level_cntrl <= 1'b1;
            startup_rst_level_reg <= 1'b0;
            startup_done <= 1'b0;

            startup_state <= STARTUP_DONE;
        end

        // stay in this state forever
        // the startup_done flag tells the WRITE SM to toggle the sync wire after writing to the registers
        STARTUP_DONE : begin
            startup_cnt[15:0] <= 16'd0;
            startup_rst_level_cntrl <= 1'b0;
            startup_rst_level_reg <= 1'b0;
            startup_done <= 1'b1;

            startup_state <= STARTUP_DONE;
        end
    endcase
end


// ==============================================
// IPbus interface used to update register values
// ==============================================
// address decoding
wire reg_wr_en, scntrl_reg_sel;
wire s00_1_reg_sel, s00_2_reg_sel, s00_3_reg_sel,
     s01_1_reg_sel, s01_2_reg_sel, s01_3_reg_sel,
     s02_1_reg_sel, s02_2_reg_sel, s02_3_reg_sel,
     s03_1_reg_sel, s03_2_reg_sel, s03_3_reg_sel,
     s04_1_reg_sel, s04_2_reg_sel, s04_3_reg_sel,
     s05_1_reg_sel, s05_2_reg_sel, s05_3_reg_sel,
     s06_1_reg_sel, s06_2_reg_sel, s06_3_reg_sel;

assign reg_wr_en  = io_sync & io_wr_en;

assign scntrl_reg_sel = io_sel && (io_addr[4:0] == 5'b11010);
assign  s00_1_reg_sel = io_sel && (io_addr[4:0] == 5'b00000);    // AFE DAC #1 MODE
assign  s00_2_reg_sel = io_sel && (io_addr[4:0] == 5'b00001);    // AFE DAC #2 MODE
assign  s00_3_reg_sel = io_sel && (io_addr[4:0] == 5'b00010);    // AFE DAC #3 MODE
assign  s01_1_reg_sel = io_sel && (io_addr[4:0] == 5'b00011);    // AFE DAC #1 \LDAC
assign  s01_2_reg_sel = io_sel && (io_addr[4:0] == 5'b00100);    // AFE DAC #2 \LDAC
assign  s01_3_reg_sel = io_sel && (io_addr[4:0] == 5'b00101);    // AFE DAC #3 \LDAC
assign  s02_1_reg_sel = io_sel && (io_addr[4:0] == 5'b00110);    // AFE DAC #1 DCEN
assign  s02_2_reg_sel = io_sel && (io_addr[4:0] == 5'b00111);    // AFE DAC #2 DCEN
assign  s02_3_reg_sel = io_sel && (io_addr[4:0] == 5'b01000);    // AFE DAC #3 DCEN
assign  s03_1_reg_sel = io_sel && (io_addr[4:0] == 5'b01001);    // AFE DAC #1 Channel A
assign  s03_2_reg_sel = io_sel && (io_addr[4:0] == 5'b01010);    // AFE DAC #2 Channel A
assign  s03_3_reg_sel = io_sel && (io_addr[4:0] == 5'b01011);    // AFE DAC #3 Channel A
assign  s04_1_reg_sel = io_sel && (io_addr[4:0] == 5'b01100);    // AFE DAC #1 Channel B
assign  s04_2_reg_sel = io_sel && (io_addr[4:0] == 5'b01101);    // AFE DAC #2 Channel B
assign  s04_3_reg_sel = io_sel && (io_addr[4:0] == 5'b01110);    // AFE DAC #3 Channel B
assign  s05_1_reg_sel = io_sel && (io_addr[4:0] == 5'b01111);    // AFE DAC #1 Channel C
assign  s05_2_reg_sel = io_sel && (io_addr[4:0] == 5'b10000);    // AFE DAC #2 Channel C
assign  s05_3_reg_sel = io_sel && (io_addr[4:0] == 5'b10001);    // AFE DAC #3 Channel C
assign  s06_1_reg_sel = io_sel && (io_addr[4:0] == 5'b10010);    // AFE DAC #1 Channel D
assign  s06_2_reg_sel = io_sel && (io_addr[4:0] == 5'b10011);    // AFE DAC #2 Channel D
assign  s06_3_reg_sel = io_sel && (io_addr[4:0] == 5'b10100);    // AFE DAC #3 Channel D


// ====================================================================
// Recommended programming sequence:
//     MODE, \LDAC, DCEN, Channel A-D
//
// Notes:
//     s[#] notation indicates the order of data sent to the AFE's DACs
//          and not the AFE's DACs register number
// ====================================================================

wire [31:0] scntrl_reg_out; // LSB controls the strobe

// s[#]_reg_out wires used to write to the AFE's DACs
// these wires are driven by the reg inside the reg32_ce2 blocks

// from IPbus
wire [31:0] s00_1_reg_out, s00_2_reg_out, s00_3_reg_out;    // AFE DAC MODE
wire [31:0] s01_1_reg_out, s01_2_reg_out, s01_3_reg_out;    // AFE DAC \LDAC
wire [31:0] s02_1_reg_out, s02_2_reg_out, s02_3_reg_out;    // AFE DAC DCEN
wire [31:0] s03_1_reg_out, s03_2_reg_out, s03_3_reg_out;    // AFE DAC Channel A
wire [31:0] s04_1_reg_out, s04_2_reg_out, s04_3_reg_out;    // AFE DAC Channel B
wire [31:0] s05_1_reg_out, s05_2_reg_out, s05_3_reg_out;    // AFE DAC Channel C
wire [31:0] s06_1_reg_out, s06_2_reg_out, s06_3_reg_out;    // AFE DAC Channel D


// to AFE's DACs
wire [95:0] s00_reg_out;    // AFE DAC MODE
wire [95:0] s01_reg_out;    // AFE DAC \LDAC
wire [95:0] s02_reg_out;    // AFE DAC DCEN
wire [95:0] s03_reg_out;    // AFE DAC Channel A
wire [95:0] s04_reg_out;    // AFE DAC Channel B
wire [95:0] s05_reg_out;    // AFE DAC Channel C
wire [95:0] s06_reg_out;    // AFE DAC Channel D

// format: {(DAC #3 REG), (DAC #2 REG), (DAC #1 REG)}
assign s00_reg_out = {s00_1_reg_out, s00_2_reg_out, s00_3_reg_out};
assign s01_reg_out = {s01_1_reg_out, s01_2_reg_out, s01_3_reg_out};
assign s02_reg_out = {s02_1_reg_out, s02_2_reg_out, s02_3_reg_out};
assign s03_reg_out = {s03_1_reg_out, s03_2_reg_out, s03_3_reg_out};
assign s04_reg_out = {s04_1_reg_out, s04_2_reg_out, s04_3_reg_out};
assign s05_reg_out = {s05_1_reg_out, s05_2_reg_out, s05_3_reg_out};
assign s06_reg_out = {s06_1_reg_out, s06_2_reg_out, s06_3_reg_out};

// reverse format for initial configuration
// NOT NEEDED RIGHT NOW SINCE \LDAC AND DCEN REGISTERS ARE IDENTICAL FOR ALL DACS
//wire [95:0] s01_reg_out_r, s02_reg_out_r;
//assign s01_reg_out_r = {s01_3_reg_out, s01_2_reg_out, s01_1_reg_out};
//assign s02_reg_out_r = {s02_3_reg_out, s02_2_reg_out, s02_1_reg_out};

wire rst_reg;    // want the reg_out values to be set to default when IPbus reset or the startup reset is asserted
wire rst_cntrl;  // want the cntrl_reg_out values to be set to default when IPbus reset or the startup reset is asserted
assign rst_reg   = resetS | startup_rst_reg;
assign rst_cntrl = resetS | startup_rst_cntrl;

reg32_ce2 scntrl_reg(.in(io_wr_data[31:0]), .reset(rst_cntrl), .def_value(32'h00000001),     .out(scntrl_reg_out[31:0]), .clk(io_clk), .clk_en1(reg_wr_en), .clk_en2(scntrl_reg_sel));
reg32_ce2  s00_3_reg(.in(io_wr_data[31:0]), .reset(rst_reg),   .def_value(`DAC1_DEF_MODE),   .out(s00_3_reg_out[31:0]),  .clk(io_clk), .clk_en1(reg_wr_en), .clk_en2(s00_3_reg_sel));
reg32_ce2  s00_2_reg(.in(io_wr_data[31:0]), .reset(rst_reg),   .def_value(`DAC2_DEF_MODE),   .out(s00_2_reg_out[31:0]),  .clk(io_clk), .clk_en1(reg_wr_en), .clk_en2(s00_2_reg_sel));
reg32_ce2  s00_1_reg(.in(io_wr_data[31:0]), .reset(rst_reg),   .def_value(`DAC3_DEF_MODE),   .out(s00_1_reg_out[31:0]),  .clk(io_clk), .clk_en1(reg_wr_en), .clk_en2(s00_1_reg_sel));
reg32_ce2  s01_3_reg(.in(io_wr_data[31:0]), .reset(rst_reg),   .def_value(`DAC1_DEF_LDAC),   .out(s01_3_reg_out[31:0]),  .clk(io_clk), .clk_en1(reg_wr_en), .clk_en2(s01_3_reg_sel));
reg32_ce2  s01_2_reg(.in(io_wr_data[31:0]), .reset(rst_reg),   .def_value(`DAC2_DEF_LDAC),   .out(s01_2_reg_out[31:0]),  .clk(io_clk), .clk_en1(reg_wr_en), .clk_en2(s01_2_reg_sel));
reg32_ce2  s01_1_reg(.in(io_wr_data[31:0]), .reset(rst_reg),   .def_value(`DAC3_DEF_LDAC),   .out(s01_1_reg_out[31:0]),  .clk(io_clk), .clk_en1(reg_wr_en), .clk_en2(s01_1_reg_sel));
reg32_ce2  s02_3_reg(.in(io_wr_data[31:0]), .reset(rst_reg),   .def_value(`DAC1_DEF_DCEN),   .out(s02_3_reg_out[31:0]),  .clk(io_clk), .clk_en1(reg_wr_en), .clk_en2(s02_3_reg_sel));
reg32_ce2  s02_2_reg(.in(io_wr_data[31:0]), .reset(rst_reg),   .def_value(`DAC2_DEF_DCEN),   .out(s02_2_reg_out[31:0]),  .clk(io_clk), .clk_en1(reg_wr_en), .clk_en2(s02_2_reg_sel));
reg32_ce2  s02_1_reg(.in(io_wr_data[31:0]), .reset(rst_reg),   .def_value(`DAC3_DEF_DCEN),   .out(s02_1_reg_out[31:0]),  .clk(io_clk), .clk_en1(reg_wr_en), .clk_en2(s02_1_reg_sel));
reg32_ce2  s03_3_reg(.in(io_wr_data[31:0]), .reset(rst_reg),   .def_value(`DAC1_DEF_CHAN_A), .out(s03_3_reg_out[31:0]),  .clk(io_clk), .clk_en1(reg_wr_en), .clk_en2(s03_3_reg_sel));
reg32_ce2  s03_2_reg(.in(io_wr_data[31:0]), .reset(rst_reg),   .def_value(`DAC2_DEF_CHAN_A), .out(s03_2_reg_out[31:0]),  .clk(io_clk), .clk_en1(reg_wr_en), .clk_en2(s03_2_reg_sel));
reg32_ce2  s03_1_reg(.in(io_wr_data[31:0]), .reset(rst_reg),   .def_value(`DAC3_DEF_CHAN_A), .out(s03_1_reg_out[31:0]),  .clk(io_clk), .clk_en1(reg_wr_en), .clk_en2(s03_1_reg_sel));
reg32_ce2  s04_3_reg(.in(io_wr_data[31:0]), .reset(rst_reg),   .def_value(`DAC1_DEF_CHAN_B), .out(s04_3_reg_out[31:0]),  .clk(io_clk), .clk_en1(reg_wr_en), .clk_en2(s04_3_reg_sel));
reg32_ce2  s04_2_reg(.in(io_wr_data[31:0]), .reset(rst_reg),   .def_value(`DAC2_DEF_CHAN_B), .out(s04_2_reg_out[31:0]),  .clk(io_clk), .clk_en1(reg_wr_en), .clk_en2(s04_2_reg_sel));
reg32_ce2  s04_1_reg(.in(io_wr_data[31:0]), .reset(rst_reg),   .def_value(`DAC3_DEF_CHAN_B), .out(s04_1_reg_out[31:0]),  .clk(io_clk), .clk_en1(reg_wr_en), .clk_en2(s04_1_reg_sel));
reg32_ce2  s05_3_reg(.in(io_wr_data[31:0]), .reset(rst_reg),   .def_value(`DAC1_DEF_CHAN_C), .out(s05_3_reg_out[31:0]),  .clk(io_clk), .clk_en1(reg_wr_en), .clk_en2(s05_3_reg_sel));
reg32_ce2  s05_2_reg(.in(io_wr_data[31:0]), .reset(rst_reg),   .def_value(`DAC2_DEF_CHAN_C), .out(s05_2_reg_out[31:0]),  .clk(io_clk), .clk_en1(reg_wr_en), .clk_en2(s05_2_reg_sel));
reg32_ce2  s05_1_reg(.in(io_wr_data[31:0]), .reset(rst_reg),   .def_value(`DAC3_DEF_CHAN_C), .out(s05_1_reg_out[31:0]),  .clk(io_clk), .clk_en1(reg_wr_en), .clk_en2(s05_1_reg_sel));
reg32_ce2  s06_3_reg(.in(io_wr_data[31:0]), .reset(rst_reg),   .def_value(`DAC1_DEF_CHAN_D), .out(s06_3_reg_out[31:0]),  .clk(io_clk), .clk_en1(reg_wr_en), .clk_en2(s06_3_reg_sel));
reg32_ce2  s06_2_reg(.in(io_wr_data[31:0]), .reset(rst_reg),   .def_value(`DAC2_DEF_CHAN_D), .out(s06_2_reg_out[31:0]),  .clk(io_clk), .clk_en1(reg_wr_en), .clk_en2(s06_2_reg_sel));
reg32_ce2  s06_1_reg(.in(io_wr_data[31:0]), .reset(rst_reg),   .def_value(`DAC3_DEF_CHAN_D), .out(s06_1_reg_out[31:0]),  .clk(io_clk), .clk_en1(reg_wr_en), .clk_en2(s06_1_reg_sel));


// use the LSB of the control register to generate a strobe which will be used
// to reset the loop counter and thus initiate a new programming sequence

// synchronize the LSB with the slow_clk
reg scntrl_LSB;

always @ (posedge slow_clk)
begin
    scntrl_LSB <= scntrl_reg_out[0];
end


// =================================================
// generate a single clock strobe based on scntrlLSB
// it's triggered by sctrlLSB going from low to high
// =================================================
parameter STROBE_IDLE = 3'b001;
parameter STROBE_TRIG = 3'b010;
parameter STROBE_DONE = 3'b100;

reg [2:0] strobe_state = STROBE_IDLE;
reg strobe;

always @ (posedge slow_clk)
begin
    if (resetS)
        begin
            strobe <= 1'b0;
            strobe_state <= STROBE_IDLE;
        end
    else
        begin
            case (strobe_state)
                STROBE_IDLE : begin
                    strobe <= 1'b0;

                    if (scntrl_LSB)
                        strobe_state <= STROBE_TRIG;
                    else
                        strobe_state <= STROBE_IDLE;
                end
                
                STROBE_TRIG : begin
                    strobe <= 1'b1;

                    strobe_state <= STROBE_DONE;
                end
                
                STROBE_DONE : begin
                    strobe <= 1'b0;

                    if (scntrl_LSB)
                        strobe_state <= STROBE_DONE;    
                    else
                        strobe_state <= STROBE_IDLE;
                end
            endcase
        end
end


// ==============================================
// generate a low speed clock (6.25 MHz / 160 ns)
// ==============================================
reg [2:0] clk_cnt;
wire slow_clk;
wire slow_clk_180;

always @ (posedge clk50)
begin
    clk_cnt[2:0] <= clk_cnt[2:0] + 1'b1;
end 

assign slow_clk = clk_cnt[2];
assign slow_clk_180 = !slow_clk;


// ==========================================================
// shift register with counter, LSB wired to output of module
//
// sreg_strobe - starts the shifting mechanism
// payload     - what will be shifted
// sreg_ready  - active high status signal
// ==========================================================
reg sreg_strobe;
reg [95:0] sreg;
reg [7:0] sreg_cnt = 8'b00000000;
reg sreg_ready;

parameter SHIFT_IDLE     = 2'b00;
parameter SHIFT_LOAD     = 2'b01;
parameter SHIFT_SHIFTING = 2'b10;

reg [1:0] shift_state = SHIFT_IDLE;

reg sreg_cnt_ena;
reg sreg_cnt_reset;

// flags for sending out 32, 64, and 96 bit register values
wire sreg_cnt_max_32, sreg_cnt_max_64, sreg_cnt_max_96;
assign sreg_cnt_max_32 = (sreg_cnt == 8'd30) ? 1'b1 : 1'b0;
assign sreg_cnt_max_64 = (sreg_cnt == 8'd62) ? 1'b1 : 1'b0;
assign sreg_cnt_max_96 = (sreg_cnt == 8'd94) ? 1'b1 : 1'b0;

// if addr is 0 or 1, use 32-bit value
wire sreg_cnt_max_init;
assign sreg_cnt_max_init = (dac_reg_addr[4:0] <= 5'd1) ? sreg_cnt_max_32 : sreg_cnt_max_64;

wire sreg_cnt_max;
assign sreg_cnt_max = (dac_reg_addr[4:0] >= 5'd4) ? sreg_cnt_max_96 : sreg_cnt_max_init;

always @ (posedge slow_clk)
begin
    if (sreg_cnt_reset)
        sreg_cnt[7:0] <= 8'b00000000;
    else if (sreg_cnt_ena)
        sreg_cnt[7:0] <= sreg_cnt[7:0] + 8'b00000001; 
    else
        sreg_cnt[7:0] <= sreg_cnt[7:0];
end

reg sreg_load;

always @ (posedge slow_clk)
begin
    if (sreg_load)
        sreg[95:0] <= dac_reg[95:0];
    else
        sreg[95:0] <= {sreg[94:0], 1'b0};        
end

assign sdi = sreg[95];

always @ (posedge slow_clk)
begin
    if (resetS)
        begin
            sreg_load <= 1'b1;
            sreg_cnt_reset <= 1'b1;
            sreg_cnt_ena <= 1'b0;
            sync_n <= 1'b1;
            sreg_ready <= 1'b1;
            
            shift_state <= SHIFT_IDLE;
        end
    else
        begin
            case (shift_state)
                SHIFT_IDLE : begin
                    sreg_cnt_reset <= 1'b1;
                    sreg_cnt_ena <= 1'b0;
                    sreg_load <= 1'b1;                    
                    sync_n <= 1'b1;
                    sreg_ready <= 1'b1;

                    if (sreg_strobe)
                        shift_state <= SHIFT_LOAD;
                    else
                        shift_state <= SHIFT_IDLE;
                end
                
                SHIFT_LOAD : begin
                    sreg_cnt_reset <= 1'b1;
                    sreg_cnt_ena <= 1'b0;
                    sreg_load <= 1'b1;                    
                    sync_n <= 1'b1;
                    sreg_ready <= 1'b0;

                    if (sreg_strobe)
                        shift_state <= SHIFT_LOAD;
                    else
                        shift_state <= SHIFT_SHIFTING;                
                end
                
                SHIFT_SHIFTING : begin
                    sreg_cnt_reset <= 1'b0;
                    sreg_cnt_ena <= 1'b1;
                    sreg_load <= 1'b0;
                    sync_n <= 1'b0;
                    sreg_ready <= 1'b0;

                    if (sreg_cnt_max)
                        shift_state <= SHIFT_IDLE;
                    else
                        shift_state <= SHIFT_SHIFTING;
                end
            endcase
        end
end


// ==================
// array of registers
// ==================
reg [4:0] dac_reg_addr = 5'd0;
reg [95:0] dac_reg = 96'd0;

always @ (posedge slow_clk)
begin
    case (dac_reg_addr[4:0])
        // order in which the registers will be programmed
        5'b00000 : dac_reg[95:0] = s01_reg_out[95:0]; // \LDAC, for DAC 1
        5'b00001 : dac_reg[95:0] = s02_reg_out[95:0]; //  DCEN, for DAC 1
        5'b00010 : dac_reg[95:0] = s01_reg_out[95:0]; // \LDAC, for DAC 1,2
        5'b00011 : dac_reg[95:0] = s02_reg_out[95:0]; //  DCEN, for DAC 1,2
        5'b00100 : dac_reg[95:0] = s01_reg_out[95:0]; // \LDAC, for DAC 1,2,3
        5'b00101 : dac_reg[95:0] = s02_reg_out[95:0]; //  DCEN, for DAC 1,2,3
        5'b00110 : dac_reg[95:0] = s00_reg_out[95:0]; //  MODE
        5'b00111 : dac_reg[95:0] = s03_reg_out[95:0]; //  Channel A
        5'b01000 : dac_reg[95:0] = s04_reg_out[95:0]; //  Channel B
        5'b01001 : dac_reg[95:0] = s05_reg_out[95:0]; //  Channel C
        5'b01010 : dac_reg[95:0] = s06_reg_out[95:0]; //  Channel D
    endcase
end


// =========================================================
// automatic configuration of all of the AFE's DAC registers
// =========================================================
parameter WRITE_IDLE      = 3'b000;
parameter WRITE_COUNT     = 3'b001;
parameter WRITE_LOAD      = 3'b010;
parameter WRITE_SHIFT     = 3'b011;
parameter WRITE_INCREMENT = 3'b100;
parameter SYNC_LOW        = 3'b101;
parameter SYNC_HIGH       = 3'b110;

reg [2:0] dac_state = WRITE_IDLE;


// =======================================
// loop counter to clock out all registers
// =======================================
reg [5:0] loop_cnt = `DAC_NUM_REGS; // initialized to cnt_max so that the WRITE SM isn't automatically triggered
reg loop_cnt_ena;

wire loop_cnt_max;
assign loop_cnt_max = (loop_cnt == `DAC_NUM_REGS) ? 1'b1 : 1'b0;

always @ (posedge slow_clk)
begin
    if (strobe)
        loop_cnt[5:0] <= 6'b000000;
    else if (loop_cnt_ena)
        loop_cnt[5:0] <= loop_cnt[5:0] + 6'b000001; 
    else
        loop_cnt[5:0] <= loop_cnt[5:0];
end


// ====================================
// state machine to write the registers
// ====================================
always @ (posedge slow_clk)
begin
    if (resetS)
        begin
            dac_reg_addr[4:0] <= 5'b00000;
            sreg_strobe <= 1'b0;
            loop_cnt_ena <= 1'b0;

            dac_state <= WRITE_IDLE;
        end
    else
        begin
            case (dac_state)
                WRITE_IDLE : begin
                    sreg_strobe <= 1'b0;
                    loop_cnt_ena <= 1'b0;

                    if (!loop_cnt_max)
                        begin               
                            dac_state <= WRITE_COUNT;
                            dac_reg_addr[4:0] <= dac_reg_addr[4:0];
                        end
                    else
                        begin
                            dac_state <= WRITE_IDLE;
                            dac_reg_addr[4:0] <= 5'b00000;
                        end
                    end
            
                WRITE_COUNT : begin
                    dac_reg_addr[4:0] <= dac_reg_addr[4:0];
                    sreg_strobe <= 1'b0;
                    loop_cnt_ena <= 1'b1;

                    dac_state <= WRITE_LOAD;
                end
                               
                WRITE_LOAD : begin
                    dac_reg_addr[4:0] <= dac_reg_addr[4:0];
                    sreg_strobe <= 1'b1;
                    loop_cnt_ena <= 1'b0;

                    if (sreg_ready) // wait here until the shift reg starts shifting                       
                        dac_state <= WRITE_LOAD;
                    else
                        dac_state <= WRITE_SHIFT;
                end
                
                WRITE_SHIFT : begin
                    dac_reg_addr[4:0] <= dac_reg_addr[4:0];
                    sreg_strobe <= 1'b0;
                    loop_cnt_ena <= 1'b0;

                    if (sreg_ready) // wait here until the shift reg stops shifting
                        dac_state <= WRITE_INCREMENT;
                    else
                        dac_state <= WRITE_SHIFT;
                end
                
                WRITE_INCREMENT : begin
                    dac_reg_addr[4:0] <= dac_reg_addr[4:0] + 1'b1;
                    sreg_strobe <= 1'b0;
                    loop_cnt_ena <= 1'b0;

                    dac_state <= WRITE_IDLE;
                end
            endcase
        end
end


// =================
// debug assignments
// =================
assign debug[2] = slow_clk;
assign debug[1] = loop_cnt_max;
assign debug[0] = scntrl_reg_out[0];
 

endmodule
