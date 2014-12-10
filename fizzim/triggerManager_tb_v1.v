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
    reg done;
    reg ready;
    reg trigger;
    reg clk;
    
    // Outputs
    wire go;
    wire pause;
    wire prepare;
    
    // Instantiate the Device Under Test
    triggerManager DUT (
        .done(done),
        .ready(ready),
        .trigger(trigger),
        .clk(clk),
        .go(go),
        .pause(pause),
        .prepare(prepare)
    );
    
    initial begin
        // Initialize inputs
        done = 0;
        ready = 0;
        trigger = 0;
        clk = 0;
        
        #10 trigger = 1;
        #10 trigger = 0;
        #10 ready = 1;
        #10 ready = 0;
        #10 done = 1;
        #10 done = 0;
        
        #50 $finish;
    
    end
    
    always
        #5 clk = ~clk;

endmodule
