//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/21/2016 02:18:49 PM
// Design Name: 
// Module Name: ptn_ram
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

`include "timescale.v"
`include "version.v"

//
// From Xilinx sample
// Write-First Mode (template 2)
//
module ptn_ram //#(parameter DEPTH=65536)
(
        input clk, 
        input we, 
        input en, 
        input [23:0] addr, 
        input [15:0] data_i, 
        output [15:0] data_o
        );

    reg [15:0] RAM [65535:0];
    reg [23:0] read_addr;

    always @(posedge clk) begin
        if (en) begin
            if (we)
                RAM[addr] <= data_i;
            read_addr <= addr;
        end
    end

    assign data_o = RAM[read_addr];

endmodule