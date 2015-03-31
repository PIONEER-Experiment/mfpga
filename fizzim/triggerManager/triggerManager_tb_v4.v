`timescale 1ns / 100ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/19/2014 07:14:54 PM
// Design Name: 
// Module Name: triggerManager_tb
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module triggerManager_tb;

    // Inputs
    reg [4:0] done;
    reg trigger;
    reg clk;
    reg reset;
    
    // Outputs
    wire [4:0] go;
    wire [7:0] fillNum;
    
    // Instantiate the Device Under Test
    triggerManager DUT (
        .done(done),
        .trigger(trigger),
        .clk(clk),
        .reset(reset),
        .go(go),
        .fillNum(fillNum)
    );
        
    initial begin
        // Initialize inputs
        done = 5'b00000;
        trigger = 0;
        clk = 0;
        reset = 1;
        #20 reset = 0;
        #20 reset = 1;
        #20 trigger = 1;
        #20 trigger = 0;
        #20 done = 5'b10000;
        #20 done = 5'b10010;
        #20 done = 5'b11010;
        #20 done = 5'b11011;
        #20 done = 5'b11111;
        #20 done = 5'b00000;

        #20 trigger = 1;
        #20 trigger = 0;
        #20 done = 5'b10000;
        #20 done = 5'b10110;
        #20 done = 5'b11110;
        #20 done = 5'b11111;
        #20 done = 5'b00000;
        
        #20 trigger = 1;
        #20 trigger = 0;
        #20 done = 5'b11111;
        #20 done = 5'b00000;
        
        #20 reset = 0;
        #20 reset = 1;
        
        #50 $finish;
    
    end
    
    always
        #5 clk = ~clk;

endmodule
