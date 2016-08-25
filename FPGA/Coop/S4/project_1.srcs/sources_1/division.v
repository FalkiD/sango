`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 06/21/2016 02:32:50 PM
// Design Name: 
// Module Name: division
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: http://verilogcodes.blogspot.com/2015/11/synthesisable-verilog-code-for-division.html
// Verilog parameterized division module
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

// Can't find the right damn syntax...
module division ( enable, A, B, result, done);
// none of these declarations work right, WTF???
//    input enable,
//    input reg [31:0] A, 
//    input reg [31:0] B, 
//    output reg [31:0] result, 
//    output reg done );
//module division #(parameter WIDTH = 32)(
//    input enable, 
//    reg input [WIDTH-1:0] A, 
//    reg input [WIDTH-1:0] B, 
//    reg output [WIDTH-1:0] Result, 
//    reg output done );

    // So we're left with this junk:
    parameter WIDTH = 32;
    // input and output ports.
    input enable;
    input [WIDTH-1:0] A;
    input [WIDTH-1:0] B;
    output [WIDTH-1:0] result;
    output done;
    // internal variables
    wire enable;    
    reg [WIDTH-1:0] result = 0;
    reg [WIDTH-1:0] a1,b1;
    reg [WIDTH:0] p1;
    reg done;   
    integer i;

    always@ (*)
    begin
        if(enable) begin
            // initialize the variables.
            done = 0;
            a1 = A;
            b1 = B;
            p1 = 0;
            for(i=0;i < WIDTH;i=i+1)    begin //start the for loop
                p1 = {p1[WIDTH-2:0],a1[WIDTH-1]};
                a1[WIDTH-1:1] = a1[WIDTH-2:0];
                p1 = p1-b1;
                if(p1[WIDTH-1] == 1)    begin
                    a1[0] = 0;
                    p1 = p1 + b1;   end
                else
                    a1[0] = 1;
            end
            result = a1;   
            done = 1;
        end
    end 

endmodule
