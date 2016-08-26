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
// File name:		tg_test.v
// Project:		Ctrl4 extended digital, timing generator image
// Purpose:		Verify burst generation w/LPC43xx EMC master
// Author: 		Roger Williams <roger.williams@nxp.com> (RAW)
// -----------------------------------------------------------------------------
// 0.10.0  2013-09-30 (RAW) Initial entry
//------------------------------------------------------------------------------

`include "registers_def.v"
`include "timescale.v"
`include "version.v"

module tg_test();
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

   wire 		adc_sck, adc_conv;
   reg 			adcf_sdo = 0;
   reg 			adcr_sdo = 0;
   reg [13:0] 		adcf;
   reg [13:0] 		adcr;
   reg [13:0] 		adcfi_init = 14'b11001100110011;
   reg [13:0] 		adcfq_init = 14'b10001000100011;
   reg [13:0] 		adcri_init = 14'b11100011100011;
   reg [13:0] 		adcrq_init = 14'b11110000111101;
   wire [15:0] 		dat_o;
   reg [15:0] 		result, i, result1, result2, result3, result4;
   integer 		read;

   localparam TG1 = 8'h80, TG2 = 8'ha0, TG3 = 8'hc0, TG4 = 8'he0;

   initial begin
      $dumpfile("tg_test.vcd");
      $dumpvars(0);

      clkrst.reset;
      wait(tg_test.xdig.DCM_clk.LOCKED);

      @ (posedge clk);
      emc.rd(`VERSION_AD, result);
      $write("Reading VERSION = %04x\n", result);

      @ (posedge clk);
      emc.wr(`CONF_AD, 16'h0101);		// enable TG1
      @ (posedge clk);
      emc.wr(TG1 + `TG_TCONF_AD, 16'h0100);	// phase modulation by pi/2
      @ (posedge clk);
      emc.wr(TG1 + `TG_TCTRL_AD, 16'h2000);	// clear TQUEUE
      @ (posedge clk);
      emc.wr2(TG1 + `TG_TQUEUE_AD, 32'h30000004); // pwr=48, np=4
      @ (posedge clk);
      emc.wr2(TG1 + `TG_TQUEUE_AD, 32'h0000001e); // td=30
      @ (posedge clk);
      emc.wr2(TG1 + `TG_TQUEUE_AD, 32'h00040002); // tf=4, tw=2
      @ (posedge clk);
      emc.wr2(TG1 + `TG_TQUEUE_AD, 32'h30000000); // freq=48
      @ (posedge clk);
      @ (posedge clk);
      emc.wr2(TG1 + `TG_TQUEUE_AD, 32'h30000003); // pwr=48, np=3
      @ (posedge clk);
      emc.wr2(TG1 + `TG_TQUEUE_AD, 32'h00000001); // td=1
      @ (posedge clk);
      emc.wr2(TG1 + `TG_TQUEUE_AD, 32'h00030003); // tf=3, tw=3
      @ (posedge clk);
      emc.wr2(TG1 + `TG_TQUEUE_AD, 32'h30000000); // freq=48
      @ (posedge clk);
      @ (posedge clk);
      emc.wr2(TG1 + `TG_TQUEUE_AD, 32'h28000002); // pwr=40, np=2
      @ (posedge clk);
      emc.wr2(TG1 + `TG_TQUEUE_AD, 32'h00000002); // td=2
      @ (posedge clk);
      emc.wr2(TG1 + `TG_TQUEUE_AD, 32'h00020004); // tf=2, tw=4
      @ (posedge clk);
      emc.wr2(TG1 + `TG_TQUEUE_AD, 32'h30000000); // freq=48
      @ (posedge clk);
      @ (posedge clk);
      emc.wr2(TG1 + `TG_TQUEUE_AD, 32'h28000001); // np=1
      @ (posedge clk);
      emc.wr2(TG1 + `TG_TQUEUE_AD, 32'h00000003); // td=3
      @ (posedge clk);
      emc.wr2(TG1 + `TG_TQUEUE_AD, 32'h00010005); // tf=1, tw=5
      @ (posedge clk);
      emc.wr2(TG1 + `TG_TQUEUE_AD, 32'h30000000); // freq=48
      @ (posedge clk);
      emc.wr(TG1 + `TG_TCTRL_AD, 16'h1000);	// arm TG1

      @ (posedge clk);
      emc.rd(TG1 + `TG_TQ_STAT_AD, result);
      $write("Reading TG1 TQ_STAT = %04x\n", result);
      @ (posedge clk);
      emc.rd(`STAT_AD, result);
      $write("Reading STAT = %04x\n", result);

      @ (posedge clk);
      emc.wr(TG1 + `TG_TCTRL_AD, 16'h0800);	// trigger TG1

      wait(tg_test.xdig.tg[1].tdone);

      @ (posedge clk);
      emc.wr(TG1 + `TG_TCTRL_AD, 16'h2000);	// clear TQUEUE
      @ (posedge clk);
      emc.wr(`CONF_AD, 16'h1101);		// enable TG1 meas
      @ (posedge clk);
      emc.wr2(TG1 + `TG_TQUEUE_AD, 32'h30_010_032); // pwr=40, tc=16, np=40
      @ (posedge clk);
      emc.wr2(TG1 + `TG_TQUEUE_AD, 32'h0000_0000); // to=0, td=0
      @ (posedge clk);
      emc.wr2(TG1 + `TG_TQUEUE_AD, 32'h0002_0001); // tf=2, tw=1
      @ (posedge clk);
      emc.wr2(TG1 + `TG_TQUEUE_AD, 32'h30_00a_000); // freq=48, ts=2, tk=0
      @ (posedge clk);
      emc.wr(`CTRL_AD, 16'h0001);		// arm TG1
      @ (posedge clk);
      emc.wr(`CTRL_AD, 16'h0100);		// trigger TG1
      //emc.wr(TG1 + `TG_TCTRL_AD, 16'h0800);	// trigger TG1

      wait(tg_test.xdig.tg[1].tdone);

      @ (posedge clk);
      emc.rd(TG1 + `TG_MQUEUE_AD, result1);
      @ (posedge clk);
      @ (posedge clk);
      emc.rd(TG1 + `TG_MQUEUE_AD, result2);
      @ (posedge clk);
      @ (posedge clk);
      emc.rd(TG1 + `TG_MQUEUE_AD, result3);
      @ (posedge clk);
      @ (posedge clk);
      emc.rd(TG1 + `TG_MQUEUE_AD, result4);
      $write("Reading TG1 MQUEUE = %04x %04x %04x %04x\n", result1, result2, result3, result4);
      @ (posedge clk);
      @ (posedge clk);
      emc.rd(TG1 + `TG_MQUEUE_AD, result1);
      @ (posedge clk);
      @ (posedge clk);
      emc.rd(TG1 + `TG_MQUEUE_AD, result2);
      @ (posedge clk);
      @ (posedge clk);
      emc.rd(TG1 + `TG_MQUEUE_AD, result3);
      @ (posedge clk);
      @ (posedge clk);
      emc.rd(TG1 + `TG_MQUEUE_AD, result4);
      $write("Reading TG1 MQUEUE = %04x %04x %04x %04x\n", result1, result2, result3, result4);
      @ (posedge clk);
      @ (posedge clk);
      emc.rd(TG1 + `TG_MQUEUE_AD, result1);
      @ (posedge clk);
      @ (posedge clk);
      emc.rd(TG1 + `TG_MQUEUE_AD, result2);
      @ (posedge clk);
      @ (posedge clk);
      emc.rd(TG1 + `TG_MQUEUE_AD, result3);
      @ (posedge clk);
      @ (posedge clk);
      emc.rd(TG1 + `TG_MQUEUE_AD, result4);
      $write("Reading TG1 MQUEUE = %04x %04x %04x %04x\n", result1, result2, result3, result4);

      $finish;
   end

   initial begin
      #100000 $write("ERROR: EMC testbench timed out\n");
      $stop(2);
   end

   // clock/reset generator
   clkrst clkrst(.clk(clk), .clk2x(clk2x), .rst(rst));

   // master EMC BFM
   emc_master #(.AW(AW), .WAITOEN(WAITOEN), .WAITRD(WAITRD), .WAITWEN(WAITWEN), .WAITWR(WAITWR))
   emc(.clk_i(clk2x), .rst_i(rst), .A(A), .D(D), .WEN(WEN), .CSN(CSN), .OEN(OEN));

   xdig xdig (.ADCF_SCK(adc_sck), .ADCF_SDO(adcf_sdo), .ADCR_SDO(adcr_sdo), .CONVP(adc_conv),
	      .FPGA_CLK(clk), .A(A[7:1]), .D(D), .WEN(WEN), .OEN(OEN), .CSN(CSN), .RST(rst));

   // starts with adcfi_init = 14'h48d => 16'h1234, adcfq_init = 14'h8d1 => 16'h2344
   //             adcri_init = 14'hd15 => 16'h3454, adcrq_init = 14'h1159 => 16'h4565
   always begin
      adcf = 0;
      adcr = 0;
      adcf_sdo = 1'bz;
      adcr_sdo = 1'bz;
      @ (posedge adc_conv);
      @ (posedge adc_sck);
      @ (posedge adc_sck);
      #8;
      adcf = adcfi_init;
      adcr = adcri_init;
      for (i=1; i<16; i=i+1) begin
	 @ (posedge adc_sck);
	 #8;
	 adcf_sdo = adcf[13];
	 adcr_sdo = adcr[13];
	 adcf = {adcf[12:0], 1'b0};
	 adcr = {adcr[12:0], 1'b0};
      end
      adcf_sdo = 1'bz;
      adcr_sdo = 1'bz;
      @ (posedge adc_sck);
      #8;
      adcf = adcfq_init;
      adcr = adcrq_init;
      for (i=1; i<16; i=i+1) begin
	 @ (posedge adc_sck);
	 #8;
	 adcf_sdo = adcf[13];
	 adcr_sdo = adcr[13];
	 adcf = {adcf[12:0], 1'b0};
	 adcr = {adcr[12:0], 1'b0};
      end
      adcf_sdo = 1'bz;
      adcr_sdo = 1'bz;
      adcfi_init = adcfi_init + 1;
      adcfq_init = adcfq_init + 1;
      adcri_init = adcri_init + 1;
      adcrq_init = adcrq_init + 1;
   end
   
endmodule
