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
// File name:		emc_test.v
// Project:		Ctrl4 extended digital, timing generator image
// Purpose:		Verify LPC43xx EMC master behavorial model
// Author: 		Roger Williams <roger.williams@nxp.com> (RAW)
// -----------------------------------------------------------------------------
// 0.10.0  2013-09-30 (RAW) Initial entry
//------------------------------------------------------------------------------

`include "timescale.v"

module emc_test();
   parameter AW = 8, DW = 16, WAITOEN = 0, WAITRD = 0, WAITWEN = 0, WAITWR = 0;
   // interconnect wires
   wire			clk;			// clock
   wire			rst;			// reset
   wire [AW-1:0] 	A;			// address bus
   wire [3:0] 		BLSN;			// byte lane selects
   wire			WEN;			// write enable
   wire			OEN;			// output enable
   wire			CSN;			// cycle select
   wire [DW-1:0] 	D;			// data bus from EMC to DUT

   reg [DW-1:0] 	dat_r;
   reg [31:0] 		result, i;
   integer 		read;

   assign D = read ? dat_r : {DW{1'bz}};

   initial begin
      $dumpfile("emc_test.vcd");
      $dumpvars(0);

      clkrst.reset;
      read = 0;
      @ (posedge clk);
      $write("Testing write...");
      emc.wr(8'ha5, 16'habcd);
      @ (posedge clk);

      $write("read...");
      read = 1;
      dat_r = 16'hba98;
      emc.rd(8'h07, result);
      read = 0;
      @ (posedge clk);
      @ (posedge clk);
      @ (posedge clk);
      $write("done\n");
      
      $finish;
   end

   initial begin
      #1000 $write("ERROR: EMC testbench timed out\n");
      $stop(2);
   end

   // clock/reset generator
   clkrst clkrst(.clk(clk), .rst(rst));

   // master EMC BFM
   emc_master #(.AW(AW),.DW(DW), .WAITOEN(WAITOEN), .WAITRD(WAITRD), .WAITWEN(WAITWEN), .WAITWR(WAITWR))
   emc(.clk_i(clk), .rst_i(rst), .A(A), .D(D), .BLSN(BLSN), .WEN(WEN), .CSN(CSN), .OEN(OEN));
   
endmodule
