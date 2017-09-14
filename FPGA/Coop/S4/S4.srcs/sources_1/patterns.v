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
// 1) on reset, clear the ram using PTN_INIT_RAM
// 2) when loading, opcode processor writes directly into RAM,
//    no state machine action here
// 3) to run, every 10 sys clocks the next pattern data and
//    index(address) are presented to the opcode processor to
//    be run. 
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
      output reg  [RD_WIDTH-1:0]  opcptn_data_o,      // Write next pattern entry to fifo for opcode processor(from pattern RAM)
      output reg                  opcptn_fif_wen_o,   // fifo write enable for next pattern entry
      input  wire                 opcptn_fif_fl_i,    // opcode processor pattern fifo full
      
      input  wire [PCMD_BITS-1:0] ptn_cmd_i,          // Command/mode, i.e. writing pattern, run pattern, stop, etc

      output reg  [7:0]           status_o            // pattern processor status
  );
    
  // Variables/registers:
  reg   [3:0]           init_state;
  reg   [3:0]           ptn_state;

  // pattern RAM registers
  wire  [RD_WIDTH-1:0]  ptn_data;                   // opcode and data payload into RAM
  reg   [PTN_BITS-1:0]  ptn_addr;                   // 
  reg   [5:0]           sys_counter;                // sys clock counter
  wire  [RD_WIDTH-1:0]  ptn_data_rd;
  reg                   ptn_wen;                    // write enable line

  localparam PTN_IDLE       = 4'd1;
  localparam PTN_LOAD       = 4'd2;
  localparam PTN_NEXT       = 4'd3;
  localparam PTN_RD_RAM     = 4'd4;
  localparam PTN_SPACER     = 4'd5;
  localparam PTN_WAIT_TICK  = 4'd6;
  localparam PTN_OPCODE_GO  = 4'd7;
  localparam PTN_INIT_RAM   = 4'd8; // clear RAM on reset
  localparam PTN_STOP       = 4'd9;
  
  localparam INIT_IDLE      = 4'd1;
  localparam INIT1          = 4'd2;
  localparam INIT2          = 4'd3;
  localparam INIT3          = 4'd4;
  localparam INIT4          = 4'd5;
 
  // Pattern RAM
  ptn_ram #(
    .DEPTH(PTN_DEPTH),
    .DEPTH_BITS(PTN_BITS),
    .WIDTH(RD_WIDTH)
  )
  pattern_ram
  (
    .clk            (sys_clk), 
    .we             (ptn_wen), 
    .en             (ptn_en), 
    .addr_i         (ptn_addr), 
    .data_i         (ptn_data), 
    .data_o         (ptn_data_rd)
  );

  // Logic
  always @(posedge sys_clk) begin
    if(!sys_rst_n) begin
        status_o <= `SUCCESS;           // pattern processor status
        sys_counter <= 6'd0;
        ptn_addr <= 0;
        ptn_state <= PTN_INIT_RAM;
        ptn_wen <= 1'b0;
        opcptn_fif_wen_o <= 1'b0;
        init_state <= INIT_IDLE;
    end
    else begin
        if(ptn_state == PTN_INIT_RAM) begin
            case(init_state)
            INIT_IDLE: begin
                ptn_wen <= 1'b1;
                ptn_addr <= 0;
                init_state <= INIT1;         
            end
            INIT1: begin
                // Data is written to RAM at this clock, read address is valid at next clock
                init_state <= INIT2;
            end
            INIT2: begin
                // Read is valid here
//                if(ptn_data_rd != {59'd0, ptn_addr}) begin
//                    status_o <= `ERR_WR_PTN_RAM;
//                    ptn_state <= PTN_IDLE;
//                end
                if(ptn_addr < PTN_DEPTH - 1) begin
                    ptn_addr = ptn_addr + 1;
                    init_state <= INIT1;
                end
                else begin
                    ptn_wen <= 1'b0;
                    ptn_addr <= 0;
                    init_state <= INIT_IDLE;
                    ptn_state <= PTN_IDLE;         
                end
            end
            endcase
        end
        else if(ptn_run_i) begin
            ptn_wen <= 1'b0;
            case(ptn_state)
            PTN_IDLE: begin
                ptn_addr <= ptn_addr_i;      // init read index, absolute RAM index
                sys_counter <= 6'd0;
                status_o <= 8'h00;              // busy           
                ptn_state <= PTN_SPACER;
            end
            PTN_SPACER: begin
                ptn_state <= PTN_RD_RAM;            
            end            
            PTN_RD_RAM: begin
                // reads are valid here
                if(ptn_data_rd[70:64] != 7'd0) begin
                    opcptn_data_o <= ptn_data_rd;
                    opcptn_fif_wen_o <= 1'b1;
                end
                ptn_state <= PTN_NEXT;
            end
            PTN_NEXT: begin
                opcptn_fif_wen_o <= 1'b0;
                if(ptn_addr < PTN_DEPTH - 1) begin
                    ptn_addr = ptn_addr + 1;
                    ptn_state <= PTN_SPACER;
                end
                else begin
                    ptn_addr <= 0;
                    ptn_state <= PTN_STOP;         
                end                       
            end
            PTN_STOP: begin
                // Just do nothing
            end
            endcase
        
//            // don't do anything unless SUCCESS or BUSY
//            if(ptn_addr_rd < PTN_DEPTH-1 && status_o <= `SUCCESS) begin
//                case(ptn_state)
//                PTN_IDLE: begin
//                    ptn_addr_rd <= ptn_addr_i;      // init read index, absolute RAM index
//                    sys_counter <= 6'd0;
//                    ptn_state <= PTN_RD_RAM;
//                    status_o <= 8'h00;              // busy           
//                end
//                PTN_RD_RAM: begin
//                    ptn_state <= PTN_NEXT;
////    // debugging, fill fifo w/address
////      if(!opcptn_fif_fl_i) begin
////          opcptn_data_o <= {8'd2, 56'd0, 8'd222};
////          opcptn_fif_wen_o <= 1'b1;
////          ptn_state <= PTN_NEXT;
////      end
//                end
//                PTN_NEXT: begin // next opcode
////      opcptn_fif_wen_o <= 1'b0;
////      ptn_state <= PTN_IDLE;      

//                    if(dbg_last_idx != ptn_tick &&
//                       ptn_data_rd != 72'h00_0000_0000_0000_0000) begin
//                        nonzero_entries_o <= nonzero_entries_o + 13'd1;
//                        dbg_last_idx <= ptn_tick;
//                    end

//                    if(!opcptn_fif_fl_i) begin
//                        opcptn_data_o <= ptn_data_rd;
//                        opcptn_fif_wen_o <= 1'b1;
//                    end
//                    sys_counter <= sys_counter + 6'd1;
//                    ptn_state <= PTN_OPCODE_GO;

////                    if(opcptn_fif_fl_i) begin
////                        status_o <= `ERR_PTN_FIFO_FULL;
////                        ptn_state <= PTN_IDLE;
////                    end
////                    else begin //if(ptn_data_rd != 72'h00_0000_0000_0000_0000) begin
////                        opcptn_data_o <= ptn_data_rd;
////                        opcptn_fif_wen_o <= 1'b1;
////                        sys_counter <= sys_counter + 6'd1;
////                        ptn_state <= PTN_OPCODE_GO;
////                    end
////                    else
////                        ptn_state <= PTN_OPCODE_GO;  // don't do anything
//                end
//                PTN_OPCODE_GO: begin
//                    opcptn_fif_wen_o <= 1'b0;
//                    sys_counter <= sys_counter + 6'd1;
//                    ptn_state <= PTN_WAIT_TICK;
//                end
//                PTN_WAIT_TICK: begin
//                    if(sys_counter >= `SYSCLK_PER_PTN_CLK) begin
//                        sys_counter <= 6'd0;
//                        if(ptn_addr_rd < PTN_DEPTH-1) begin
//                            ptn_addr_rd <= ptn_addr_rd + 1;
//                            ptn_state <= PTN_RD_RAM;
//                        end
//                        else begin
//                            status_o <= `ERR_PATTERN_ADDR;
//                            ptn_state <= PTN_IDLE;
//                        end
//                    end
//                    else
//                        sys_counter <= sys_counter + 6'd1;
//                end
//                default: begin
//                    status_o <= `ERR_PATTERN_ADDR;
//                    ptn_state <= PTN_IDLE;
//                end
//                endcase
//            end
//            else begin
//                status_o <= `ERR_PATTERN_ADDR;
//                ptn_state <= PTN_IDLE;
//            end
//        end
//        else begin
//            ptn_state <= PTN_IDLE;
//            if(status_o == 8'h00)
//                status_o <= `SUCCESS;
        end
        else begin
            // not initializing RAM or running a pattern, use opcode processor inputs
            ptn_wen <= ptn_wen_i;
            ptn_addr <= ptn_data_i[95:72] + ptn_addr_i;
        end
    end
  end

  assign ptn_data     = ptn_state == PTN_INIT_RAM ? 72'd0 : ptn_data_i[71:0]; 
  assign ptn_index_o  = ptn_addr;    // address of pattern entry in use for status/debug
   
endmodule
