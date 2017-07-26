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
// File name:  rvcr.v
// Project:    s4x7
// Author:     Roger Williams <roger.williams@ampleon.com> (RAW)
// Purpose:    Support s uart diag/debug access to s4x7 FPGA internals.
// -----------------------------------------------------------------------------
// 0.00.0  2016-08-04 (JLC) Modified for current project.
//
//------------------------------------------------------------------------------

module rcvr #(parameter BAUD_DIV = 867) // ((BAUD_DIV = 100MHz) / (BAUD = 115200)) - 1
   (// connections to uart.v
    input               rxd,             // RX serial input
    input               clk,             // 100MHz clock
    input               rst,
    input               rx_enbl,
    output [7:0]	    dorx,            // RX data out
    output reg          drdy,            // data ready
    output              rxdbg1,
    output              rxdbg0
   );

   reg  [11:0]     clk_div   = 11'b0;
   reg  [7:0]      rsr       = 8'b0;
   reg  [7:0]      dout;
   reg  [3:0]      bit_count = 4'd9;
   reg             baud      = 1'b0;
   reg             rx_actv   = 1'b0;
   reg  [15:0]     rx_edge   = 16'hffff;
   reg             rx_enblsr = 1'b0;
   reg  [7:0]      baudr     = 8'h00;

   always @(posedge clk or posedge rst) begin
      if (rst)
      begin
         rx_edge       <= 16'hffff;
         rx_enblsr     <= 1'b0;
      end
      else
      begin
         rx_edge       <= {rx_edge[14:0], rxd};
         rx_enblsr     <= rx_enblsr | rx_enbl;
      end
   end  // end of always @(posedge clk).

   always @(posedge clk or posedge rst) begin
      if (rst) begin
         rsr <= 8'b0000_0000;
         dout <= 8'b0000_0000;
         clk_div <= 11'b0;
         bit_count <= 4'd9;
         rx_actv <= 1'b0;
         drdy <= 0;
         baud <= 1'b0;
      end
      else begin
         baud <= (clk_div == 11'b0);
         drdy <= 1'b0;
         if (bit_count == 9 && rx_edge == 16'hff00) begin // detect start bit, reject noise
            rx_actv <= 1'b1;
            clk_div <= BAUD_DIV / 2;
            bit_count <= 0;
         end
         else begin
            if (clk_div == 11'b0)
               clk_div <= BAUD_DIV;
            else
               clk_div <= clk_div - 11'b000_0000_0001;
               
            // at baud, shift in RX data, LSB first
            if (baud) begin
               if (bit_count < 9) begin
                  bit_count <= bit_count + 1;
               end
               if (bit_count >= 1 && bit_count <= 8) begin
                  rsr[7:0] <= {rxd, rsr[7:1]};
               end
               else if (bit_count == 9) begin
                  dout <= rsr;
                  drdy <= rx_actv;
                  rx_actv <= 1'b0;
               end
            end
         end
      end
   end  // end of always @(posedge clk).

   assign dorx     = dout;
   assign rxdbg0   = rx_actv;
   assign rxdbg1   = drdy;

endmodule
