// Dynamic Reconfiguration Port (DRP) interface to the XADC for monitoring
// FPGA on-chip sensors, based on example design in UG480.

module xadc_interface (
    input dclk,
    input reset,
    output reg [15:0] measured_temp,
    output reg [15:0] measured_vccint,
    output reg [15:0] measured_vccaux,
    output reg [15:0] measured_vccbram,
    output wire over_temp,
    output wire alarm_temp,
    output wire alarm_vccint,
    output wire alarm_vccaux,
    output wire alarm_vccbram,
    output wire eoc,
    output wire eos
);

wire drdy;
wire [15:0] do_drp;
wire [ 7:0] alarm;

reg [6:0] daddr;
reg [1:0] den_reg;

parameter read_reg00     = 3'h0,
          reg00_waitdrdy = 3'h1,
          read_reg01     = 3'h2,
          reg01_waitdrdy = 3'h3,
          read_reg02     = 3'h4,
          reg02_waitdrdy = 3'h5,
          read_reg06     = 3'h6,
          reg06_waitdrdy = 3'h7;

reg [2:0] state = read_reg00;

always @(posedge dclk) begin
    if (reset) begin
        state <= read_reg00;
        den_reg <= 2'h0;
    end
    else begin
        case (state)
            read_reg00 : begin
                daddr = 7'h00;
                den_reg = 2'h2; // performing read
                if (eos == 1) begin
                    state <= reg00_waitdrdy;
                end
            end
            reg00_waitdrdy : begin
                if (drdy == 1) begin
                    measured_temp = do_drp;
                    state <= read_reg01;
                end
                else begin
                    den_reg = {1'b0, den_reg[1]};
                    state = state;
                end
            end
            read_reg01 : begin
                daddr = 7'h01;
                den_reg = 2'h2; // performing read
                state <= reg01_waitdrdy;
            end
            reg01_waitdrdy : begin
                if (drdy == 1) begin
                    measured_vccint = do_drp;
                    state <= read_reg02;
                end
                else begin
                    den_reg = {1'b0, den_reg[1]};
                    state = state;
                end
            end
            read_reg02 : begin
                daddr = 7'h02;
                den_reg = 2'h2; // performing read
                state <= reg02_waitdrdy;
            end
            reg02_waitdrdy : begin
                if (drdy == 1) begin
                    measured_vccaux = do_drp;
                    state <= read_reg06;
                end
                else begin
                    den_reg = {1'b0, den_reg[1]};
                    state = state;
                end
            end
            read_reg06 : begin
                daddr = 7'h06;
                den_reg = 2'h2; // performing read
                state <= reg06_waitdrdy;
            end
            reg06_waitdrdy : begin
                if (drdy == 1) begin
                    measured_vccbram = do_drp;
                    state <= read_reg00;
                    daddr = 7'h00;
                end
                else begin
                    den_reg = {1'b0, den_reg[1]};
                    state = state;
                end
            end
        endcase
    end
end

// Initializing the XADC Control Registers
XADC #(
    .INIT_40(16'h1000),             // Averaging of 16 selected for external channels
    .INIT_41(16'h2ef0),             // Continuous seq mode, Disable unused ALMs, Enable calibration
    .INIT_42(16'h0500),             // Set DCLK divides
    .INIT_48(16'h4700),             // CHSEL1 - enable TEMP, VCCINT, VCCAUX, VCCBRAM
    .INIT_49(16'h0000),             // CHSEL2 - disable all other channels
    .INIT_4A(16'h0000),             // SEQAVG1 disabled
    .INIT_4B(16'h0000),             // SEQAVG2 disabled
    .INIT_4C(16'h0000),             // SEQINMODE0
    .INIT_4D(16'h0000),             // SEQINMODE1
    .INIT_4E(16'h0000),             // SEQACQ0
    .INIT_4F(16'h0000),             // SEQACQ1
    .INIT_50(16'hb5ed),             // TEMP upper alarm trigger 85°C
    .INIT_51(16'h57e4),             // VCCINT upper alarm limit 1.03V
    .INIT_52(16'hA147),             // VCCAUX upper alarm limit 1.89V
    .INIT_53(16'hca33),             // OT upper alarm limit 125°C using automatic shutdown
    .INIT_54(16'h9a3a),             // TEMP lower alarm reset 60°C
    .INIT_55(16'h52c6),             // VCCINT lower alarm limit 0.97V
    .INIT_56(16'h9555),             // VCCAUX lower alarm limit 1.75V
    .INIT_57(16'hae4e),             // OT lower alarm reset 70°C
    .INIT_58(16'h5999),             // VCCBRAM upper alarm limit 1.05V
    .INIT_5C(16'h5111),             // VCCBRAM lower alarm limit 0.95V
    .SIM_DEVICE("7SERIES"),         // 
    .SIM_MONITOR_FILE("design.txt") // Analog stimulus file for simulation
) XADC_INST (
    .CONVST(1'b0),     // not used
    .CONVSTCLK(1'b0),  // not used
    .DADDR(daddr),
    .DCLK(dclk),
    .DEN(den_reg[0]),
    .DI(16'h0000),     // not used
    .DWE(1'b0),        // not used
    .RESET(reset),
    .VAUXN(1'b0),      // not used
    .VAUXP(1'b0),      // not used
    .ALM(alarm),
    .BUSY(),           // not used
    .CHANNEL(),        // not used
    .DO(do_drp),
    .DRDY(drdy),
    .EOC(eoc),
    .EOS(eos),
    .JTAGBUSY(),       // not used
    .JTAGLOCKED(),     // not used
    .JTAGMODIFIED(),   // not used
    .OT(over_temp),
    .MUXADDR(),        // not used
    .VP(1'b0),         // not used
    .VN(1'b0)          // not used
);

assign alarm_temp    = alarm[0];
assign alarm_vccint  = alarm[1];
assign alarm_vccaux  = alarm[2];
assign alarm_vccbram = alarm[3];

endmodule
