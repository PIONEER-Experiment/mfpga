`timescale 1ns / 1ps

module clk_synth_intf(
    input clk50,
    input clk50_reset,
    input io_clk,                       // ipbus interface clock
    input io_reset,         // ipbus interface reset    
    input io_sel,                       // this module has been selected for an I/O operation
    input io_sync,                      // start the I/O operation
    input [19:0] io_addr,               // local slave address, memory or register
    input io_rd_en,                     // this is a read operation, enable readback logic
    input io_wr_en,                     // this is a write operation, enable target for one clock
    input [31:0] io_wr_data,            // data to write for write operations

    output [31:0] io_rd_data,           // data returned for read operations
    output io_rd_ack,                   // 'write' data has been stored, 'read' data is ready

    output dclk,
    output ddat,
    output reg dlen,
    output goe,
    output sync,
    output [2:0] debug 
);

reg resetS;


//*************************************************************************
// static assignments
//*************************************************************************
assign dclk = slow_clk_180;
assign goe = 1'b1;
assign sync = 1'b1;

//*************************************************************************
// synchronize state machine inputs
//*************************************************************************
always @ (posedge slow_clk)
begin
    resetS <= clk50_reset;
end

//*************************************************************************
// ipbus interface used to update register values
//************************************************************************

//address decoding
wire reg_wr_en, scntrlreg_sel, s16reg_sel, s15reg_sel, s14reg_sel, s13reg_sel, s12reg_sel, s11reg_sel, s10reg_sel, s09reg_sel,
       s08reg_sel, s07reg_sel, s06reg_sel, s05reg_sel, s04reg_sel, s03reg_sel, s02reg_sel, s01reg_sel, s00reg_sel;

assign reg_wr_en  = io_sync & io_wr_en;
assign scntrlreg_sel = io_sel && (io_addr[4:0] == 5'b10001);
assign s16reg_sel = io_sel && (io_addr[4:0] == 5'b10000);
assign s15reg_sel = io_sel && (io_addr[4:0] == 5'b01111);
assign s14reg_sel = io_sel && (io_addr[4:0] == 5'b01110);
assign s13reg_sel = io_sel && (io_addr[4:0] == 5'b01101);
assign s12reg_sel = io_sel && (io_addr[4:0] == 5'b01100);
assign s11reg_sel = io_sel && (io_addr[4:0] == 5'b01011);
assign s10reg_sel = io_sel && (io_addr[4:0] == 5'b01010);
assign s09reg_sel = io_sel && (io_addr[4:0] == 5'b01001);
assign s08reg_sel = io_sel && (io_addr[4:0] == 5'b01000);
assign s07reg_sel = io_sel && (io_addr[4:0] == 5'b00111);
assign s06reg_sel = io_sel && (io_addr[4:0] == 5'b00110);
assign s05reg_sel = io_sel && (io_addr[4:0] == 5'b00101);
assign s04reg_sel = io_sel && (io_addr[4:0] == 5'b00100);
assign s03reg_sel = io_sel && (io_addr[4:0] == 5'b00011);
assign s02reg_sel = io_sel && (io_addr[4:0] == 5'b00010);
assign s01reg_sel = io_sel && (io_addr[4:0] == 5'b00001);
assign s00reg_sel = io_sel && (io_addr[4:0] == 5'b00000);

wire [31:0] scntrl_reg_out;
wire [31:0] s16_reg_out;
wire [31:0] s15_reg_out;
wire [31:0] s14_reg_out;
wire [31:0] s13_reg_out;
wire [31:0] s12_reg_out;
wire [31:0] s11_reg_out;
wire [31:0] s10_reg_out;
wire [31:0] s09_reg_out;
wire [31:0] s08_reg_out;
wire [31:0] s07_reg_out;
wire [31:0] s06_reg_out;
wire [31:0] s05_reg_out;
wire [31:0] s04_reg_out;
wire [31:0] s03_reg_out;
wire [31:0] s02_reg_out;
wire [31:0] s01_reg_out;
wire [31:0] s00_reg_out;

reg32_ce2 scntrl_reg(.in(io_wr_data[31:0]), .reset(io_reset), .out(scntrl_reg_out[31:0]), .clk(io_clk), .clk_en1(reg_wr_en), .clk_en2(scntrlreg_sel));
reg32_ce2 s16_reg(.in(io_wr_data[31:0]), .reset(io_reset), .out(s16_reg_out[31:0]), .clk(io_clk), .clk_en1(reg_wr_en), .clk_en2(s16reg_sel));
reg32_ce2 s15_reg(.in(io_wr_data[31:0]), .reset(io_reset), .out(s15_reg_out[31:0]), .clk(io_clk), .clk_en1(reg_wr_en), .clk_en2(s15reg_sel));
reg32_ce2 s14_reg(.in(io_wr_data[31:0]), .reset(io_reset), .out(s14_reg_out[31:0]), .clk(io_clk), .clk_en1(reg_wr_en), .clk_en2(s14reg_sel));
reg32_ce2 s13_reg(.in(io_wr_data[31:0]), .reset(io_reset), .out(s13_reg_out[31:0]), .clk(io_clk), .clk_en1(reg_wr_en), .clk_en2(s13reg_sel));
reg32_ce2 s12_reg(.in(io_wr_data[31:0]), .reset(io_reset), .out(s12_reg_out[31:0]), .clk(io_clk), .clk_en1(reg_wr_en), .clk_en2(s12reg_sel));
reg32_ce2 s11_reg(.in(io_wr_data[31:0]), .reset(io_reset), .out(s11_reg_out[31:0]), .clk(io_clk), .clk_en1(reg_wr_en), .clk_en2(s11reg_sel));
reg32_ce2 s10_reg(.in(io_wr_data[31:0]), .reset(io_reset), .out(s10_reg_out[31:0]), .clk(io_clk), .clk_en1(reg_wr_en), .clk_en2(s10reg_sel));
reg32_ce2 s09_reg(.in(io_wr_data[31:0]), .reset(io_reset), .out(s09_reg_out[31:0]), .clk(io_clk), .clk_en1(reg_wr_en), .clk_en2(s09reg_sel));
reg32_ce2 s08_reg(.in(io_wr_data[31:0]), .reset(io_reset), .out(s08_reg_out[31:0]), .clk(io_clk), .clk_en1(reg_wr_en), .clk_en2(s09reg_sel));
reg32_ce2 s07_reg(.in(io_wr_data[31:0]), .reset(io_reset), .out(s07_reg_out[31:0]), .clk(io_clk), .clk_en1(reg_wr_en), .clk_en2(s07reg_sel));
reg32_ce2 s06_reg(.in(io_wr_data[31:0]), .reset(io_reset), .out(s06_reg_out[31:0]), .clk(io_clk), .clk_en1(reg_wr_en), .clk_en2(s06reg_sel));
reg32_ce2 s05_reg(.in(io_wr_data[31:0]), .reset(io_reset), .out(s05_reg_out[31:0]), .clk(io_clk), .clk_en1(reg_wr_en), .clk_en2(s05reg_sel));
reg32_ce2 s04_reg(.in(io_wr_data[31:0]), .reset(io_reset), .out(s04_reg_out[31:0]), .clk(io_clk), .clk_en1(reg_wr_en), .clk_en2(s04reg_sel));
reg32_ce2 s03_reg(.in(io_wr_data[31:0]), .reset(io_reset), .out(s03_reg_out[31:0]), .clk(io_clk), .clk_en1(reg_wr_en), .clk_en2(s03reg_sel));
reg32_ce2 s02_reg(.in(io_wr_data[31:0]), .reset(io_reset), .out(s02_reg_out[31:0]), .clk(io_clk), .clk_en1(reg_wr_en), .clk_en2(s02reg_sel));
reg32_ce2 s01_reg(.in(io_wr_data[31:0]), .reset(io_reset), .out(s01_reg_out[31:0]), .clk(io_clk), .clk_en1(reg_wr_en), .clk_en2(s01reg_sel));
reg32_ce2 s00_reg(.in(io_wr_data[31:0]), .reset(io_reset), .out(s00_reg_out[31:0]), .clk(io_clk), .clk_en1(reg_wr_en), .clk_en2(s00reg_sel));

// use the LSB of the control register to generate a strobe which will be used
// to reset the loop counter and thus initiate a new programming sequence


//synchronize the LSB with the slow_clk
reg scntrl_LSB;

always @ (posedge slow_clk)
begin
    scntrl_LSB <= scntrl_reg_out[0];
end

//generate a single clock strobe based on scntrlLSB

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
                if (!scntrl_LSB)
                    strobe_state <= STROBE_IDLE;
                else
                    strobe_state <= STROBE_TRIG;
                strobe <= 1'b0;
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
// generate a low speed clock
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
// payload - what will be shifted
// sreg_ready - active high status signal
//*************************************************************************
reg sreg_strobe;
reg [31:0] sreg;
wire [31:0] sreg_payload;
reg [5:0] sreg_cnt = 6'b100000;
reg sreg_ready;
parameter IDLE = 2'b00;
parameter LOAD = 2'b01;
parameter SHIFTING = 2'b10;

reg [1:0] shift_state = IDLE;

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
        sreg[31:0] <= {sreg[30:0],1'b0};        
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
            shift_state <= IDLE;
        end
    else
        begin
            case (shift_state)
                IDLE : begin
                    sreg_cnt_reset <= 1'b1;
                    sreg_cnt_ena <= 1'b0;
                    sreg_load <= 1'b1;                    
                    dlen <= 1'b1;
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
                    dlen <= 1'b1;
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
                    dlen <= 1'b0;
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
// array of registers
//*************************************************************************
reg [4:0] synth_reg_addr;
reg [31:0] synth_reg;

always @ (posedge slow_clk)
begin
/*    case (synth_reg_addr[4:0])
        5'b00000 : synth_reg[31:0] = 32'h00000017;
    5'b00001 : synth_reg[31:0] = 32'h01010100;//en,div=2
    5'b00010 : synth_reg[31:0] = 32'h01010101;//en,div=2
        5'b00011 : synth_reg[31:0] = 32'h01010102;//en,div=2
        5'b00100 : synth_reg[31:0] = 32'h01010103;//en,div=2
        5'b00101 : synth_reg[31:0] = 32'h01010104;//en,div=2
        5'b00110 : synth_reg[31:0] = 32'h00000005;
        5'b00111 : synth_reg[31:0] = 32'h08000076;
        5'b01000 : synth_reg[31:0] = 32'h00000007;
        5'b01001 : synth_reg[31:0] = 32'h00000008;
        5'b01010 : synth_reg[31:0] = 32'h00a22a09;
        5'b01011 : synth_reg[31:0] = 32'h0152000a;
        5'b01100 : synth_reg[31:0] = 32'h00650ccb;
        5'b01101 : synth_reg[31:0] = 32'h200200ac;
        5'b01110 : synth_reg[31:0] = 32'h0a14000d;
        5'b01111 : synth_reg[31:0] = 32'h1900004e;//osc_in=200,R2=4
        5'b10000 : synth_reg[31:0] = 32'h100001ef;//vco_div=2,N2=30
    endcase
*/    case (synth_reg_addr[4:0])
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
    endcase


end

//clock synth config notes:
//  -  these settings should yield a clock Fout = 750 MHz
//  -  200/4=50  ::  1500/30=50

//*************************************************************************
// automatic configuration of all of the synth registers
//*************************************************************************
parameter S1 = 3'b000;
parameter S2 = 3'b001;
parameter S3 = 3'b010;
parameter S4 = 3'b011;
parameter S5 = 3'b100;

reg [2:0] synth_state = S1;


//************************************************
// loop counter to clock out all registers
//************************************************

reg [5:0] loop_cnt = 6'b000000;
reg loop_cnt_ena;
//reg loop_cnt_reset;

wire loop_cnt_max;
assign loop_cnt_max = (loop_cnt == 6'b010001) ? 1'b1 : 1'b0;


always @ (posedge slow_clk)
begin
//    if (loop_cnt_reset)
    if (strobe)
    loop_cnt[5:0] <= 6'b000000;
    else if (loop_cnt_ena)
        loop_cnt[5:0] <= loop_cnt[5:0] + 6'b000001; 
    else
        loop_cnt[5:0] <= loop_cnt[5:0];
end

//************************************************
// state machine to wite the registers
//************************************************
always @ (posedge slow_clk)
begin
    if (resetS)
        begin
            synth_reg_addr[4:0] <= 5'b00000;
            sreg_strobe <= 1'b0;
            loop_cnt_ena <= 1'b0;
            //loop_cnt_reset <= 1'b1;
            synth_state <= S1;
        end
    else
       begin
        case (synth_state)
            // idle
                S1 : begin
                    //synth_reg_addr[4:0] <= synth_reg_addr[4:0];
                    sreg_strobe <= 1'b0;
                    loop_cnt_ena <= 1'b0;
                    //loop_cnt_reset <= 1'b0; //this makes the loop only fire once
                    if (!loop_cnt_max)
            begin               
                          synth_state <= S2;
                          synth_reg_addr[4:0] <= synth_reg_addr[4:0];
            end
            else
            begin
                          synth_state <= S1;
                          synth_reg_addr[4:0] <= 5'b00000;
                end
          end
        
            // count
             S2 : begin
                synth_reg_addr[4:0] <= synth_reg_addr[4:0];
                sreg_strobe <= 1'b0;
                loop_cnt_ena <= 1'b1;
                //loop_cnt_reset <= 1'b0;
                synth_state <= S3;
            end
                           
            // load
            S3 : begin
                synth_reg_addr[4:0] <= synth_reg_addr[4:0];
                sreg_strobe <= 1'b1;
                loop_cnt_ena <= 1'b0;
               //loop_cnt_reset <= 1'b0;
                if (sreg_ready)              // wait here until the shift reg starts shifting                       
                     synth_state <= S3;
                else
                     synth_state <= S4;
            end
            
            // shift
            S4 : begin
                synth_reg_addr[4:0] <= synth_reg_addr[4:0];
                sreg_strobe <= 1'b0;
                loop_cnt_ena <= 1'b0;
               // loop_cnt_reset <= 1'b0;                
                if (sreg_ready)             // wait here until the shift reg stops shifting
                    synth_state <= S5;
                else
                    synth_state <= S4;
            end
            
            // increment
            S5 : begin
                synth_reg_addr[4:0] <= synth_reg_addr[4:0] + 1'b1;
                sreg_strobe <= 1'b0;
                loop_cnt_ena <= 1'b0;
               //loop_cnt_reset <= 1'b0;
                synth_state <= S1;
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
