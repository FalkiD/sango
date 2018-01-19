//------------------------------------------------------------------------------
// (C) Copyright 2016, Ampleon Inc.
//     All rights reserved.
//
// PROPRIETARY INFORMATION
//
// The information contained in this file is the property of Ampleon Inc.
// Except as specifically authorized in writing by Ampleon, the holder of this
// file:
// (1) shall keep all information contained herein confidential and shall protect
//     same in whole or in part from disclosure and dissemination to all third
//     parties and 
// (2) shall use same for operation and maintenance purposes only.
// -----------------------------------------------------------------------------
// File name:  snglClkFifoParmd.v
// Project:    s4x7
// Author:     JLCooper <aa1ww.coop@gmail.com> (RAW)
// Purpose:    Parameterized Single Clock FIFO independent of coregen.
// -----------------------------------------------------------------------------
// 0.00.1  2016-08-31 (JLC) Created,
//
//------------------------------------------------------------------------------

`include "timescale.v"        // Every source file needs this include

`define LOG2(x) \
   (x <= 2) ? 1 : \
   (x <= 4) ? 2 : \
   (x <= 8) ? 3 : \
   (x <= 16) ? 4 : \
   (x <= 32) ? 5 : \
   (x <= 64) ? 6 : \
   (x <= 128) ? 7 : \
   (x <= 256) ? 8 : \
   (x <= 512) ? 9 : \
   (x <= 1024) ? 10 : \
   (x <= 2048) ? 11 : \
   (x <= 4096) ? 12 : \
   (x <= 8192) ? 13 : \
   (x <= 16384) ? 14 : \
   (x <= 32768) ? 15 : \
   (x <= 65536) ? 16 : \
   -1

module snglClkFifoParmd #(
    parameter USE_BRAM = 1,
    parameter WIDTH    = 8,
    parameter DEPTH    = 16
  )
  
  (
    input                     CLK,
    input                     RST,
    input                     WEN,
    input       [WIDTH-1:0]   DI,
    output                    FULL,
    input                     REN,
    output reg  [WIDTH-1:0]   DO,
    output                    MT
  );

  localparam ADDRSIZ          = `LOG2(DEPTH);


  reg  [ADDRSIZ:0]            wrAddr = 0;
  reg  [ADDRSIZ:0]            rdAddr = 0;

  wire [ADDRSIZ-1:0]          wrAAddr = wrAddr[ADDRSIZ-1:0];
  wire [ADDRSIZ-1:0]          rdAAddr = rdAddr[ADDRSIZ-1:0];

  generate
    if (USE_BRAM == 1) begin
      // Xilinx XST-specific meta comment follows:
      (* ram_style = "block" *) reg  [WIDTH-1:0]  fifoRAM[DEPTH-1:0];
      always @(posedge CLK) begin
        if (RST) begin
          wrAddr                    <= 0;
          rdAddr                    <= 0;
          DO                        <= {WIDTH{1'b0}};
        end
        else begin
          if (WEN) begin
            fifoRAM[wrAAddr]        <= DI;
            wrAddr                  <= wrAddr + ({ {(ADDRSIZ-1){1'b0}}, 1'b1});
          end
          DO                        <= fifoRAM[rdAAddr];
          if (REN) begin
            rdAddr                  <= rdAddr + ({ {(ADDRSIZ-1){1'b0}}, 1'b1});
          end
        end
      end  // end of always @(posedge CLK)
    end  // end of generate if (BRAM == 1)
    else begin
      // Xilinx XST-specific meta comment follows:
      (* ram_style = "distributed" *) reg  [WIDTH-1:0]  fifoRAM[DEPTH-1:0];
      always @(posedge CLK) begin
        if (RST) begin
          wrAddr                    <= 0;
          rdAddr                    <= 0;
          DO                        <= {WIDTH{1'b0}};
        end
        else begin
          if (WEN) begin
            fifoRAM[wrAAddr]        <= DI;
            wrAddr                  <= wrAddr + ({ {(ADDRSIZ-1){1'b0}}, 1'b1});
          end
          DO                        <= fifoRAM[rdAAddr];
          if (REN) begin
            rdAddr                  <= rdAddr + ({ {(ADDRSIZ-1){1'b0}}, 1'b1});
          end
        end
      end  // end of always @ (posedge CLK)
    end  // end of generate if (BRAM == 1) else
  endgenerate


  assign MT       = (wrAAddr == rdAAddr) & (wrAddr[ADDRSIZ] == rdAddr[ADDRSIZ]);
  assign FULL     = (wrAAddr == rdAAddr) & (wrAddr[ADDRSIZ] != rdAddr[ADDRSIZ]);
   
endmodule  // end of module snglClkFifoParmd
