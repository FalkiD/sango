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
// Description: Each saved entry is 9 bytes.
// Index into pattern gives 100ns tick
// Each entry is 8 bytes opcode data plus the opcode
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
  (* ram_style = "block" *) reg  [WIDTH-1:0]  RAM[DEPTH-1:0];
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
