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
// File name:		emc_master.v
// Project:		Ctrl4 extended digital, timing generator image
// Purpose:		LPC43xx EMC master behavorial model for testbench
// Author: 		Roger Williams <roger.williams@nxp.com> (RAW)
// -----------------------------------------------------------------------------
// Supported cycles:	Master Read/Write
// Data port:		8, 16, 32-bit; 8-bit granularity
// Data ordering:	little endian
// Parameters:		AW = width of address bus (default 8)
// -----------------------------------------------------------------------------
// 0.10.0  2013-09-30 (RAW) Initial entry
//------------------------------------------------------------------------------

`include "timescale.v"

module emc_master (clk_i, rst_i, A, D, BLSN, CSN, WEN, OEN);
   parameter AW = 8, WAITOEN = 0, WAITRD = 0, WAITWEN = 0, WAITWR = 0;
   input wire		clk_i;	// internal 200MHz clock
   input wire		rst_i;	// internal reset
   output reg [AW-1:0] 	A = {AW{1'bx}};
   inout wire [15:0] 	D;
   output reg [3:0] 	BLSN = 4'b1111;
   output reg		CSN = 1'b1;
   output reg		WEN = 1'b1;
   output reg		OEN = 1'b1;
   
   reg [15:0] 		dat_o = 0;
   reg [15:0] 		data_rd = 0;
   reg [15:0] 		data_rd2 = 0;
   reg [3:0] 		waito1, waito2, waitw1, waitw2;
   reg 			go = 0;
   reg 			stop = 0;
   integer 		address, iswrite;

   assign D = (~CSN & iswrite) ? dat_o : {16{1'bz}};

   // read single
   task rd (input [AW-1:0] adr, output [15:0] result);
      begin
	 iswrite = 0;
	 waito1 <= WAITOEN;
	 waito2 <= WAITRD;
	 @ (posedge clk_i);
	 A = adr[AW-1:0];
	 CSN = 0;
	 while (waito1 != 0)
	   @ (posedge clk_i) waito1 = waito1 - 1;
	 OEN = 0;
	 while (waito2 != 0)
	   @ (posedge clk_i) waito2 = waito2 - 1;
	 data_rd <= D;
	 @ (posedge clk_i);
	 @ (posedge clk_i);
	 @ (posedge clk_i);
	 OEN = 1;
	 CSN = 1;
	 result = data_rd;
      end
   endtask
   
   // write single
   task wr (input [AW-1:0] adr, input [15:0] dat);
      begin
	 iswrite = 1;
	 waitw1 <= WAITWEN;
	 waitw2 <= WAITWR;
	 @ (posedge clk_i);
	 A = adr[AW-1:0];
	 dat_o = dat[15:0];
	 CSN = 0;
	 @ (posedge clk_i);
	 while (waitw1 != 0)
	   @ (posedge clk_i) waitw1 = waitw1 - 1;
	 WEN = 0;
	 @ (posedge clk_i);
	 while (waitw2 != 0)
	   @ (posedge clk_i) waitw2 = waitw2 - 1;
	 WEN = 1;
	 @ (posedge clk_i);
	 CSN = 1;
      end
   endtask // wr

   // write double
   task wr2 (input [AW-1:0] adr, input [31:0] dat);
      begin
	 iswrite = 1;
	 waitw1 <= WAITWEN;
	 waitw2 <= WAITWR;
	 @ (posedge clk_i);
	 A = adr[AW-1:0];
	 dat_o = dat[15:0];
	 CSN = 0;
	 @ (posedge clk_i);
	 while (waitw1 != 0)
	   @ (posedge clk_i) waitw1 = waitw1 - 1;
	 WEN = 0;
	 @ (posedge clk_i);
	 while (waitw2 != 0)
	   @ (posedge clk_i) waitw2 = waitw2 - 1;
	 WEN = 1;
	 A = adr[AW-1:0] + 2;
	 dat_o = dat[31:16];
	 waitw1 <= WAITWEN;
	 waitw2 <= WAITWR;
	 @ (posedge clk_i);
	 while (waitw1 != 0)
	   @ (posedge clk_i) waitw1 = waitw1 - 1;
	 WEN = 0;
	 @ (posedge clk_i);
	 while (waitw2 != 0)
	   @ (posedge clk_i) waitw2 = waitw2 - 1;
	 WEN = 1;
	 @ (posedge clk_i);
	 CSN = 1;
      end
   endtask // wr

endmodule
