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
// Project:		Ctrl4 extended digital, timing generator image
// Author: 		Roger Williams <roger.williams@nxp.com> (RAW)
// -----------------------------------------------------------------------------
// 0.10.0  2013-09-30 (RAW) Initial entry
//------------------------------------------------------------------------------

`include "registers_def.v"
`include "version.v"
`include "timescale.v"

module xdig
  (
   // MCU interface
   input wire [4:1]  CHAN_ENN,
   input wire [2:0]  I2C_SEL,
   input wire 	     CFG_SSELN, DAC_SSELN, SYN_SSELN, VGA_SSELN,
   output wire 	     MISO_OUT,
   input wire 	     MOSI_IN,
   input wire 	     SCK_IN,
   input wire 	     SS_IN, // active LOW
   input wire [1:0]  SSEL,
   input wire 	     MCU_SYNCOUT,
   output reg 	     MCU_TRIGIN,
   output reg [2:0]  ANTSEL,
   output wire       GPIO519,
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
   output wire 	     I2CEXT,
   output reg [4:1]  MOSI = 4'b0,
   output reg [4:1]  SCK = 4'b0,
   output reg [4:1]  DACSSN = 4'b1,
   output reg [4:1]  SYNSSN = 4'b1,
   output reg [4:1]  VGASSN = 4'b1,
   output wire [4:1] RF_ENN,
   output wire [4:1] RF_GATE,
   // External I/O
   input wire 	     EXT_UNLOCK,
   input wire [11:0] EXTDIG_IN,
   input wire 	     SYNC_IN,
   output reg 	     SYNC_OUTX = 1'b0,
   output wire 	     TEST_LEDN,
   input wire [4:1]  TRIG_INN, // trigger on falling edge
   // MCU memory interface
   input wire [7:1]  A,
   inout wire [15:0] D,
   input wire 	     OEN, CSN, WEN,
   output wire 	     FPGA_IRQN,
   // output wire 	CLKOUT,
`ifdef SYNTHESIS
   input wire 	     RST,
`endif
   // Clocks
   input wire 	     FPGA_CLK		// 100MHz
   );

`ifndef SYNTHESIS
   wire 		RST = 1'b0;
