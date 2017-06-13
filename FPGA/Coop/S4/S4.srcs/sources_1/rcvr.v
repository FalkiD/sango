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

module rcvr #(parameter BAUD_DIV = 885) // BAUD_DIV = 102MHz / (115200 - 1)
   (// connections to uart.v
    input               rxd,             // RX serial input
    input               clk,             // 100MHz clock
    input               rst,
    output [7:0]	    do,              // RX data
    output              baudx,
    output              drdy            // data ready
   );

   reg  [11:0]     clk_div   = 11'b0;
   reg  [7:0]      rsr       = 8'b0;
   reg  [7:0]      dout;
   reg  [3:0]      bit_count = 4'd9;
   reg             baud      = 1'b0;
   reg             done      = 1'b0;
   reg             done2     = 1'b0;
   reg  [15:0]     rx_edge   = 16'hffff;
   
   reg  [7:0]      baudr     = 8'h00;

   assign drdy = done & ~done2;			// single clock pulse at stop bit
   assign do = dout;

   always @ (posedge clk)
   begin
     baudr <= {baudr[6:0], baud};
   end
   
   assign baudx = |baudr;
   
   always @(posedge clk) begin
      if (rst)
         rx_edge <= 16'hffff;
      else
         rx_edge <= {rx_edge[14:0], rxd};
   end  // end of always @(posedge clk).

   always @(posedge clk) begin
      if (rst) begin
         rsr <= 8'b0000_0000;
         dout <= 8'b0000_0000;
         clk_div <= 11'b0;
         bit_count <= 4'd9;
         done <= 1'b0;
         done2 <= 1'b0;
      end
      else begin
         done2 <= done;
         baud <= (clk_div == 11'b0);
         if (bit_count == 9 && rx_edge == 16'hff00) begin // detect start bit, reject noise
            clk_div <= BAUD_DIV / 2;
            bit_count <= 0;
            done <= 1'b0;
         end
         else begin
            if (clk_div == 11'b0)
               clk_div <= BAUD_DIV;
            else
               clk_div <= clk_div - 11'b000_0000_0001;
            // shift in RX data, LSB first
            if (baud) begin
               if (bit_count < 9) begin
                  bit_count <= bit_count + 1;
               end
               if (bit_count >= 1 && bit_count <= 8) begin
                  rsr[7:0] <= {rxd, rsr[7:1]};
               end
               else if (bit_count == 9) begin
                  dout <= rsr;
                  done <= 1;
               end
            end
         end
      end
   end  // end of always @(posedge clk).

endmodule
