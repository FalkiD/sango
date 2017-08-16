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
module ptn_ram #(parameter DEPTH=65536,
		 parameter DEPTH_BITS=16,
		 parameter WIDTH=16)
(
  input  clk, 
  input  we, 
  input  en, 
  input  [DEPTH_BITS-1:0] addr_i, 
  input  [WIDTH-1:0] data_i, 
  output [WIDTH-1:0] data_o
);

  // Xilinx XST-specific meta comment follows:
  (* ram_style = "distributed" *) reg  [WIDTH-1:0]  RAM[DEPTH-1:0];
  reg [DEPTH_BITS-1:0] read_addr;

  always @(posedge clk) begin
    if (en) begin
      if (we)
        RAM[addr_i] <= data_i;
        read_addr <= addr_i;
      end
  end

  assign data_o = RAM[read_addr];

endmodule
