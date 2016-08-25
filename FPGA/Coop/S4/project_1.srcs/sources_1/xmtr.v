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
// File name:  xmtr.v
// Project:    s4x7
// Author:     Roger Williams <roger.williams@ampleon.com> (RAW)
// Purpose:    Support s uart diag/debug access to s4x7 FPGA internals.
// -----------------------------------------------------------------------------
// 0.00.0  2016-08-04 (JLC) Modified for current project.
//
//------------------------------------------------------------------------------
`include "timescale.v"
`include "version.v"

module xmtr #(parameter BAUD_DIV = 867) // BAUD_DIV = 100MHz / 57600 - 1
   (
    output reg           tbre = 1'b1,    // transmit buffer empty
    output reg           txd  = 1'b1,    // serial TX out
    input      [7:0]     din,            // TX data in
    input                rst,
    input                clk,            // 100MHz clock
    input                tx_stb          // single-clock TX strobe
   );

   reg  [7:0]       tbr         = 8'b0;
   reg  [3:0]       bit_count   = 4'd0;
   reg  [12:0] 		clk_div     = 13'h1fff;
   reg              baud        = 1'b0;

   always @(posedge clk)
      if (rst) begin
         tbre <= 1'b1;
         tbr <= 8'b0;
         clk_div <= 13'h1fff;
         baud <= 0;
         bit_count <= 0;
         end
      else begin
         baud <= (clk_div == 0);
         if (tx_stb) begin
            tbre <= 1'b0;
            tbr <= din;
            clk_div <= 0;
            bit_count <= 0;
         end
         else begin
            // generate synchronised baud-rate clock enable
            if (clk_div == 0)
               clk_div <= BAUD_DIV;
            else
               clk_div <= clk_div - 1;
         // shift out TX data bits, LSB first
         if (baud) begin
            if (bit_count < 11)
               bit_count <= bit_count + 1;
            if (bit_count == 0)
               txd <= 0;       // start bit (space)
            else if (bit_count >= 1 && bit_count <= 8) begin
               txd <= tbr[0];  // 8 data bits
               tbr[7:0] <= {1'b0, tbr[7:1]};
            end
            else if (bit_count == 9)
               txd <= 1;       // stop bit (mark)
            else if (bit_count == 10)
               txd <= 1;       // inter-character interval (mark)
            else if (bit_count == 11)
               tbre <= 1'b1;
         end
      end
   end

endmodule
