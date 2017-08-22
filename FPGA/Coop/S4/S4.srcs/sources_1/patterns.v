`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08/16/2017 12:03:53 PM
// Design Name: 
// Module Name: patterns
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
`include "opcodes.h"
`include "status.h"

module patterns #(parameter PTN_DEPTH = 65536,
                            PTN_BITS = 16,
                            PCMD_BITS = 4,
                            WR_WIDTH = 96,      // Write pattern includes 3 bytes patclk tick
                            RD_WIDTH = 72)      // Read pattern only needs opcode & 8 bytes data
  (
      input  wire                 sys_clk,
      input  wire                 sys_rst_n,
  
      input  wire                 ptn_en,
      
      input  wire                 ptn_run_i,          // Run a pattern
      input  wire [WR_WIDTH-1:0]  ptn_data_i,         // Write pattern data word from opcode processor
      output wire [RD_WIDTH-1:0]  ptn_data_o,         // Read 9 bytes opcode data from pattern RAM, 0=do nothing
      input  wire [PTN_BITS-1:0]  ptn_addr_i,         // Start of pattern address
      input  wire                 ptn_wen_i,          // Pattern RAM write enable
      input  wire [PCMD_BITS-1:0] ptn_cmd_i,          // Command/mode, i.e. writing pattern, run pattern, stop, etc

      output reg  [7:0]           status_o            // pattern processor status
  );
    
  // Variables/registers:
  reg   [3:0]           ptn_state;

  // pattern RAM registers
  reg   [RD_WIDTH-1:0]  ptn_next;
  wire  [PTN_BITS-1:0]  ptn_tick;                  // tick is the index of an opcode 
  wire  [RD_WIDTH-1:0]  ptn_data;                  // opcode and data payload into RAM
 
  // Pattern RAM
  ptn_ram #(
    .DEPTH(PTN_DEPTH),
    .DEPTH_BITS(PTN_BITS),
    .WIDTH(RD_WIDTH)
  )
  pattern_ram
  (
    .clk            (sys_clk), 
    .we             (ptn_wen_i), 
    .en             (ptn_en), 
    .addr_i         (ptn_tick), 
    .data_i         (ptn_data), 
    .data_o         (ptn_data_rd)
  );

  // Logic
  always @(posedge sys_clk) begin
    if(!sys_rst_n) begin
        status_o <= `SUCCESS;           // pattern processor status
        ptn_next <= 0;                  // do nothing
        ptn_state <= `OPCODE_NORMAL;
    end
    else begin
        case(ptn_state)
        `PTNCMD_RUN: begin
        
        end
        default: begin
                
        end
        endcase
    end
  end

  assign ptn_tick = ptn_data_i[95:72] + ptn_addr_i; 
  assign ptn_data = ptn_data_i[71:0]; 
  assign ptn_data_o = ptn_run_i ? ptn_next : 0;     // next opcode to run or 0 to do nothing
   
endmodule
