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
// File name:		reg_test.v
// Project:		Ctrl4 extended digital, timing generator image
// Purpose:		Verify registers w/LPC43xx EMC master behavorial model
// Author: 		Roger Williams <roger.williams@nxp.com> (RAW)
// -----------------------------------------------------------------------------
// 0.10.0  2013-09-30 (RAW) Initial entry
//------------------------------------------------------------------------------

`include "registers_def.v"
`include "timescale.v"
`include "version.v"

module reg_test();
   parameter AW = 8, WAITWEN = 0, WAITWR = 1, WAITOEN = 0, WAITRD = 5;
   // interconnect wires
   wire			clk;			// clock
   wire			clk2x;			// clock
   wire			rst;			// reset
   wire [AW-1:0] 	A;			// address bus
   wire			WEN;			// write enable
   wire			OEN;			// output enable
   wire			CSN;			// cycle select
   wire [15:0] 		D;			// data bus from EMC to DUT

   wire [15:0] 		dat_o;
   reg [15:0] 		result, i;
   integer 		read;

   localparam TG1 = 8'h80, TG2 = 8'ha0, TG3 = 8'hc0, TG4 = 8'he0;

   initial begin
      $dumpfile("reg_test.vcd");
      $dumpvars(0);

      clkrst.reset;
      wait(reg_test.xdig.DCM_clk.LOCKED);

      @ (posedge clk);
      emc.rd(`VERSION_AD, result);
      $write("Reading VERSION = %04x\n", result);
      @ (posedge clk);

      @ (posedge clk);
      emc.wr(`CONF_AD, 16'hfedc);
      $write("Writing %04x to CONF\n", 16'hfedc);

      @ (posedge clk);
      emc.rd(TG1 + `TG_TQ_STAT_AD, result);
      $write("Reading TG1 TQ_STAT = %04x\n", result);

      @ (posedge clk);
      emc.wr(TG1 + `TG_TCTRL_AD, 16'h0800);
      $write("Writing %04x to TG1 TCTRL\n", 16'h0800);

      @ (posedge clk);
      emc.rd(TG1 + `TG_MQUEUE_AD, result);
      $write("Reading TG1 MQUEUE = %04x\n", result);

      @ (posedge clk);
      emc.wr2(TG1 + `TG_TQUEUE_AD, 32'h12345678);
      $write("Writing %08x to TG1 TQUEUE\n", 32'h12345678);

      @ (posedge clk);
      emc.wr(`CTRL_AD, 16'h8705);
      $write("Writing %04x to CTRL\n", 16'h8705);

      @ (posedge clk);
      emc.rd(`CONF_AD, result);
      $write("Reading CONF = %04x\n", result);
      @ (posedge clk);
    
      $finish;
   end

   initial begin
      #10000 $write("ERROR: EMC testbench timed out\n");
      $stop(2);
   end

   // clock/reset generator
   clkrst clkrst(.clk(clk), .clk2x(clk2x), .rst(rst));

   // master EMC BFM
   emc_master #(.AW(AW), .WAITOEN(WAITOEN), .WAITRD(WAITRD), .WAITWEN(WAITWEN), .WAITWR(WAITWR))
   emc(.clk_i(clk2x), .rst_i(rst), .A(A), .D(D), .WEN(WEN), .CSN(CSN), .OEN(OEN));

   xdig xdig (.FPGA_CLK(clk), .A(A[7:1]), .D(D), .WEN(WEN), .OEN(OEN), .CSN(CSN), .RST(rst));

endmodule
