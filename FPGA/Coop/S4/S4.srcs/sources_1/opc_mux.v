`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: Ampleon USA 
// Engineer: Rick Rigby
// 
// Create Date: 07/21/2017 02:59:45 PM
// Design Name: S4
// Module Name: opc_mux
// Project Name: S4
// Target Devices: Artix-7
// Tool Versions: 
// Description: Mux opcode processor I/O between MMC fifo's 
//              and the pattern processor. MMC is the default.
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

`include "timescale.v"

module opc_mux #(parameter MMC_FILL_LEVEL_BITS = 16,
                 parameter RSP_FILL_LEVEL_BITS = 10)
(
    input wire      sys_clk,
    input wire      sys_rst_n,
    input wire      enable_i,
    
    input wire      select_i,   // 1'b0=>MMC, 1'b1=>pattern processor
    
    // opcode processor connections
    output reg  [7:0]           opc_fif_dat_o,          // output of mux, input to opcode processor
    input  wire                 opc_fif_ren_i,          // fifo read line, from opcode processor to MMC fifo
    output reg                  opc_fif_mt_o,           // MMC opcode fifo empty flag to opcode processor
    output reg  [MMC_FILL_LEVEL_BITS-1:0] opc_fif_cnt_o,// MMC fifo fill level to opcode processor
    input  wire                 opc_inpf_rst_i,         // opcode processor resets input fifo at first null opcode
 
    input  wire [7:0]           opc_rspf_dat_i,         // from opcode processor to MMC response fifo
    input  wire                 opc_rspf_wen_i,         // MMC response fifo write enable
    output reg                  opc_rspf_mt_o,          // MMC response fifo empty
    output reg                  opc_rspf_fl_o,          // MMC response fifo full
    output reg  [MMC_FILL_LEVEL_BITS-1:0] opc_rspf_cnt_o,// MMC response fifo count
    
    input  wire                 opc_rsp_rdy_i,          // response fifo is waiting
    input  wire [MMC_FILL_LEVEL_BITS-1:0] opc_rsp_len_i,// update response length when response is ready
    
    // mux'd connections
    // mux 0, default, is MMC fifo's
    input  wire [7:0]           mmc_fif_dat_i,          // mux 0 is MMC
    output reg                  mmc_fif_ren_o,          // 
    input  wire                 mmc_fif_mt_i,           // 
    input  wire [MMC_FILL_LEVEL_BITS-1:0] mmc_fif_cnt_i,// 
    output reg                  mmc_inpf_rst_o,         // opcode processor resets input fifo at first null opcode
 
    output reg  [7:0]           mmc_rspf_dat_o,         // 
    output reg                  mmc_rspf_wen_o,         // 
    input  wire                 mmc_rspf_mt_i,          // 
    input  wire                 mmc_rspf_fl_i,          // 
    input  wire [MMC_FILL_LEVEL_BITS-1:0] mmc_rspf_cnt_i, 
    
    output reg                  mmc_rsp_rdy_o,          // 
    output reg  [MMC_FILL_LEVEL_BITS-1:0] mmc_rsp_len_o,// update response length when response is ready

    // mux 1, is pattern processor fifo's
    input  wire [7:0]           ptn_fif_dat_i,          // mux 0 is MMC
    output reg                  ptn_fif_ren_o,          // 
    input  wire                 ptn_fif_mt_i,           // 
    input  wire [MMC_FILL_LEVEL_BITS-1:0] ptn_fif_cnt_i,// 
    output reg                  ptn_inpf_rst_o,         // opcode processor resets input fifo at first null opcode
 
    output reg  [7:0]           ptn_rspf_dat_o,         // 
    output reg                  ptn_rspf_wen_o,         // 
    input  wire                 ptn_rspf_mt_i,          // 
    input  wire                 ptn_rspf_fl_i,          // 
    input  wire [MMC_FILL_LEVEL_BITS-1:0] ptn_rspf_cnt_i, 

    output reg                  ptn_rsp_rdy_o,          // 
    output reg  [MMC_FILL_LEVEL_BITS-1:0] ptn_rsp_len_o // update response length when response is ready
);

  always @(*) begin
    if(enable_i && sys_rst_n == 1'b1) begin
      if(select_i == 1'b0) begin
        opc_fif_dat_o  = mmc_fif_dat_i;
        mmc_fif_ren_o  = opc_fif_ren_i;          // fifo read line, from opcode processor to MMC fifo
        opc_fif_mt_o   = mmc_fif_mt_i;           // MMC opcode fifo empty flag to opcode processor
        opc_fif_cnt_o  = mmc_fif_cnt_i;          // MMC fifo fill level to opcode processor
        mmc_inpf_rst_o = opc_inpf_rst_i;         // opcode processor resets input fifo at first null opcode
       
        mmc_rspf_dat_o = opc_rspf_dat_i;         // from opcode processor to MMC response fifo
        mmc_rspf_wen_o = opc_rspf_wen_i;         // MMC response fifo write enable
        opc_rspf_mt_o  = mmc_rspf_mt_i;          // MMC response fifo empty
        opc_rspf_fl_o  = mmc_rspf_fl_i;          // MMC response fifo full
        opc_rspf_cnt_o = mmc_rspf_cnt_i;

        mmc_rsp_rdy_o  = opc_rsp_rdy_i;          
        mmc_rsp_len_o  = opc_rsp_len_i;
      end
      else begin
        opc_fif_dat_o  = ptn_fif_dat_i;
        ptn_fif_ren_o  = opc_fif_ren_i;          // fifo read line, from opcode processor to pattern fifo
        opc_fif_mt_o   = ptn_fif_mt_i;           // pattern opcode fifo empty flag to opcode processor
        opc_fif_cnt_o  = ptn_fif_cnt_i;          // pattern fifo fill level to opcode processor
        ptn_inpf_rst_o = opc_inpf_rst_i;         // opcode processor can reset input fifo at first null opcode
     
        ptn_rspf_dat_o = opc_rspf_dat_i;         // from opcode processor to pattern response fifo
        ptn_rspf_wen_o = opc_rspf_wen_i;         // pattern response fifo write enable
        opc_rspf_mt_o  = ptn_rspf_mt_i;          // pattern response fifo empty
        opc_rspf_fl_o  = ptn_rspf_fl_i;          // pattern response fifo full
        opc_rspf_cnt_o = ptn_rspf_cnt_i;

        ptn_rsp_rdy_o  = opc_rsp_rdy_i;          
        ptn_rsp_len_o  = opc_rsp_len_i;
      end
    end  
  end
endmodule
