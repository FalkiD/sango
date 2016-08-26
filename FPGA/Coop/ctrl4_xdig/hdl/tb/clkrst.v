//------------------------------------------------------------------------------
// (C) Copyright 2013, NXP Semiconductors
//     All rights reserved.
//
// PROPRIETARY INFORMATION
//
// The information contained in this file is the property of NXP Semiconductors.
// Except as specifically authorized in writing by NXP, the holder of this
// file: (1) shall keep all information contained herein confidential and
// shall protect same in whole or in part from disclosure and dissemination to
// all third parties and (2) shall use same for operation and maintenance
// purposes only.
// -----------------------------------------------------------------------------
// File name:		clkrst.v
// Project:		Ctrl4 extended digital, timing generator image
// Purpose:		Testbench clock and reset generator
// Author: 		Roger Williams <roger.williams@nxp.com> (RAW)
// -----------------------------------------------------------------------------
// 0.10.0  2013-09-30 (RAW) Initial entry
//------------------------------------------------------------------------------

`include "timescale.v"

module clkrst (clk, clk2x, rst);

   // I/O ports
   output reg	clk = 0;	// clock
   output reg	clk2x = 0;	// clock
   output reg	rst = 0;	// reset

   task reset;
      begin
	 rst = 1'b0;
	 @ (negedge clk) rst <= 1'b1;
	 @ (negedge clk);
	 @ (negedge clk);
	 @ (negedge clk);
	 @ (negedge clk) rst <= 1'b0;
      end
   endtask // reset
   
   // 100 MHz clock
   always begin
      #5 clk <= 1'b0;
      #5 clk <= 1'b1;
   end

   // 200 MHz clock
   always begin
      #2 clk2x <= 1'b0;
      #3 clk2x <= 1'b1;
   end

endmodule
