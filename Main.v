`timescale 1ns / 1ps

module Main(
    input clk_100MHz,
    input btnC,
    inout PS2Clk,
    inout PS2Data,
    output [7:0] JC
    );
    
    Tutorial_Level inst0 (clk_100MHz, btnC, PS2Clk, PS2Data, JC);
    
endmodule

