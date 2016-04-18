`include "clk_synth_regs.txt"

//*************************************************************************
// NOTE:  Modified to support LMK04906 - 7/16/15
//*************************************************************************

module clk_synth_intf (
    input clk50,
    input clk50_reset,

    // inputs from IPbus
    input io_clk,            // ipbus interface clock
    input io_reset,          // ipbus interface reset    
    input io_sel,            // this module has been selected for an I/O operation
    input io_sync,           // start the I/O operation
    input [19:0] io_addr,    // local slave address, memory or register
    input io_wr_en,          // this is a write operation, enable target for one clock
    input [31:0] io_wr_data, // data to write for write operations

    // unused
    input io_rd_en,                     // this is a read operation, enable readback logic
    output [31:0] io_rd_data,           // data returned for read operations
    output io_rd_ack,                   // 'write' data has been stored, 'read' data is ready

    // outputs to clock synthesizer
    output dclk,
    output ddat,
    output reg dlen,
    output sync,

    output [2:0] debug 
);


//*************************************************************************
// static assignments
//*************************************************************************
assign dclk = slow_clk_180;


//*************************************************************************
// synchronize state machine inputs
//*************************************************************************
reg resetS;

always @ (posedge slow_clk)
begin
    resetS <= clk50_reset;
end


// ====================================================================
// startup state machine to configure default settings
// ====================================================================
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
        
        // wait for >3 ms after power is delivered to clock synthesizer
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
        // this will initiate the configuration to the clock synthesizer
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


//*************************************************************************
// IPbus interface used to update register values
//*************************************************************************
//address decoding
wire reg_wr_en, scntrlreg_sel;
wire s25reg_sel, s24reg_sel, s23reg_sel, s22reg_sel, s21reg_sel, s20reg_sel, s19reg_sel, s18reg_sel,
     s17reg_sel, s16reg_sel, s15reg_sel, s14reg_sel, s13reg_sel, s12reg_sel, s11reg_sel, s10reg_sel,
     s09reg_sel, s08reg_sel, s07reg_sel, s06reg_sel, s05reg_sel, s04reg_sel, s03reg_sel, s02reg_sel,
     s01reg_sel, s00reg_sel;

assign reg_wr_en  = io_sync & io_wr_en;

assign scntrlreg_sel = io_sel && (io_addr[4:0] == 5'b11010);
assign    s25reg_sel = io_sel && (io_addr[4:0] == 5'b11001);    // clk synth reg 31
assign    s24reg_sel = io_sel && (io_addr[4:0] == 5'b11000);    // clk synth reg 30 
assign    s23reg_sel = io_sel && (io_addr[4:0] == 5'b10111);    // clk synth reg 29
assign    s22reg_sel = io_sel && (io_addr[4:0] == 5'b10110);    // clk synth reg 28
assign    s21reg_sel = io_sel && (io_addr[4:0] == 5'b10101);    // clk synth reg 27
assign    s20reg_sel = io_sel && (io_addr[4:0] == 5'b10100);    // clk synth reg 26
assign    s19reg_sel = io_sel && (io_addr[4:0] == 5'b10011);    // clk synth reg 25
assign    s18reg_sel = io_sel && (io_addr[4:0] == 5'b10010);    // clk synth reg 24
assign    s17reg_sel = io_sel && (io_addr[4:0] == 5'b10001);    // clk synth reg 16
assign    s16reg_sel = io_sel && (io_addr[4:0] == 5'b10000);    // clk synth reg 15
assign    s15reg_sel = io_sel && (io_addr[4:0] == 5'b01111);    // clk synth reg 14
assign    s14reg_sel = io_sel && (io_addr[4:0] == 5'b01110);    // clk synth reg 13
assign    s13reg_sel = io_sel && (io_addr[4:0] == 5'b01101);    // clk synth reg 12
assign    s12reg_sel = io_sel && (io_addr[4:0] == 5'b01100);    // clk synth reg 11
assign    s11reg_sel = io_sel && (io_addr[4:0] == 5'b01011);    // clk synth reg 10
assign    s10reg_sel = io_sel && (io_addr[4:0] == 5'b01010);    // clk synth reg 9
assign    s09reg_sel = io_sel && (io_addr[4:0] == 5'b01001);    // clk synth reg 8
assign    s08reg_sel = io_sel && (io_addr[4:0] == 5'b01000);    // clk synth reg 7
assign    s07reg_sel = io_sel && (io_addr[4:0] == 5'b00111);    // clk synth reg 6
assign    s06reg_sel = io_sel && (io_addr[4:0] == 5'b00110);    // clk synth reg 5
assign    s05reg_sel = io_sel && (io_addr[4:0] == 5'b00101);    // clk synth reg 4
assign    s04reg_sel = io_sel && (io_addr[4:0] == 5'b00100);    // clk synth reg 3
assign    s03reg_sel = io_sel && (io_addr[4:0] == 5'b00011);    // clk synth reg 2
assign    s02reg_sel = io_sel && (io_addr[4:0] == 5'b00010);    // clk synth reg 1
assign    s01reg_sel = io_sel && (io_addr[4:0] == 5'b00001);    // clk synth reg 0
assign    s00reg_sel = io_sel && (io_addr[4:0] == 5'b00000);    // clk synth reg 0, initial reset


// ====================================================================
// Recommended programming sequence:
//     R0 to R31
//
// Notes:
//     s[#] notation indicates the order of data sent to the clk synth
//          and not the clk synth register number
// ====================================================================

wire [31:0] scntrl_reg_out; // LSB controls the strobe

// s[#]_reg_out wires used to write to the clk synth
// these wires are driven by the reg inside the reg32_ce2 blocks

wire [31:0] s25_reg_out;    // clk synth reg 31
wire [31:0] s24_reg_out;    // clk synth reg 30 
wire [31:0] s23_reg_out;    // clk synth reg 29
wire [31:0] s22_reg_out;    // clk synth reg 28
wire [31:0] s21_reg_out;    // clk synth reg 27
wire [31:0] s20_reg_out;    // clk synth reg 26
wire [31:0] s19_reg_out;    // clk synth reg 25
wire [31:0] s18_reg_out;    // clk synth reg 24
wire [31:0] s17_reg_out;    // clk synth reg 16
wire [31:0] s16_reg_out;    // clk synth reg 15
wire [31:0] s15_reg_out;    // clk synth reg 14
wire [31:0] s14_reg_out;    // clk synth reg 13
wire [31:0] s13_reg_out;    // clk synth reg 12
wire [31:0] s12_reg_out;    // clk synth reg 11
wire [31:0] s11_reg_out;    // clk synth reg 10
wire [31:0] s10_reg_out;    // clk synth reg 9
wire [31:0] s09_reg_out;    // clk synth reg 8
wire [31:0] s08_reg_out;    // clk synth reg 7
wire [31:0] s07_reg_out;    // clk synth reg 6
wire [31:0] s06_reg_out;    // clk synth reg 5
wire [31:0] s05_reg_out;    // clk synth reg 4
wire [31:0] s04_reg_out;    // clk synth reg 3
wire [31:0] s03_reg_out;    // clk synth reg 2
wire [31:0] s02_reg_out;    // clk synth reg 1
wire [31:0] s01_reg_out;    // clk synth reg 0
wire [31:0] s00_reg_out;    // clk synth reg 0, initial reset

wire rst_reg;    // want the reg_out values to be set to default when IPbus reset or the startup reset is asserted
wire rst_cntrl;  // want the cntrl_reg_out values to be set to default when IPbus reset or the startup reset is asserted
assign rst_reg   = resetS | startup_rst_reg;
assign rst_cntrl = resetS | startup_rst_cntrl;

reg32_ce2 scntrl_reg(.in(io_wr_data[31:0]), .reset(rst_cntrl), .def_value(32'h00000001), .out(scntrl_reg_out[31:0]), .clk(io_clk), .clk_en1(reg_wr_en), .clk_en2(scntrlreg_sel));

reg32_ce2 s25_reg(.in(io_wr_data[31:0]), .reset(rst_reg), .def_value(`CS_DEF_REG31),      .out(s25_reg_out[31:0]), .clk(io_clk), .clk_en1(reg_wr_en), .clk_en2(s25reg_sel));
reg32_ce2 s24_reg(.in(io_wr_data[31:0]), .reset(rst_reg), .def_value(`CS_DEF_REG30),      .out(s24_reg_out[31:0]), .clk(io_clk), .clk_en1(reg_wr_en), .clk_en2(s24reg_sel));
reg32_ce2 s23_reg(.in(io_wr_data[31:0]), .reset(rst_reg), .def_value(`CS_DEF_REG29),      .out(s23_reg_out[31:0]), .clk(io_clk), .clk_en1(reg_wr_en), .clk_en2(s23reg_sel));
reg32_ce2 s22_reg(.in(io_wr_data[31:0]), .reset(rst_reg), .def_value(`CS_DEF_REG28),      .out(s22_reg_out[31:0]), .clk(io_clk), .clk_en1(reg_wr_en), .clk_en2(s22reg_sel));
reg32_ce2 s21_reg(.in(io_wr_data[31:0]), .reset(rst_reg), .def_value(`CS_DEF_REG27),      .out(s21_reg_out[31:0]), .clk(io_clk), .clk_en1(reg_wr_en), .clk_en2(s21reg_sel));
reg32_ce2 s20_reg(.in(io_wr_data[31:0]), .reset(rst_reg), .def_value(`CS_DEF_REG26),      .out(s20_reg_out[31:0]), .clk(io_clk), .clk_en1(reg_wr_en), .clk_en2(s20reg_sel));
reg32_ce2 s19_reg(.in(io_wr_data[31:0]), .reset(rst_reg), .def_value(`CS_DEF_REG25),      .out(s19_reg_out[31:0]), .clk(io_clk), .clk_en1(reg_wr_en), .clk_en2(s19reg_sel));
reg32_ce2 s18_reg(.in(io_wr_data[31:0]), .reset(rst_reg), .def_value(`CS_DEF_REG24),      .out(s18_reg_out[31:0]), .clk(io_clk), .clk_en1(reg_wr_en), .clk_en2(s18reg_sel));
reg32_ce2 s17_reg(.in(io_wr_data[31:0]), .reset(rst_reg), .def_value(`CS_DEF_REG16),      .out(s17_reg_out[31:0]), .clk(io_clk), .clk_en1(reg_wr_en), .clk_en2(s17reg_sel));
reg32_ce2 s16_reg(.in(io_wr_data[31:0]), .reset(rst_reg), .def_value(`CS_DEF_REG15),      .out(s16_reg_out[31:0]), .clk(io_clk), .clk_en1(reg_wr_en), .clk_en2(s16reg_sel));
reg32_ce2 s15_reg(.in(io_wr_data[31:0]), .reset(rst_reg), .def_value(`CS_DEF_REG14),      .out(s15_reg_out[31:0]), .clk(io_clk), .clk_en1(reg_wr_en), .clk_en2(s15reg_sel));
reg32_ce2 s14_reg(.in(io_wr_data[31:0]), .reset(rst_reg), .def_value(`CS_DEF_REG13),      .out(s14_reg_out[31:0]), .clk(io_clk), .clk_en1(reg_wr_en), .clk_en2(s14reg_sel));
reg32_ce2 s13_reg(.in(io_wr_data[31:0]), .reset(rst_reg), .def_value(`CS_DEF_REG12),      .out(s13_reg_out[31:0]), .clk(io_clk), .clk_en1(reg_wr_en), .clk_en2(s13reg_sel));
reg32_ce2 s12_reg(.in(io_wr_data[31:0]), .reset(rst_reg), .def_value(`CS_DEF_REG11),      .out(s12_reg_out[31:0]), .clk(io_clk), .clk_en1(reg_wr_en), .clk_en2(s12reg_sel));
reg32_ce2 s11_reg(.in(io_wr_data[31:0]), .reset(rst_reg), .def_value(`CS_DEF_REG10),      .out(s11_reg_out[31:0]), .clk(io_clk), .clk_en1(reg_wr_en), .clk_en2(s11reg_sel));
reg32_ce2 s10_reg(.in(io_wr_data[31:0]), .reset(rst_reg), .def_value(`CS_DEF_REG09),      .out(s10_reg_out[31:0]), .clk(io_clk), .clk_en1(reg_wr_en), .clk_en2(s10reg_sel));
reg32_ce2 s09_reg(.in(io_wr_data[31:0]), .reset(rst_reg), .def_value(`CS_DEF_REG08),      .out(s09_reg_out[31:0]), .clk(io_clk), .clk_en1(reg_wr_en), .clk_en2(s09reg_sel));
reg32_ce2 s08_reg(.in(io_wr_data[31:0]), .reset(rst_reg), .def_value(`CS_DEF_REG07),      .out(s08_reg_out[31:0]), .clk(io_clk), .clk_en1(reg_wr_en), .clk_en2(s08reg_sel));
reg32_ce2 s07_reg(.in(io_wr_data[31:0]), .reset(rst_reg), .def_value(`CS_DEF_REG06),      .out(s07_reg_out[31:0]), .clk(io_clk), .clk_en1(reg_wr_en), .clk_en2(s07reg_sel));
reg32_ce2 s06_reg(.in(io_wr_data[31:0]), .reset(rst_reg), .def_value(`CS_DEF_REG05),      .out(s06_reg_out[31:0]), .clk(io_clk), .clk_en1(reg_wr_en), .clk_en2(s06reg_sel));
reg32_ce2 s05_reg(.in(io_wr_data[31:0]), .reset(rst_reg), .def_value(`CS_DEF_REG04),      .out(s05_reg_out[31:0]), .clk(io_clk), .clk_en1(reg_wr_en), .clk_en2(s05reg_sel));
reg32_ce2 s04_reg(.in(io_wr_data[31:0]), .reset(rst_reg), .def_value(`CS_DEF_REG03),      .out(s04_reg_out[31:0]), .clk(io_clk), .clk_en1(reg_wr_en), .clk_en2(s04reg_sel));
reg32_ce2 s03_reg(.in(io_wr_data[31:0]), .reset(rst_reg), .def_value(`CS_DEF_REG02),      .out(s03_reg_out[31:0]), .clk(io_clk), .clk_en1(reg_wr_en), .clk_en2(s03reg_sel));
reg32_ce2 s02_reg(.in(io_wr_data[31:0]), .reset(rst_reg), .def_value(`CS_DEF_REG01),      .out(s02_reg_out[31:0]), .clk(io_clk), .clk_en1(reg_wr_en), .clk_en2(s02reg_sel));
reg32_ce2 s01_reg(.in(io_wr_data[31:0]), .reset(rst_reg), .def_value(`CS_DEF_REG00),      .out(s01_reg_out[31:0]), .clk(io_clk), .clk_en1(reg_wr_en), .clk_en2(s01reg_sel));
reg32_ce2 s00_reg(.in(io_wr_data[31:0]), .reset(rst_reg), .def_value(`CS_DEF_REG00_INIT), .out(s00_reg_out[31:0]), .clk(io_clk), .clk_en1(reg_wr_en), .clk_en2(s00reg_sel));


// use the LSB of the control register to generate a strobe which will be used
// to reset the loop counter and thus initiate a new programming sequence

// synchronize the LSB with the slow_clk
reg scntrl_LSB;

always @ (posedge slow_clk)
begin
    scntrl_LSB <= scntrl_reg_out[0];
end


//*************************************************************************
// generate a single clock strobe based on scntrlLSB
// it's triggered by sctrlLSB going from low to high
//*************************************************************************
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


//*************************************************************************
// generate a low speed clock (6.25 MHz / 160 ns)
//*************************************************************************
reg [2:0] clk_cnt;
wire slow_clk;
wire slow_clk_180;

always @ (posedge clk50)
begin
    clk_cnt[2:0] <= clk_cnt[2:0] + 1'b1;
end 

assign slow_clk = clk_cnt[2];
assign slow_clk_180 = !slow_clk;


//*************************************************************************
// shift register with counter, LSB wired to output of module
//
// sreg_strobe - starts the shifting mechanism
// payload     - what will be shifted
// sreg_ready  - active high status signal
//*************************************************************************
reg sreg_strobe;
reg [31:0] sreg;
reg [5:0] sreg_cnt = 6'b000000;
reg sreg_ready;

parameter SHIFT_IDLE     = 2'b00;
parameter SHIFT_LOAD     = 2'b01;
parameter SHIFT_SHIFTING = 2'b10;

reg [1:0] shift_state = SHIFT_IDLE;

reg sreg_cnt_ena;
reg sreg_cnt_reset;

wire sreg_cnt_max;
assign sreg_cnt_max = (sreg_cnt == 6'b011110) ? 1'b1 : 1'b0;

always @ (posedge slow_clk)
begin
    if (sreg_cnt_reset)
        sreg_cnt[5:0] <= 6'b000000;
    else if (sreg_cnt_ena)
        sreg_cnt[5:0] <= sreg_cnt[5:0] + 6'b000001; 
    else
        sreg_cnt[5:0] <= sreg_cnt[5:0];
end

reg sreg_load;

always @ (posedge slow_clk)
begin
    if (sreg_load)
        sreg[31:0] <= synth_reg[31:0];
    else
        sreg[31:0] <= {sreg[30:0], 1'b0};        
end

assign ddat = sreg[31];

always @ (posedge slow_clk)
begin
    if (resetS)
        begin
            sreg_load <= 1'b1;
            sreg_cnt_reset <= 1'b1;
            sreg_cnt_ena <= 1'b0;
            dlen <= 1'b1;
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
                    dlen <= 1'b1;
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
                    dlen <= 1'b1;
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
                    dlen <= 1'b0;
                    sreg_ready <= 1'b0;

                    if (sreg_cnt_max)
                        shift_state <= SHIFT_IDLE;
                    else
                        shift_state <= SHIFT_SHIFTING;
                end
            endcase
        end
end


//*************************************************************************
// array of registers
//*************************************************************************
reg [4:0] synth_reg_addr = 5'd0;
reg [31:0] synth_reg = 32'd0;

always @ (posedge slow_clk)
begin
    case (synth_reg_addr[4:0])
        5'b00000 : synth_reg[31:0] = s00_reg_out[31:0];
        5'b00001 : synth_reg[31:0] = s01_reg_out[31:0];
        5'b00010 : synth_reg[31:0] = s02_reg_out[31:0];
        5'b00011 : synth_reg[31:0] = s03_reg_out[31:0];
        5'b00100 : synth_reg[31:0] = s04_reg_out[31:0];
        5'b00101 : synth_reg[31:0] = s05_reg_out[31:0];
        5'b00110 : synth_reg[31:0] = s06_reg_out[31:0];
        5'b00111 : synth_reg[31:0] = s07_reg_out[31:0];
        5'b01000 : synth_reg[31:0] = s08_reg_out[31:0];
        5'b01001 : synth_reg[31:0] = s09_reg_out[31:0];
        5'b01010 : synth_reg[31:0] = s10_reg_out[31:0];
        5'b01011 : synth_reg[31:0] = s11_reg_out[31:0];
        5'b01100 : synth_reg[31:0] = s12_reg_out[31:0];
        5'b01101 : synth_reg[31:0] = s13_reg_out[31:0];
        5'b01110 : synth_reg[31:0] = s14_reg_out[31:0];
        5'b01111 : synth_reg[31:0] = s15_reg_out[31:0];
        5'b10000 : synth_reg[31:0] = s16_reg_out[31:0];
        5'b10001 : synth_reg[31:0] = s17_reg_out[31:0];
        5'b10010 : synth_reg[31:0] = s18_reg_out[31:0];
        5'b10011 : synth_reg[31:0] = s19_reg_out[31:0];
        5'b10100 : synth_reg[31:0] = s20_reg_out[31:0];
        5'b10101 : synth_reg[31:0] = s21_reg_out[31:0];
        5'b10110 : synth_reg[31:0] = s22_reg_out[31:0];
        5'b10111 : synth_reg[31:0] = s23_reg_out[31:0];
        5'b11000 : synth_reg[31:0] = s24_reg_out[31:0];
        5'b11001 : synth_reg[31:0] = s25_reg_out[31:0];
    endcase
end


//*************************************************************************
// automatic configuration of all of the synth registers
//*************************************************************************
parameter WRITE_IDLE      = 3'b000;
parameter WRITE_COUNT     = 3'b001;
parameter WRITE_LOAD      = 3'b010;
parameter WRITE_SHIFT     = 3'b011;
parameter WRITE_INCREMENT = 3'b100;
parameter SYNC_LOW        = 3'b101;
parameter SYNC_HIGH       = 3'b110;

reg [2:0] synth_state = WRITE_IDLE;

// ====================================================================
// signals for sync functionality
// ====================================================================
reg [4:0] sync_cnt = 5'b00000; // counter to keep sync wire low for >4 clock cycles
reg sync_asserted = 1'b0;      // flag to remember when sync has already been asserted
reg sync_level;                // flag to drive sync wire to either low (1'b0) or high (1'b1)

assign sync = (sync_level) ? 1'b1 : 1'b0;


//************************************************
// loop counter to clock out all registers
//************************************************
reg [5:0] loop_cnt = `CS_NUM_REGS; // initialized to cnt_max so that the WRITE SM isn't automatically triggered
reg loop_cnt_ena;

wire loop_cnt_max;
assign loop_cnt_max = (loop_cnt == `CS_NUM_REGS) ? 1'b1 : 1'b0;

always @ (posedge slow_clk)
begin
    if (strobe)
        loop_cnt[5:0] <= 6'b000000;
    else if (loop_cnt_ena)
        loop_cnt[5:0] <= loop_cnt[5:0] + 6'b000001; 
    else
        loop_cnt[5:0] <= loop_cnt[5:0];
end


//************************************************
// state machine to write the registers
//************************************************
always @ (posedge slow_clk)
begin
    if (resetS)
        begin
            synth_reg_addr[4:0] <= 5'b00000;
            sreg_strobe <= 1'b0;
            loop_cnt_ena <= 1'b0;
            sync_cnt[4:0] <= 5'b00000;
            sync_asserted <= 1'b0;
            sync_level <= 1'b1;

            synth_state <= WRITE_IDLE;
        end
    else
        begin
            case (synth_state)
                WRITE_IDLE : begin
                    sreg_strobe <= 1'b0;
                    loop_cnt_ena <= 1'b0;
                    sync_cnt[4:0] <= 5'b00000;
                    sync_level <= 1'b1;

                    if (!loop_cnt_max)
                        begin               
                            synth_state <= WRITE_COUNT;
                            synth_reg_addr[4:0] <= synth_reg_addr[4:0];
                        end
                    else if (!sync_asserted && startup_done) // don't toggle sync wire before startup configuration is complete
                        begin
                            synth_state <= SYNC_LOW;
                            synth_reg_addr[4:0] <= 5'b00000;
                        end
                    else
                        begin
                            synth_state <= WRITE_IDLE;
                            synth_reg_addr[4:0] <= 5'b00000;
                        end
                    end
            
                WRITE_COUNT : begin
                    synth_reg_addr[4:0] <= synth_reg_addr[4:0];
                    sreg_strobe <= 1'b0;
                    loop_cnt_ena <= 1'b1;
                    sync_asserted <= 1'b0;

                    synth_state <= WRITE_LOAD;
                end
                               
                WRITE_LOAD : begin
                    synth_reg_addr[4:0] <= synth_reg_addr[4:0];
                    sreg_strobe <= 1'b1;
                    loop_cnt_ena <= 1'b0;
                    sync_asserted <= 1'b0;

                    if (sreg_ready)              // wait here until the shift reg starts shifting                       
                        synth_state <= WRITE_LOAD;
                    else
                        synth_state <= WRITE_SHIFT;
                end
                
                WRITE_SHIFT : begin
                    synth_reg_addr[4:0] <= synth_reg_addr[4:0];
                    sreg_strobe <= 1'b0;
                    loop_cnt_ena <= 1'b0;
                    sync_asserted <= 1'b0;

                    if (sreg_ready)             // wait here until the shift reg stops shifting
                        synth_state <= WRITE_INCREMENT;
                    else
                        synth_state <= WRITE_SHIFT;
                end
                
                WRITE_INCREMENT : begin
                    synth_reg_addr[4:0] <= synth_reg_addr[4:0] + 1'b1;
                    sreg_strobe <= 1'b0;
                    loop_cnt_ena <= 1'b0;
                    sync_asserted <= 1'b0;

                    synth_state <= WRITE_IDLE;
                end

                SYNC_LOW : begin
                    sync_cnt[4:0] <= sync_cnt[4:0] + 1'b1;
                    sync_level <= 1'b0;
                    sync_asserted <= 1'b0;

                    if (sync_cnt[4])
                        synth_state <= SYNC_HIGH;
                    else
                        synth_state <= SYNC_LOW;
                end

                SYNC_HIGH : begin
                    sync_cnt[4:0] <= sync_cnt[4:0] + 1'b1;
                    sync_level <= 1'b1;
                    sync_asserted <= 1'b1;

                    if (!sync_cnt[4])
                        synth_state <= WRITE_IDLE;
                    else
                        synth_state <= SYNC_HIGH;
                end
            endcase
        end
end


//*************************************************************************
// debug assignments
//*************************************************************************
assign debug[2] = slow_clk;
assign debug[1] = loop_cnt_max;
assign debug[0] = scntrl_reg_out[0];
 

endmodule
