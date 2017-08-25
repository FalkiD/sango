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

      // opcode processor writes into pattern RAM
      input  wire [PTN_BITS-1:0]  ptn_addr_i,         // Start of pattern address
      input  wire [WR_WIDTH-1:0]  ptn_data_i,         // Write pattern data word from opcode processor
      input  wire                 ptn_wen_i,          // Pattern RAM write enable

      // pattern processor(this instance) writes next pattern entry for opcode processor to run
      output wire [PTN_BITS-1:0]  ptn_index_o,        // address of pattern entry to run next
      output wire [RD_WIDTH-1:0]  ptn_data_o,         // Read 9 bytes opcode data from pattern RAM, 0=do nothing

      input  wire [PCMD_BITS-1:0] ptn_cmd_i,          // Command/mode, i.e. writing pattern, run pattern, stop, etc

      output reg  [7:0]           status_o            // pattern processor status
  );
    
  // Variables/registers:
  reg   [3:0]           ptn_state;

  // pattern RAM registers
  wire  [PTN_BITS-1:0]  ptn_tick;                   // tick is the index into pattern RAM
  wire  [RD_WIDTH-1:0]  ptn_data;                   // opcode and data payload into RAM
  reg   [PTN_BITS-1:0]  ptn_addr_rd;                // read address when running patterns
  reg   [5:0]           sys_counter;                // sys clock counter
  reg   [RD_WIDTH-1:0]  ptn_next_data;
  wire  [RD_WIDTH-1:0]  ptn_data_rd;
  reg   [PTN_BITS-1:0]  init_addr;                  // used during reset to initialize RAM

  localparam PTN_IDLE       = 4'd1;
  localparam PTN_LOAD       = 4'd2;
  localparam PTN_NEXT       = 4'd3;
  localparam PTN_RD_RAM     = 4'd4;
  localparam PTN_SPACER     = 4'd5;
  localparam PTN_WAIT_TICK  = 4'd6;
  localparam PTN_OPCODE_GO  = 4'd7;
  localparam PTN_STOP       = 4'd8;
  localparam PTN_CLEAR_RAM  = 4'd9;
 
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
        ptn_next_data <= 0;             // do nothing
        sys_counter <= 6'd0;
        ptn_addr_rd <= 0;               // read address when running patterns
        init_addr <= 0;
        ptn_state <= PTN_CLEAR_RAM;
//        ptn_state <= PTN_IDLE;
    end
    else begin
        if(ptn_state == PTN_CLEAR_RAM) begin
            if(init_addr < PTN_DEPTH-1) begin            
                init_addr <= init_addr + 1;
            end
            else begin
                init_addr <= 0;
                ptn_state <= PTN_IDLE;
            end
        end    
        else if(ptn_run_i) begin
            case(ptn_state)
            PTN_IDLE: begin
                //if(ptn_run_i) begin //ptn_cmd_i == `PTNCMD_RUN) begin
                    ptn_addr_rd <= ptn_addr_i;      // init read index, absolute RAM index
                    sys_counter <= 6'd0;
                    ptn_state <= PTN_RD_RAM;
                    status_o <= 8'h00;              // busy           
                //end           
            end
            PTN_RD_RAM: begin
                ptn_state <= PTN_NEXT;
            end
            PTN_NEXT: begin // next opcode
                ptn_next_data <= ptn_data_rd;
                sys_counter <= sys_counter + 6'd1;
                ptn_state <= PTN_OPCODE_GO;    
            end
            PTN_OPCODE_GO: begin
                sys_counter <= sys_counter + 6'd1;
                ptn_next_data <= 0;     // clear this so only executes once
                ptn_state <= PTN_WAIT_TICK;
            end
            PTN_WAIT_TICK: begin
                if(sys_counter >= `SYSCLK_PER_PTN_CLK) begin
                    sys_counter <= 6'd0;
                    if(ptn_addr_rd < PTN_DEPTH-1) begin
                        ptn_addr_rd <= ptn_addr_rd + 1;
                        ptn_state <= PTN_RD_RAM;
                    end
                    else begin
                        status_o <= `ERR_PATTERN_ADDR;
                        ptn_state <= PTN_STOP;
                    end
                end
                else
                    sys_counter <= sys_counter + 6'd1;
            end
            PTN_STOP: begin
                if(ptn_run_i == 1'b0)
                    ptn_state <= PTN_IDLE;  // Back to idle when caller stops running
            end
            default: begin
                status_o <= `ERR_PATTERN_ADDR;
                ptn_state <= PTN_STOP;
            end
            endcase
        end
        else begin
            ptn_state <= PTN_IDLE;
            if(status_o == 8'h00)
                status_o <= `SUCCESS;
        end
    end
  end

  // Concurrent assignments
//  assign ptn_tick = ptn_run_i ? ptn_addr_rd : (ptn_data_i[95:72] + ptn_addr_i); 
//  assign ptn_addr_wr = (ptn_state == PTN_CLEAR_RAM) ? init_addr : ptn_tick;
//  assign ptn_data = (ptn_state == PTN_CLEAR_RAM) ? 72'd0 : ptn_data_i[71:0]; 
//  assign ptn_data_o = ptn_run_i ? ptn_next_data : 0;    // next opcode to run or 0 to do nothing
//  assign ptn_index_o = ptn_tick;                        // unique address of pattern entry to run next
//  assign ptn_wen = (ptn_state == PTN_CLEAR_RAM) ? 1'b1 : ptn_wen_i;
  assign ptn_tick = ptn_run_i ? ptn_addr_rd : (ptn_data_i[95:72] + ptn_addr_i); 
  assign ptn_data = ptn_data_i[71:0]; 
  assign ptn_data_o = ptn_run_i ? ptn_next_data : 0;    // next opcode to run or 0 to do nothing
  assign ptn_index_o = ptn_tick;                        // unique address of pattern entry to run next
   
endmodule
