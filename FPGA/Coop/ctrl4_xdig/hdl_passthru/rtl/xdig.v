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
// File name:		xdig.v
// Project:		Ctrl4 extended digital, passthru image
// Author: 		Roger Williams <roger.williams@nxp.com> (RAW)
// -----------------------------------------------------------------------------
// 0.02.0  2013-10-31 (RAW) Removed SS_IN
// 0.01.0  2013-09-30 (RAW) Initial entry
//------------------------------------------------------------------------------

//`include "registers_def.v"
//`include "version.v"
`include "timescale.v"

module xdig
  (
   // MCU passthru interface
   // input wire     ADC_MOSI_IN, ADC_SS_IN,
   input wire 	     ADC_SCK_IN,
   output reg 	     ADC_MISO_OUT,
   input wire [2:0]  ADC_SSEL,
   input wire [4:1]  CONV_IN,
   input wire [4:1]  BIAS_ENN,
   input wire [4:1]  GATE,
   input wire [4:1]  RF_PWM,
   input wire [2:0]  I2C_SEL,
   input wire 	     CFG_SSELN, DAC_SSELN, SYN_SSELN, VGA_SSELN,
   output reg 	     MISO_OUT,
   input wire 	     MOSI_IN,
   input wire 	     SCK_IN,
   // input wire 	     SS_IN,
   input wire [1:0]  SSEL,
   input wire 	     MCU_SYNCOUT,
   output reg 	     MCU_TRIGIN,
   output reg [2:0]  ANTSEL,
    // Zmon ADC interfaces
   output wire [4:1] ADCF_SCK,
   input wire [4:1]  ADCF_SDO,
   output wire [4:1] ADCR_SCK,
   input wire [4:1]  ADCR_SDO,
   output wire [4:1] CONVP,
   output wire [4:1] CONVN,
    // RF channel interfaces
   output wire 	     I2CINT,
   output wire [4:1] I2C,
   input wire [4:1]  MISO,
   output wire [4:1] MOSI,
   output wire [4:1] SCK,
   output wire [4:1] DACSSN,
   output wire [4:1] SYNSSN,
   output wire [4:1] VGASSN,
   output wire [4:1] RF_ENN,
   output wire [4:1] RF_GATE,
    // External I/O
   input wire 	     EXT_UNLOCK,
   //input wire		SYNC_IN,
   output wire 	     SYNC_OUTX,
   output wire 	     TEST_LEDN,
   input wire [4:1]  TRIG_IN,
    // MCU memory interface
   // input wire [9:1]  A,
   // inout wire [15:0] D,
   // input wire     OEN, FPGA_CSN, WEN,
   // input wire [1:0] BLSN,
    // Clocks
   input wire 	     FPGA_CLK		// 100MHz
   );

   // connect MCU SSP1 to internal flash
   // MCU SSP: CPOL=1, CPHA=1, so SCK high when idle, data changed on falling edges
   wire 		cfg_sck = CFG_SSELN | SCK_IN; // SCK high when idle
   wire 		cfg_csb = CFG_SSELN;
   wire 		cfg_miso;
   SPI_ACCESS #(.SIM_DEVICE("3S400AN"))
   SPI_ACCESS_inst (.MISO(cfg_miso), .MOSI(MOSI_IN), .CSB(cfg_csb),.CLK(cfg_sck));

   // multiplex MCU SSP1 to RF channel synthesisers
   // MCU SSP: CPOL=0, CPHA=0 (CPHA=1 for DAC), so SCK low when idle
   assign MOSI[1] = (SSEL == 2'd0) ? MOSI_IN : 1'b0;
   assign MOSI[2] = (SSEL == 2'd1) ? MOSI_IN : 1'b0;
   assign MOSI[3] = (SSEL == 2'd2) ? MOSI_IN : 1'b0;
   assign MOSI[4] = (SSEL == 2'd3) ? MOSI_IN : 1'b0;
   assign SCK[1] = (SSEL == 2'd0) ? SCK_IN : 1'b0;
   assign SCK[2] = (SSEL == 2'd1) ? SCK_IN : 1'b0;
   assign SCK[3] = (SSEL == 2'd2) ? SCK_IN : 1'b0;
   assign SCK[4] = (SSEL == 2'd3) ? SCK_IN : 1'b0;
   assign DACSSN[1] = (SSEL == 2'd0) ? DAC_SSELN : 1'b1;
   assign DACSSN[2] = (SSEL == 2'd1) ? DAC_SSELN : 1'b1;
   assign DACSSN[3] = (SSEL == 2'd2) ? DAC_SSELN : 1'b1;
   assign DACSSN[4] = (SSEL == 2'd3) ? DAC_SSELN : 1'b1;
   assign SYNSSN[1] = (SSEL == 2'd0) ? SYN_SSELN : 1'b1;
   assign SYNSSN[2] = (SSEL == 2'd1) ? SYN_SSELN : 1'b1;
   assign SYNSSN[3] = (SSEL == 2'd2) ? SYN_SSELN : 1'b1;
   assign SYNSSN[4] = (SSEL == 2'd3) ? SYN_SSELN : 1'b1;
   assign VGASSN[1] = (SSEL == 2'd0) ? VGA_SSELN : 1'b1;
   assign VGASSN[2] = (SSEL == 2'd1) ? VGA_SSELN : 1'b1;
   assign VGASSN[3] = (SSEL == 2'd2) ? VGA_SSELN : 1'b1;
   assign VGASSN[4] = (SSEL == 2'd3) ? VGA_SSELN : 1'b1;

   // multiplex MISO outputs back to SSP1
   always @*
      if (~CFG_SSELN)
	 MISO_OUT = cfg_miso;
      else if (~VGA_SSELN)	// DAC and SYN can't talk back
	 case (SSEL)
	   2'd0: MISO_OUT = MISO[1];
	   2'd1: MISO_OUT = MISO[2];
	   2'd2: MISO_OUT = MISO[3];
	   2'd3: MISO_OUT = MISO[4];
	 endcase
      else
	 MISO_OUT = 0;

   // multiplex MCU SSP0 to Zmon ADCs
   assign ADCF_SCK[1] = (ADC_SSEL == 3'd0) ? ADC_SCK_IN : 1'b0;
   assign ADCR_SCK[1] = (ADC_SSEL == 3'd1) ? ADC_SCK_IN : 1'b0;
   assign ADCF_SCK[2] = (ADC_SSEL == 3'd2) ? ADC_SCK_IN : 1'b0;
   assign ADCR_SCK[2] = (ADC_SSEL == 3'd3) ? ADC_SCK_IN : 1'b0;
   assign ADCF_SCK[3] = (ADC_SSEL == 3'd4) ? ADC_SCK_IN : 1'b0;
   assign ADCR_SCK[3] = (ADC_SSEL == 3'd5) ? ADC_SCK_IN : 1'b0;
   assign ADCF_SCK[4] = (ADC_SSEL == 3'd6) ? ADC_SCK_IN : 1'b0;
   assign ADCR_SCK[4] = (ADC_SSEL == 3'd7) ? ADC_SCK_IN : 1'b0;

   // multiplex ADC_SDO outputs back to MCU
   always @*
      case (ADC_SSEL)
	3'd0: ADC_MISO_OUT = ADCF_SDO[1];
	3'd1: ADC_MISO_OUT = ADCR_SDO[1];
	3'd2: ADC_MISO_OUT = ADCF_SDO[2];
	3'd3: ADC_MISO_OUT = ADCR_SDO[2];
	3'd4: ADC_MISO_OUT = ADCF_SDO[3];
	3'd5: ADC_MISO_OUT = ADCR_SDO[3];
	3'd6: ADC_MISO_OUT = ADCF_SDO[4];
	3'd7: ADC_MISO_OUT = ADCR_SDO[4];
      endcase

   // convert CONV signals to LVDS outputs
   OBUFDS #(.IOSTANDARD("LVDS_33"))
   OBUFDS_conv[4:1] (.O(CONVP), .OB(CONVN), .I(CONV_IN));

   // enable I2C bus switches
   assign I2CINT = (I2C_SEL == 3'd0);
   assign I2C[1] = (I2C_SEL == 3'd1);
   assign I2C[2] = (I2C_SEL == 3'd2);
   assign I2C[3] = (I2C_SEL == 3'd3);
   assign I2C[4] = (I2C_SEL == 3'd4);

   // assign RF channel bias enables
   assign RF_ENN = ~({4{~EXT_UNLOCK}} & ~BIAS_ENN);

   // assign RF gate signals
   assign RF_GATE = GATE & RF_PWM;

   // connect MCU sync output
   assign SYNC_OUTX = MCU_SYNCOUT;

   // connect unused outputs
   assign TEST_LEDN = 1'b1;

   wire 		clk10, clkdv, clk100, clk0, clkin;
   DCM #(.CLKDV_DIVIDE(10), .CLKIN_PERIOD("10ns"))
   DCM_clk (.CLK0(clk0), .CLKDV(clkdv), .CLKFB(clk100), .CLKIN(clkin));
   IBUFG IBUFG_clkin (.I(FPGA_CLK), .O(clkin));
   BUFG BUFG_clk100 (.I(clk0), .O(clk100));
   BUFG BUFG_clk10 (.I(clkdv), .O(clk10));

   // input trigger filters
   wire [4:1] 		trigflt;
   reg 			anytrigvld, anytrigvld_dly;
   reg [2:0]		antdecode = 3'b111;
   trig_filter #(.N(10000)) filter[4:1] (.I(TRIG_IN), .O(trigflt), .C(clk10));

   // decode filtered (validated) triggers
   always @*
      case (trigflt)
	4'b0001:	antdecode = 3'b000;
	4'b0010:	antdecode = 3'b001;
	4'b0100:	antdecode = 3'b010;
	4'b1000:	antdecode = 3'b011;
	default:	antdecode = 3'b111;
      endcase

   // latch decoded trigger shortly after validated edge
   always @(posedge clk100) begin
      anytrigvld <= | trigflt;
      anytrigvld_dly <= anytrigvld;
      MCU_TRIGIN <= anytrigvld_dly;
      if (anytrigvld & ~anytrigvld_dly)
	 ANTSEL <= antdecode;
   end

endmodule
 