`endif
   wire [`REG_BITS_R] 	reg_r;
   wire [`REG_BITS_W] 	reg_w;
   assign reg_r[`VERSION_INDEX] = `VERSION;
   reg [11:0] 		extdig = 12'b0;
   assign reg_r[`EXTDIG_INDEX] = {4'b0, extdig};
   wire [15:0] 		stat;
   assign reg_r[`STAT_INDEX] = stat;
   wire [15:0] 		irq;
   assign reg_r[`IRQ_INDEX] = irq;

   reg [15:0] 		dat_o;
   assign D = (~CSN & ~OEN) ? dat_o : {16{1'bz}};

   wire [4:1] 		test;				// can be muxed to SYNC_OUT

   (* keep = "true" *) wire clk, clk200, clk10;
   wire 		clkdv, clkin, clk0, clk2x;

   // reclock strobes in 100MHz domain
   reg [15:0] 		ctrl = 16'b0;
   wire			ctrl_RST = ctrl[15];		// reset everything
   wire			ctrl_ABT = ctrl[14];		// abort bursts, clear arm
   wire [4:1]		ctrl_TRIG = ctrl[11:8];		// manually trigger specified channels
   wire [4:1]		ctrl_ARM = ctrl[3:0];		// arm specified channels for triggering
   always @(posedge clk) begin
     ctrl <= reg_w[`CTRL_INDEX];
   end

   reg [15:0] 		multiboot = 16'b0;
   wire			multiboot_INIT = multiboot[0];
   always @(posedge clk)
     multiboot <= reg_w[`MULTIBOOT_INDEX];

   reg [15:0] 		irq_clr = 16'b0;
   always @(posedge clk)
     irq_clr <= reg_w[`IRQ_CLR_INDEX];

   always @(posedge clk)
     extdig <= EXTDIG_IN;
      
   // bit field assignments for CONF register
   wire [15:0]		conf = reg_w[`CONF_INDEX];
   wire [4:1]		conf_MEAS_EN = conf[15:12];	// enable Zmon measurements on specified channels
   wire [4:1]		conf_SRC_EN = conf[11:8];	// enable RF outputs on specified channels
   wire [4:1]		conf_CONT = conf[7:4];		// enable continuous retriggering on specified channels
   wire [4:1]		conf_TG_EN = conf[3:0];		// enable timing generators on specified channels

   // bit field assignments for TRIG_SRC register
   // 0 = off (manual only), 1-4 = specified TRIG input
   wire [15:0]		trig_src = reg_w[`TRIG_SRC_INDEX];

   // bit field assignments for IRQ_MASK register
   wire [15:0]		irq_mask = reg_w[`IRQ_MASK_INDEX];

   // bit field assignments for SYNC register
   // 0=MCU, 1=GEN, 4-7=TRIG1-4, 8-11=TDONE1-4, 12-15=MDONE1-4, 16-19=CONV[1:4], 20-23=GATE[1:4], 24=MCU_TRIGIN
   wire [15:0]		sync = reg_w[`SYNC_INDEX];
   wire [7:0] 		sync_GEN = sync[15:8];
   wire [4:0] 		sync_SRC = sync[4:0];

   // bit field assignments for FILTER register
   wire [15:0]		filter_len = reg_w[`FILTER_INDEX];

   // connect MCU SSP1 to internal flash
   // MCU SSP: CPOL=1, CPHA=1, so SCK high when idle, data changed on falling edges
`ifndef SYNTHESIS
   wire 		cfg_sck = CFG_SSELN | SCK_IN; // SCK high when idle
   SPI_ACCESS #(.SIM_DEVICE("3S400AN"))
   SPI_ACCESS_inst (.MISO(MISO_OUT), .MOSI(MOSI_IN), .CSB(~(~CFG_SSELN & ~SS_IN)),
		    .CLK(cfg_sck)); // CSB is active low
`else
   assign MISO_OUT = 1'b0;
`endif

   // enable I2C bus switches
   assign I2CINT = (I2C_SEL == 3'd0);
   assign I2C[1] = (I2C_SEL == 3'd1);
   assign I2C[2] = (I2C_SEL == 3'd2);
   assign I2C[3] = (I2C_SEL == 3'd3);
   assign I2C[4] = (I2C_SEL == 3'd4);
   assign I2CEXT = (I2C_SEL == 3'd5);

   // assign RF channel bias enables
   assign RF_ENN = ~({4{~EXT_UNLOCK}} & conf_SRC_EN & ~CHAN_ENN);

   // convert CONV signals to LVDS outputs
   wire [4:1] 		conv_o;
   OBUFDS #(.IOSTANDARD("LVDS_33"))
   OBUFDS_conv[4:1] (.O(CONVP), .OB(CONVN), .I(conv_o));

/* -----\/----- EXCLUDED -----\/-----
   // double 100MHz input clock to internal 200MHz clock
   DCM #(.CLKDV_DIVIDE(5), .CLKIN_PERIOD("10ns"), .CLK_FEEDBACK("2X"), .PHASE_SHIFT(0), .CLKFX_MULTIPLY(4),
	 .CLKOUT_PHASE_SHIFT("FIXED"), .STARTUP_WAIT("TRUE"), .CLKIN_DIVIDE_BY_2("TRUE"))
   DCM_clk (.CLK2X(clk0), .CLKDV(clkdv), .CLKFB(clk), .CLKIN(clkin), .CLKFX(clk2x), .RST(RST));
 -----/\----- EXCLUDED -----/\----- */
   // double 100MHz input clock to internal 200MHz clock
   DCM_SP #(.CLKDV_DIVIDE(10), .CLKIN_PERIOD("10ns"), .CLK_FEEDBACK("1X"), .PHASE_SHIFT(0),
	    .CLKOUT_PHASE_SHIFT("FIXED"), .STARTUP_WAIT("TRUE"), .CLKIN_DIVIDE_BY_2("FALSE"))
   DCM_clk (.CLK0(clk0), .CLKDV(clkdv), .CLKFB(clk), .CLKIN(clkin), .CLK2X(clk2x), .RST(RST),
	    .LOCKED(GPIO519));
   BUFG BUFG_clkin (.I(FPGA_CLK), .O(clkin));
   BUFG BUFG_clk10 (.I(clkdv), .O(clk10));
   BUFG BUFG_clk (.I(clk0), .O(clk));
   BUFG BUFG_clk200 (.I(clk2x), .O(clk200));

   // pulse generator
   reg [13:0] 		gprescale = 14'b0;
   reg [7:0] 		gcount = 8'b0;
   reg 			gen = 1'b0;
   wire 		gtick1ms = (gprescale == 14'b0);
   
   always @(posedge clk10)
     if (gtick1ms)
       gprescale <= 9999;
     else
       gprescale <= gprescale - 1;

   always @(posedge clk10)
     if (gtick1ms) begin
	if (gcount == 5)
	  gen <= 1;
	else if (gcount == 0)
	  gen <= 0;
	if (gcount == 0) begin
	   if (sync_GEN > 4)
	     gcount <= sync_GEN;
	end
	else
	  gcount <= gcount - 1;
     end

   // test LED
   wire 		led_trig;
   wire 		led_active = ~RF_ENN[1];
   reg [10:0]		led_timer = 11'b0;
   reg 			led_trig10 = 0;
   reg 			led = 0;
   reg 			led_holdoff = 0;
   assign TEST_LEDN = ~led;

   always @(posedge clk)	// capture short trigger in clk10 domain
     if (led_active) begin
	if (led_trig)
	  led_trig10 <= 1;
	else if (led)
	  led_trig10 <= 0;
     end
     else
       led_trig10 <= 0;

   always @(posedge clk10)
     if (led_active) begin
	if (gtick1ms) begin
	   if (!led_holdoff & led_trig10) begin
	      led <= 1;
	      led_holdoff <= 1;
	      led_timer <= 0;
	   end
	   else begin
	      led_timer <= led_timer + 1;
	      if (led_timer == 50)
		led <= 0;
	      else if (led_timer == 100)
		led_holdoff <= 0;
	      else if (led_timer == (2047-5))
		led <= 1;
	      else if (led_timer == 2047)
		led <= 0;
	   end
	end
     end
     else begin
	led <= 0;
     end

   // input trigger filters
   wire [5:1] 		trigflt;
   reg [2:0]		antdecode = 3'b111;
   reg [5:1] 		trigflt_dly = 4'b0;
   wire [5:1] 		trig_rising = trigflt & ~trigflt_dly;
   wire [5:1] 		trig_falling = ~trigflt & trigflt_dly;
   wire			anytrig = | trig_rising;
   trig_filter filter[4:1] (.I(TRIG_INN), .O(trigflt[4:1]), .C(clk10), .N(filter_len));
   assign trigflt[5] = gen;

   // decode which trigger just occurred
   always @*
      case (trig_rising)
	5'b00001:	antdecode = 3'b000;
	5'b00010:	antdecode = 3'b001;
	5'b00100:	antdecode = 3'b010;
	5'b01000:	antdecode = 3'b011;
	5'b10000:	antdecode = 3'b101;
	default:	antdecode = 3'b111;
      endcase

   // latch decoded trigger at valid rising edge
   always @(posedge clk) begin
      trigflt_dly <= trigflt;
      if (anytrig)
	 ANTSEL <= antdecode;
   end
   
   // demux signals to timing generators
   reg [4:1] 		trig_mux;
   always @* begin
     case (trig_src[1*4-1 -: 4])
       4'd1: trig_mux[1] = trig_falling[1];
       4'd2: trig_mux[1] = trig_falling[2];
       4'd3: trig_mux[1] = trig_falling[3];
       4'd4: trig_mux[1] = trig_falling[4];
       4'd5: trig_mux[1] = trig_falling[5];
       default: trig_mux[1] = 1'b0;
     endcase
     case (trig_src[2*4-1 -: 4])
       4'd1: trig_mux[2] = trig_falling[1];
       4'd2: trig_mux[2] = trig_falling[2];
       4'd3: trig_mux[2] = trig_falling[3];
       4'd4: trig_mux[2] = trig_falling[4];
       4'd5: trig_mux[2] = trig_falling[5];
       default: trig_mux[2] = 1'b0;
     endcase
     case (trig_src[3*4-1 -: 4])
       4'd1: trig_mux[3] = trig_falling[1];
       4'd2: trig_mux[3] = trig_falling[2];
       4'd3: trig_mux[3] = trig_falling[3];
       4'd4: trig_mux[3] = trig_falling[4];
       4'd5: trig_mux[3] = trig_falling[5];
       default: trig_mux[3] = 1'b0;
     endcase
     case (trig_src[4*4-1 -: 4])
       4'd1: trig_mux[4] = trig_falling[1];
       4'd2: trig_mux[4] = trig_falling[2];
       4'd3: trig_mux[4] = trig_falling[3];
       4'd4: trig_mux[4] = trig_falling[4];
       4'd5: trig_mux[4] = trig_falling[5];
       default: trig_mux[4] = 1'b0;
     endcase
   end

   reg [4:1] 		trig = 4'b0;
   assign led_trig = trig[1];
   always @(posedge clk)
      trig <= ctrl_TRIG | trig_mux;

   // demux signals for clearing MCU_TRIGIN
   reg [4:1] 		rising_mux;
   always @* begin
     case (trig_src[1*4-1 -: 4])
       4'd1: rising_mux[1] = trig_rising[1];
       4'd2: rising_mux[1] = trig_rising[2];
       4'd3: rising_mux[1] = trig_rising[3];
       4'd4: rising_mux[1] = trig_rising[4];
       4'd5: rising_mux[1] = trig_rising[5];
       default: rising_mux[1] = 1'b0;
     endcase
     case (trig_src[2*4-1 -: 4])
       4'd1: rising_mux[2] = trig_rising[1];
       4'd2: rising_mux[2] = trig_rising[2];
       4'd3: rising_mux[2] = trig_rising[3];
       4'd4: rising_mux[2] = trig_rising[4];
       4'd5: rising_mux[2] = trig_rising[5];
       default: rising_mux[2] = 1'b0;
     endcase
     case (trig_src[3*4-1 -: 4])
       4'd1: rising_mux[3] = trig_rising[1];
       4'd2: rising_mux[3] = trig_rising[2];
       4'd3: rising_mux[3] = trig_rising[3];
       4'd4: rising_mux[3] = trig_rising[4];
       4'd5: rising_mux[3] = trig_rising[5];
       default: rising_mux[3] = 1'b0;
     endcase
     case (trig_src[4*4-1 -: 4])
       4'd1: rising_mux[4] = trig_rising[1];
       4'd2: rising_mux[4] = trig_rising[2];
       4'd3: rising_mux[4] = trig_rising[3];
       4'd4: rising_mux[4] = trig_rising[4];
       4'd5: rising_mux[4] = trig_rising[5];
       default: rising_mux[4] = 1'b0;
     endcase
   end

   always @(posedge clk)
     if (trig_mux)
       MCU_TRIGIN <= 0;
     else if (rising_mux)
       MCU_TRIGIN <= 1;

   localparam WC = 8, WS = 8;

   // register block decodes
   reg			reg_sel;
   reg [4:1]		tg_sel;
   wire [15:0] 		reg_dat_o;
   wire [16*4-1:0]	tg_dat_o;

   always @* begin
      reg_sel = 0;
      tg_sel = 4'b0;
      dat_o = 16'b0;
      if (A[7] == 0) begin
	 reg_sel = ~CSN;
	 dat_o = reg_dat_o;
      end
      else begin
	 case (A[6:5])
	   2'd0: begin
	      tg_sel[1] = ~CSN;
	      dat_o = tg_dat_o[1*16-1 -: 16];
	   end
	   2'd1: begin
	      tg_sel[2] = ~CSN;
	      dat_o = tg_dat_o[2*16-1 -: 16];
	   end
	   2'd2: begin
	      tg_sel[3] = ~CSN;
	      dat_o = tg_dat_o[3*16-1 -: 16];
	   end
	   2'd3: begin
	      tg_sel[4] = ~CSN;
	      dat_o = tg_dat_o[4*16-1 -: 16];
	   end
	 endcase
      end
   end

   // decode SPI from MCU
   reg [4:1] 		dacss = 4'b0;
   reg [4:1] 		synss = 4'b0;
   reg [4:1] 		vgass = 4'b0;
   always @*
     case (SSEL)
       2'd0: begin
	  dacss = {3'b000, ~DAC_SSELN & ~SS_IN};
	  synss = {3'b000, ~SYN_SSELN & ~SS_IN};
	  vgass = {3'b000, ~VGA_SSELN & ~SS_IN};
       end
       2'd1: begin
	  dacss = {2'b00, ~DAC_SSELN & ~SS_IN, 1'b0};
	  synss = {2'b00, ~SYN_SSELN & ~SS_IN, 1'b0};
	  vgass = {2'b00, ~VGA_SSELN & ~SS_IN, 1'b0};
       end
       2'd2: begin
	  dacss = {1'b0, ~DAC_SSELN & ~SS_IN, 2'b00};
	  synss = {1'b0, ~SYN_SSELN & ~SS_IN, 2'b00};
	  vgass = {1'b0, ~VGA_SSELN & ~SS_IN, 2'b00};
       end
       2'd3: begin
	  dacss = {~DAC_SSELN & ~SS_IN, 3'b000};
	  synss = {~SYN_SSELN & ~SS_IN, 3'b000};
	  vgass = {~VGA_SSELN & ~SS_IN, 3'b000};
       end
     endcase

   // direct MCU SPI when TG is disabled
   // eliminate this later
   wire [4:1] 		tg_mosi;
   wire [4:1] 		tg_sck;
   wire [4:1] 		tg_dacssn;
   wire [4:1] 		tg_synssn;
   wire [4:1] 		tg_vgassn;
   always @* begin
      if (conf_TG_EN[1]) begin
	 MOSI[1] = tg_mosi[1];
	 SCK[1] = tg_sck[1];
	 DACSSN[1] = tg_dacssn[1];
	 SYNSSN[1] = tg_synssn[1];
	 VGASSN[1] = tg_vgassn[1];
      end
      else begin
	 MOSI[1] = MOSI_IN;
	 SCK[1] = SCK_IN;
	 DACSSN[1] = ~dacss[1];
	 SYNSSN[1] = ~synss[1];
	 VGASSN[1] = ~vgass[1];
      end
      if (conf_TG_EN[2]) begin
	 MOSI[2] = tg_mosi[2];
	 SCK[2] = tg_sck[2];
	 DACSSN[2] = tg_dacssn[2];
	 SYNSSN[2] = tg_synssn[2];
	 VGASSN[2] = tg_vgassn[2];
      end
      else begin
	 MOSI[2] = MOSI_IN;
	 SCK[2] = SCK_IN;
	 DACSSN[2] = ~dacss[2];
	 SYNSSN[2] = ~synss[2];
	 VGASSN[2] = ~vgass[2];
      end
      if (conf_TG_EN[3]) begin
	 MOSI[3] = tg_mosi[3];
	 SCK[3] = tg_sck[3];
	 DACSSN[3] = tg_dacssn[3];
	 SYNSSN[3] = tg_synssn[3];
	 VGASSN[3] = tg_vgassn[3];
      end
      else begin
	 MOSI[3] = MOSI_IN;
	 SCK[3] = SCK_IN;
	 DACSSN[3] = ~dacss[3];
	 SYNSSN[3] = ~synss[3];
	 VGASSN[3] = ~vgass[3];
      end
      if (conf_TG_EN[4]) begin
	 MOSI[4] = tg_mosi[4];
	 SCK[4] = tg_sck[4];
	 DACSSN[4] = tg_dacssn[4];
	 SYNSSN[4] = tg_synssn[4];
	 VGASSN[4] = tg_vgassn[4];
      end
      else begin
	 MOSI[4] = MOSI_IN;
	 SCK[4] = SCK_IN;
	 DACSSN[4] = ~dacss[4];
	 SYNSSN[4] = ~synss[4];
	 VGASSN[4] = ~vgass[4];
      end
   end

   wire [4*WC:1]	control;
   wire [4*WS-1:0] 	status;
   wire [15:0]		irq_in;

   assign control[1*WC -: WC] = {ctrl_RST, ctrl_ABT, ctrl_ARM[1], trig[1], conf_MEAS_EN[1], conf_SRC_EN[1], conf_CONT[1], conf_TG_EN[1]};
   assign control[2*WC -: WC] = {ctrl_RST, ctrl_ABT, ctrl_ARM[2], trig[2], conf_MEAS_EN[2], conf_SRC_EN[2], conf_CONT[2], conf_TG_EN[2]};
   assign control[3*WC -: WC] = {ctrl_RST, ctrl_ABT, ctrl_ARM[3], trig[3], conf_MEAS_EN[3], conf_SRC_EN[3], conf_CONT[3], conf_TG_EN[3]};
   assign control[4*WC -: WC] = {ctrl_RST, ctrl_ABT, ctrl_ARM[4], trig[4], conf_MEAS_EN[4], conf_SRC_EN[4], conf_CONT[4], conf_TG_EN[4]};
   assign stat[1*4-1 -: 4] = status[1*WS-5 -: 4];	// state machine value for each channel
   assign stat[2*4-1 -: 4] = status[2*WS-5 -: 4];
   assign stat[3*4-1 -: 4] = status[3*WS-5 -: 4];
   assign stat[4*4-1 -: 4] = status[4*WS-5 -: 4];
   assign irq_in[1*4-1 -: 4] = status[1*WS-1 -: 4];	// interrupts from each channel
   assign irq_in[2*4-1 -: 4] = status[2*WS-1 -: 4];
   assign irq_in[3*4-1 -: 4] = status[3*WS-1 -: 4];
   assign irq_in[4*4-1 -: 4] = status[4*WS-1 -: 4];

   // 0=MCU, 1=GEN, 4-7=TRIG1-4, 8-11=TDONE1-4, 12-15=MDONE1-4, 16-19=CONV[1:4], 20-23=GATE[1:4], 24=MCU_TRIGIN
   always @*
     case (sync_SRC)
       5'd1: SYNC_OUTX = gen;				// GEN
       5'd3: SYNC_OUTX = MCU_TRIGIN;			// composite trigger to MCU
       5'd4: SYNC_OUTX = trig[1];			// TRIG
       5'd5: SYNC_OUTX = trig[2];
       5'd6: SYNC_OUTX = trig[3];
       5'd7: SYNC_OUTX = trig[4];
       5'd8: SYNC_OUTX = irq_in[0];			// TDONE
       5'd9: SYNC_OUTX = irq_in[1];
       5'd10: SYNC_OUTX = irq_in[2];
       5'd11: SYNC_OUTX = irq_in[3];
       5'd12: SYNC_OUTX = irq_in[12];			// MDONE
       5'd13: SYNC_OUTX = irq_in[13];
       5'd14: SYNC_OUTX = irq_in[14];
       5'd15: SYNC_OUTX = irq_in[15];
       5'd16: SYNC_OUTX = conv_o[1];			// CONV
       5'd17: SYNC_OUTX = conv_o[2];
       5'd18: SYNC_OUTX = conv_o[3];
       5'd19: SYNC_OUTX = conv_o[4];
       5'd20: SYNC_OUTX = RF_GATE[1];			// RF_GATE
       5'd21: SYNC_OUTX = RF_GATE[2];
       5'd22: SYNC_OUTX = RF_GATE[3];
       5'd23: SYNC_OUTX = RF_GATE[4];
       5'd24: SYNC_OUTX = SYNC_IN;
       5'd25: SYNC_OUTX = test[1];
       5'd26: SYNC_OUTX = test[2];
       5'd27: SYNC_OUTX = test[3];
       5'd28: SYNC_OUTX = test[4];
       default: SYNC_OUTX = MCU_SYNCOUT;
     endcase // case (sync_SRC)

   wire [4:1] 		adc_sck;
   assign ADCR_SCK = adc_sck;
   assign ADCF_SCK = adc_sck;

   rs irq_latch[15:0] (.Q(irq), .S(irq_mask & irq_in), .R({16{ctrl_RST}} | irq_clr), .C(clk));
   // assign FPGA_IRQN = ~|(irq_mask & irq_in);		// IRQ pulse for each event
   assign FPGA_IRQN = ~|irq;				// latched IRQ

   reg [7:0] 		icap_byte = 8'b0;
   reg [3:0] 		icap_word = 4'b0;
   reg 			icap_cen = 1'b1;
   reg 			icap_clk = 1'b0;
   wire [7:0] 		icap_in;
   genvar 		i;
   generate
      for (i = 0; i < 8; i = i+1) begin: bitswap
	 assign icap_in[7-i] = icap_byte[i];
      end
   endgenerate
   ICAP_SPARTAN3A icap(.CE(icap_cen), .CLK(icap_clk), .I(icap_in), .WRITE(icap_cen));
   always @*
     case (icap_word)
       4'd0: icap_byte = 8'h00;	// 2 clock cycles required before multiboot sequence
       4'd1: icap_byte = 8'h00;
       4'd2: icap_byte = 8'haa;	// SYNC word
       4'd3: icap_byte = 8'h99;
       4'd4: icap_byte = 8'h30;	// type 1 WRITE command
       4'd5: icap_byte = 8'ha1;
       4'd6: icap_byte = 8'h00;	// REBOOT command
       4'd7: icap_byte = 8'h0e;
       4'd8: icap_byte = 8'h20;	// NOP command
       4'd9: icap_byte = 8'h00;
       default: icap_byte = 8'h00;
     endcase

   localparam IIdle = 3'd0, IStart = 3'd1, IClkRise = 3'd2, IClkFall = 3'd3, IDataChange = 3'd4;
   reg [2:0] 		istate = IIdle;
   always @(posedge clk)
     if (RST) begin
	istate <= IIdle;
	icap_word <= 0;
	icap_cen <= 1;
	icap_clk <= 0;
     end
     else begin
	case (istate)
	  IIdle: begin
	     icap_word <= 0;
	     icap_cen <= 1;
	     icap_clk <= 0;
	     if (multiboot_INIT)
	       istate <= IStart;
	  end
	  IStart: begin
	     icap_cen <= 0;
	     istate <= IClkRise;
	  end
	  IClkRise: begin
	     icap_clk <= 1;
	     istate <= IClkFall;
	  end
	  IClkFall: begin
	     icap_clk <= 0;
	     istate <= IDataChange;
	  end
	  IDataChange: begin
	     if (icap_word == 4'd11) begin
		istate <= IIdle;
	     end
	     else begin
		icap_word <= icap_word + 1;
		istate <= IClkRise;
	     end
	  end
	endcase
     end

   tg tg[4:1] (.control(control), .status(status), .mosi_o(tg_mosi), .sck_o(tg_sck), .clk(clk),
	       .dacssn_o(tg_dacssn), .synssn_o(tg_synssn), .vgassn_o(tg_vgassn), .rf_gate(RF_GATE), .test(test),
	       .mosi_i(MOSI_IN), .sck_i(SCK_IN), .dacss_i(dacss), .synss_i(synss), .vgass_i(vgass),
	       .adc_sck_o(adc_sck), .conv_o(conv_o), .adcr_sdo_i(ADCR_SDO), .adcf_sdo_i(ADCF_SDO),
	       .clk200(clk200), .rst_i(RST), .adr_i(A[4:1]), .dat_i(D), .we_i(~WEN), .oe_i(~OEN), .cs_i(tg_sel), .dat_o(tg_dat_o));

   registers reggie (.clk_i(clk200), .rst_i(RST), .adr_i({A[6:1],1'b0}), .dat_i(D), .we_i(~WEN), .oe_i(~OEN), .cs_i(reg_sel),
		     .dat_o(reg_dat_o), .reg_w(reg_w), .reg_r(reg_r));

endmodule
 
module rs
  (
   input wire	S, R, C,
   output reg	Q = 1'b0
   );

   always @(posedge C)
     if (R)
       Q <= 0;
     else if (S)
       Q <= 1;
   
endmodule
