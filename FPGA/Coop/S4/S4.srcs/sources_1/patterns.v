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

module patterns #( parameter FIFO_DEPTH = 65536, 
                   FIFO_BITS = 16, 
                   PTN_DEPTH = 64,
                   PTN_BITS = 6,
                   PCMD_BITS = 4,
                   WIDTH = 96)
  (
      input  wire         sys_clk,
      input  wire         sys_rst_n,
  
      input  wire         ptn_en,
      
      input  wire [WIDTH-1:0]     ptn_data_i,         // Write pattern data word from opcode processor
      input  wire [PTN_BITS-1:0]  ptn_addr_i,         // Write to or run from this pattern address
      input  wire [PCMD_BITS-1:0] ptn_cmd_i,          // Command/mode, i.e. writing pattern, run pattern, stop, etc

      // Read from pattern processor fifo connections
      output wire [7:0]           ptn_fif_dat_o,      // pattern fifo output to opcode processor
      input  wire                 ptn_fif_ren_i,      // pattern fifo read enable
      output wire                 ptn_fif_mt_o,       // pattern opcode fifo empty
      output wire [FIFO_BITS-1:0] ptn_rd_cnt_o,       // pattern opcode fifo fill level 
      input  wire                 ptn_rd_reset_i,     // Synchronous pattern opcode fifo reset
      // Write to pattern processor response fifo connections
      input  wire [7:0]           ptn_rspf_dat_i,     // Pattern response fifo
      input  wire                 ptn_rspf_we_i,      // response fifo write line             
      output wire                 ptn_rspf_mt_o,      // response fifo empty
      output wire                 ptn_rspf_fl_o,      // response fifo full
      input  wire                 ptn_rspf_reset_i,   // Synchronous pattern response fifo reset
      output wire [FIFO_BITS-1:0] ptn_rspf_cnt_o,     // Pattern response fifo fill level

      output wire [7:0]           status_o            // pattern processor status
  );
    
  // Variables/registers:

  // pattern fifo connections
  wire  [7:0]     ptn_fif_dat_i;
  wire            ptn_fif_wen;
  wire  [7:0]     ptn_fif_dat_o;
  wire            ptn_fif_ren;
  wire            ptn_fif_mt;
  wire  [FIFO_BITS-1:0]  ptn_fif_cnt;
  wire            ptn_inpf_rst;   // opcode processor can reset input fifo on first null opcode
  
  wire  [7:0]     ptn_rspf_dat_i;
  wire            ptn_rspf_wen;
  wire  [7:0]     ptn_rspf_dat_o;
  wire            ptn_rspf_ren;
  wire            ptn_rspf_mt;
  wire            ptn_rspf_fl;
  wire  [FIFO_BITS-1:0]  ptn_rspf_cnt;
  wire            ptn_rsp_rdy;
  wire  [FIFO_BITS-1:0]  ptn_rsp_len;

  // pattern RAM registers
  wire                  ptn_ram_we; 
  wire  [PTN_BITS-1:0]  ptn_addr; 
  wire  [WIDTH-1:0]     ptn_data_o;

  
  // Pattern processor opcode fifo's.
  // Pattern processor will write opcodes at specific times.
  // Each location in pattern RAM represents a 100ns tick
  // Instantiate VHDL fifo that mmc_tester instance
  // is using to store opcodes (opcode processor input fifo)
  swiss_army_fifo #(
    .USE_BRAM(1),           // BRAM=1 requires 1 extra clock before read data is ready
    .WIDTH(8),
    .DEPTH(FIFO_DEPTH),
    .FILL_LEVEL_BITS(FIFO_BITS),
    .PF_FULL_POINT(FIFO_BITS-1),
    .PF_FLAG_POINT(FIFO_BITS>>1),
    .PF_EMPTY_POINT(1)
  ) ptn_opcodes(
      .sys_rst_n(sys_rst_n),
      .sys_clk(sys_clk),
      .sys_clk_en(ptn_en),

      .reset_i(1'b0),

      // pattern fifo write entries
      .fifo_wr_i(ptn_fif_wen),
      .fifo_din(ptn_fif_dat_i),

      // opcode fifo mux reads entries
      .fifo_rd_i(ptn_fif_ren),
      .fifo_dout(ptn_fif_dat_o),
      .fifo_fill_level(ptn_fif_cnt),
      .fifo_full(),
      .fifo_empty(ptn_fif_mt),
      .fifo_pf_full(),
      .fifo_pf_flag(),
      .fifo_pf_empty()
  );

  // Instantiate VHDL fifo that opcode processor instance
  // is using to store responses (opcode processor output fifo)
  // when running a pattern
  swiss_army_fifo #(
    .USE_BRAM(1),               // BRAM=1 requires 1 extra clock before read data is ready
    .WIDTH(8),
    .DEPTH(FIFO_DEPTH),
    .FILL_LEVEL_BITS(FIFO_BITS),
    .PF_FULL_POINT(FIFO_BITS-1),
    .PF_FLAG_POINT(FIFO_BITS>>1),
    .PF_EMPTY_POINT(1)
  ) ptn_response(
      .sys_rst_n(sys_rst_n),
      .sys_clk(sys_clk),
      .sys_clk_en(ptn_en),

      .reset_i(1'b0),

      .fifo_wr_i(ptn_rspf_wen),                 // response fifo write enable
      .fifo_din(ptn_rspf_dat_i),                // to fifo, response bytes(status, measurements, echo, etc)

      .fifo_rd_i(ptn_rspf_ren),                 // response fifo read enable
      .fifo_dout(ptn_rspf_dat_o),               // response fifo output data, used to generate response block

      .fifo_fill_level(ptn_rspf_cnt),           // response fifo count
      .fifo_full(ptn_rspf_fl),                  // response fifo full  flag
      .fifo_empty(ptn_rspf_mt),                 // response fifo empty flag
      .fifo_pf_full(),
      .fifo_pf_flag(),
      .fifo_pf_empty()
  );

  // Pattern RAM
  ptn_ram #(
    .DEPTH(PTN_DEPTH),
    .DEPTH_BITS(PTN_BITS),
    .WIDTH(WIDTH)
  )
  pattern_ram
  (
    .clk            (sys_clk), 
    .we             (ptn_ram_we), 
    .en             (ptn_en), 
    .addr_i         (ptn_addr), 
    .data_i         (ptn_data_i), 
    .data_o         (ptn_data_o)
  );




  assign ptn_addr = ptn_addr_i;     // set by caller to write, set internally when running pattern
    
    
    
endmodule
