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
// Description: Each entry is 10 bytes.
// 3 MS bytes are patClk pattern clock tick. 100ns clock, pattern starts at 0
// 7 LS bytes are saved opcode. Leaves room for PULSE opcode. PULSE opcode is
// saved without its first byte (Channel)
// Opcodees will be left-justified in the 7 byte field.
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
module ptn_ram #(parameter DEPTH=65536)
(
        input clk, 
        input we, 
        input en, 
        input [15:0] addr, 
        input [95:0] data_i, 
        output [95:0] data_o
        );

    reg [95:0] RAM [DEPTH-1:0];
    reg [15:0] read_addr;

    always @(posedge clk) begin
        if (en) begin
            if (we)
                RAM[addr] <= data_i;
            read_addr <= addr;
        end
    end

    assign data_o = RAM[read_addr];

endmodule