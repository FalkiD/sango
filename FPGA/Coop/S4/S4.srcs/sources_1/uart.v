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
// File name:  uart.v
// Project:    s4x7
// Author:     Roger Williams <roger.williams@ampleon.com> (RAW)
// Purpose:    Diag/debug access to s4x7 FPGA "backside" internals.
// -----------------------------------------------------------------------------
// 0.00.1  2016-08-04 (JLC) Modified for current project.
// 0.00.2  2017-04-11 (JLC) Modified for s4 backside.
//
//------------------------------------------------------------------------------

// define these constants as macros instead of parameters so that sim can override them
//`define CLK_FREQ        100000000     // 100MHz
`define CLK_FREQ        102000000     // 102MHz
`define I2C_FREQ        400000        // 400kbps
`define SPI_FREQ        1000000       // 1Mbps
`define REF_FREQ        2000000       // 2MHz  (to produce 1MHz square wave)
`define BAUD            115200        // 115200 Baud

module uart #( parameter VRSN = 16'h9876 )
  (
    // diag/debug control signal outputs
    output      [15:0]    hw_ctl_o,
    // diag/debug status  signal inputs
    input       [15:0]    hw_stat_i,
    input       [31:0]    gp_opc_cnt_i,     // count of opcodes processed from top level
    input       [31:0]    ptn_opc_cnt_i,    // count of pattern opcodes processed from top level
    input       [15:0]    sys_stat_vec_i,   // 16-bit status to show, system_state for now
	
    // infrastructure, etc.
    input                 clk_i,            // 
    input                 rst_i,            // 
    output                refclk_o,         // temporary test output
    input                 RxD_i,            // "RxD" from USB serial bridge to FPGA
    output                TxD_o,            // "TxD" from FPGA to USB serial bridge
    output                dbg_o            // Utility debug output.
  );

   // Freq Gen Info
   localparam  I2C_DIV            = `CLK_FREQ / `I2C_FREQ - 1;   // 124
   localparam  SPI_DIV            = `CLK_FREQ / `SPI_FREQ - 1;   // 49
   localparam  REF_DIV            = `CLK_FREQ / `REF_FREQ - 1;   // 24
   localparam  BAUD_DIV           = `CLK_FREQ / `BAUD - 1;       // 867

   // UART state machine state declarations (probably should be mutable as macros):
   localparam  UART_IDLE          = 8'b0000_0000;
   localparam  UART_SEND_PROMPT   = 8'b0000_0001;
   localparam  UART_SEND_CR       = 8'b0000_0010;
   localparam  UART_SEND_LF       = 8'b0000_0011;
   localparam  UART_GETSTAT0      = 8'b0001_0000;
   localparam  UART_GETSTAT1      = 8'b0001_0001;
   localparam  UART_GETSTAT2      = 8'b0001_0010;
   localparam  UART_GETSTAT3      = 8'b0001_0011;
   localparam  UART_GETSTAT4      = 8'b0001_0100;
   localparam  UART_GETSTAT5      = 8'b0001_0101;
   localparam  UART_GETSTAT6      = 8'b0001_0110;
   localparam  UART_GETSTAT7      = 8'b0001_0111;
   localparam  UART_SETCTL0       = 8'b0010_0000;
   localparam  UART_SETCTL1       = 8'b0010_0001;
   localparam  UART_SETCTL2       = 8'b0010_0010;
   localparam  UART_SETCTL3       = 8'b0010_0011;
   localparam  UART_SETCTL4       = 8'b0010_0100;
   localparam  UART_SETCTL5       = 8'b0010_0101;
   localparam  UART_SETCTL6       = 8'b0010_0110;
   localparam  UART_SETCTL7       = 8'b0010_0111;
   localparam  UART_GETOPC0       = 8'b0011_0000;
   localparam  UART_GETOPC1       = 8'b0011_0001;
   localparam  UART_GETOPC2       = 8'b0011_0010;
   localparam  UART_GETOPC3       = 8'b0011_0011;
   localparam  UART_GETOPC4       = 8'b0011_0100;
   localparam  UART_GETOPC5       = 8'b0011_0101;
   localparam  UART_GETOPC6       = 8'b0011_0110;
   localparam  UART_GETOPC7       = 8'b0011_0111;
   localparam  UART_GETPTN0       = 8'b0011_1000;
   localparam  UART_GETPTN1       = 8'b0011_1001;
   localparam  UART_GETPTN2       = 8'b0011_1010;
   localparam  UART_GETPTN3       = 8'b0011_1011;
   localparam  UART_GETPTN4       = 8'b0011_1100;
   localparam  UART_GETPTN5       = 8'b0011_1101;
   localparam  UART_GETPTN6       = 8'b0011_1110;
   localparam  UART_GETPTN7       = 8'b0011_1111;
   localparam  UART_PTNUSC        = 8'b1111_0100;
   localparam  UART_GETARG3       = 8'b1111_0000;
   localparam  UART_GETARG2       = 8'b1111_0001;
   localparam  UART_GETARG1       = 8'b1111_0010;
   localparam  UART_GETARG0       = 8'b1111_0011;
   localparam  UART_GETVER0       = 8'b0100_0000;
   localparam  UART_GETVER1       = 8'b0100_0001;
   localparam  UART_GETVER2       = 8'b0100_0010;
   localparam  UART_GETVER3       = 8'b0100_0011;
   localparam  UART_BADCHAR       = 8'b1111_0101;
   localparam  UART_TEST0         = 8'b1111_1000;
   localparam  UART_TEST1         = 8'b1111_1001;
   localparam  UART_TEST2         = 8'b1111_1010;

  
   // ASCII Char Codes
   localparam  UART_CHAR_CR       = 8'h0d;    // CR                             NOTE:  btn[3] is used as reset!
   localparam  UART_CHAR_LF       = 8'h0a;    // LF
   localparam  UART_CHAR_GT       = 8'h3e;    // '>'
   localparam  UART_CHAR_WTF      = 8'h3f;    // '?'
   localparam  UART_CHAR_USC      = 8'h5f;    // _
   localparam  UART_CHAR_UV       = 8'h56;    // 'V' | 'v':  Get Version
   localparam  UART_CHAR_LV       = 8'h76;
   localparam  UART_CHAR_UR       = 8'h52;    // 'R' | 'r':  Get Diag Data       ([15:0])
   localparam  UART_CHAR_LR       = 8'h72;
   localparam  UART_CHAR_UB       = 8'h42;    // 'B' | 'b':  Get Sws & Buttons   ({sw[3:0], 1'b0. btn[2:0]})
   localparam  UART_CHAR_LB       = 8'h62;
   localparam  UART_CHAR_UL       = 8'h4C;    // 'L' | 'l':  Set Plain LEDs      (ARTY LD7:LD4)
   localparam  UART_CHAR_LL       = 8'h6C;
   localparam  UART_CHAR_UW       = 8'h57;    // 'W' | 'w':  Set Diag Data       ([15:0])
   localparam  UART_CHAR_LW       = 8'h77;
   localparam  UART_CHAR_UX       = 8'h58;    // 'X' | 'x':  No-Op               (just a test)
   localparam  UART_CHAR_LX       = 8'h78;
   localparam  UART_CHAR_UC       = 8'h43;    // 'C' | 'c':  Show count of opcodes_Underscore_countOfPatternOpcodes
   localparam  UART_CHAR_LC       = 8'h63;
   localparam  UART_CHAR_US       = 8'h53;    // 'S' | 's':  Show 16-bit instance arg data
   localparam  UART_CHAR_LS       = 8'h73;
   localparam  UART_CHAR_OK0      = 8'h4F;
   localparam  UART_CHAR_OK1      = 8'h4B;
   localparam  UART_CHAR_OK2      = 8'h21;

   reg  [15:0]            uart_rd_stat     = 16'h0000;
   reg  [3:0]             uart_rd_sw       = 16'h0;
   reg  [2:0]             uart_rd_btn      = 16'h0;
   reg  [15:0]            uart_wr_ctl      = 16'h0000;
   reg  [15:0]            uart_wr_ctlr     = 16'h0000;
   reg                    uart_wr_ctl_stb  = 1'b0;
   reg                    uart_wr_ctl_stbr = 1'b0;
   reg  [3:0]             uart_wr_leds     = 4'h0;

   reg  [6:0]             refclkdiv        = 7'b0;
   reg                    refclkstate      = 1'b0;

   reg  [7:0]             tx_char          = 8'b0;
   reg  [7:0]             rx_charr         = 8'b0;
   wire [7:0] 		      rx_charw;
   
   // serial TX FIFO
   reg  [7:0]             tx_fifo [63:0];   // actual tx FIFO array
   reg  [7:0]             tx_din = 8'b0;    // tx FIFO input data
   reg  [5:0]             txa_addr = 6'b0;  // tx FIFO write addr
   reg  [5:0]             txb_addr = 6'b0;  // tx FIFO read  addr
   reg                    tx_stb1 = 1'b0;   // tx FIFO write strobe
   reg                    tx_stb2 = 1'b0;  // tx FIFO read  strobe
   wire                   tx_stb = tx_stb1 & ~tx_stb2;
   reg                    tx_load = 1'b0;
   wire                   tbre;             // UART xmtr is ready for another char
   wire                   drdy;             // UART rcvr has valid rcv'd char

   wire [15:0]            version_w;
   
   wire                   baudxw;
   
   always @(posedge clk_i) begin
      if (rst_i) begin
         txa_addr                  <= 6'b00_0000;
         txb_addr                  <= 6'b00_0000;
         tx_stb1                   <= 0;
         tx_stb2                   <= 0;
      end
      else begin
         if (tx_load) begin
            tx_fifo[txa_addr]      <= tx_char;
            txa_addr               <= txa_addr + 6'b00_0001;
         end
         tx_din                       <= tx_fifo[txb_addr];
         tx_stb1                      <= (tbre & (txa_addr != txb_addr));
         tx_stb2                      <= tx_stb1;
         if (tx_stb) begin
            txb_addr                  <= txb_addr + 6'b00_0001;
         end
      end
   end  // end of always @ (posedge clk_i)
   // end of Serial TX FIFO

   
   // UART Rx Command Parsing State Machine
   reg  [7:0] 		cmdState     = UART_IDLE;
   reg              snapShot     = 1'b0;
   reg  [6:0]       dbgOutr      = 5'b0_0000;
   reg  [6:0]       dbgOutrr     = 5'b0_0000;
   reg  [6:0]       dbgOutrrr    = 5'b0_0000;
   reg  [6:0]       dbgOutrrrr   = 5'b0_0000;
   
   wire [6:0]       dbgOutw      = dbgOutr | dbgOutrr | dbgOutrrr | dbgOutrrrr;

   // Snapshot:  capture data for R & S commands.   
   always @(posedge clk_i) begin
      if (rst_i) begin
         uart_rd_stat              <= 16'h0000;
         uart_rd_sw                <= 4'b0000;
         uart_rd_btn               <= 3'b000;
      end
      else begin
         if (snapShot == 1'b1) begin
            uart_rd_stat           <= hw_stat_i;
         end
      end
   end  // end of always @ (posedge clk).

   // Command State Machine
   always @(posedge clk_i) begin
      if (rst_i) begin
         cmdState                <= UART_IDLE;
         rx_charr                <= 8'b0;
         tx_char                 <= 8'b0;
         tx_load                 <= 0;
	     snapShot                <= 1'b0;
         uart_wr_ctl             <= 16'h0000;
         uart_wr_ctlr            <= 16'h0000;
         uart_wr_ctl_stb         <= 1'b0;
         uart_wr_ctl_stbr        <= 1'b0;
         dbgOutr                 <= 5'b0_0000;
         dbgOutrr                <= 5'b0_0000;
         dbgOutrrr               <= 5'b0_0000;
         dbgOutrrrr              <= 5'b0_0000;
      end
      else begin
         // clears for one-tick signals
	     snapShot                <= 1'b0;
	     tx_load                 <= 1'b0;
         uart_wr_ctl_stb         <= 1'b0;
   
         // "every-time" assignments
         dbgOutr[0]              <= (txa_addr == 6'b00_0000);
         dbgOutr[1]              <= (txa_addr == 6'b00_0001);
         dbgOutr[2]              <= (txa_addr == 6'b00_0010);
         dbgOutr[3]              <= (txa_addr == 6'b00_0011);
         dbgOutr[4]              <= tx_stb;

         dbgOutrr                <= dbgOutr;
         dbgOutrrr               <= dbgOutrr;
         dbgOutrrrr              <= dbgOutrrr;
         
         if (drdy) begin
            rx_charr             <= rx_charw;
         end
         
         uart_wr_ctl_stbr        <= uart_wr_ctl_stb;
         if (uart_wr_ctl_stbr == 1'b1) begin
            uart_wr_ctlr         <= uart_wr_ctl;
         end
         
         case (cmdState)
            UART_IDLE: begin
               if (drdy == 1'b0) begin
                  cmdState       <= UART_IDLE;
               end
               else begin
                  snapShot       <= 1'b1;           // Load all status data.
                  cmdState       <= UART_SEND_PROMPT;
              end
            end
            UART_SEND_PROMPT: begin
               tx_char           <= UART_CHAR_GT;
               case (rx_charr)
                  UART_CHAR_UV: begin
                     cmdState    <= UART_GETVER3;
                     tx_load           <= 1'b1;
                  end
                  UART_CHAR_LV: begin
                     cmdState    <= UART_GETVER3;
                     tx_load           <= 1'b1;
                  end
                  UART_CHAR_UR: begin
                     cmdState    <= UART_GETSTAT3;
                     tx_load           <= 1'b1;
                  end
                  UART_CHAR_LR: begin
                    cmdState     <= UART_GETSTAT3;
                     tx_load           <= 1'b1;
                  end
                  UART_CHAR_US: begin
                     cmdState    <= UART_GETARG3;
                     tx_load           <= 1'b1;
                  end
                  UART_CHAR_LS: begin
                    cmdState     <= UART_GETARG3;
                     tx_load           <= 1'b1;
                  end
                  UART_CHAR_UW: begin
                     cmdState    <= UART_SETCTL3;
                  end
                  UART_CHAR_LW: begin
                     cmdState    <= UART_SETCTL3;
                  end
                  UART_CHAR_UX: begin
                     cmdState    <= UART_TEST0;
                     tx_load           <= 1'b1;
                  end
                  UART_CHAR_LX: begin
                     cmdState    <= UART_TEST0;
                     tx_load           <= 1'b1;
                  end
                  UART_CHAR_UC: begin
                     cmdState    <= UART_GETOPC7;
                     tx_load           <= 1'b1;
                  end
                  UART_CHAR_LC: begin
                     cmdState    <= UART_GETOPC7;
                     tx_load           <= 1'b1;
                  end
                  default: begin
                     // Just ignore all other command chars.
                     cmdState    <= UART_BADCHAR;
                  end  // end of default case.
               endcase  // endacse (rx_charr)
            end  // end of UART_PROMPT case.
            UART_GETVER3: begin
               tx_char           <= hex_to_ascii(version_w[15:12]);
               tx_load           <= 1'b1;
               cmdState          <= UART_GETVER2;
            end  // end of UART_GETVER3 case.
            UART_GETVER2: begin
               tx_char           <= hex_to_ascii(version_w[11:8]);
               tx_load           <= 1'b1;
               cmdState          <= UART_GETVER1;
            end  // end of UART_GETVER2 case.
            UART_GETVER1: begin
               tx_char           <= hex_to_ascii(version_w[7:4]);
               tx_load           <= 1'b1;
               cmdState          <= UART_GETVER0;
            end  // end of UART_GETVER1 case.
            UART_GETVER0: begin
               tx_char           <= hex_to_ascii(version_w[3:0]);
               tx_load           <= 1'b1;
               cmdState          <= UART_SEND_CR;
            end  // end of UART_GETVER0 case.
            UART_GETSTAT3: begin
               tx_char           <= hex_to_ascii(uart_rd_stat[15:12]);
               tx_load           <= 1'b1;
               cmdState          <= UART_GETSTAT2;
            end  // end of UART_GETSTAT3 case.
            UART_GETSTAT2: begin
               tx_char           <= hex_to_ascii(uart_rd_stat[11:8]);
               tx_load           <= 1'b1;
               cmdState          <= UART_GETSTAT1;
            end  // end of UART_GETSTAT2 case.
            UART_GETSTAT1: begin
               tx_char           <= hex_to_ascii(uart_rd_stat[7:4]);
               tx_load           <= 1'b1;
               cmdState          <= UART_GETSTAT0;
            end  // end of UART_GETSTAT1 case.
            UART_GETSTAT0: begin
               tx_char           <= hex_to_ascii(uart_rd_stat[3:0]);
               tx_load           <= 1'b1;
               cmdState          <= UART_SEND_CR;
            end  // end of UART_GETSTAT0 case.
            UART_SEND_CR: begin
               tx_char           <= UART_CHAR_CR;
               tx_load           <= 1'b1;
               cmdState          <= UART_SEND_LF;
            end  // end of UART_SEND_CR case.
            UART_SEND_LF: begin
               tx_char           <= UART_CHAR_LF;
               tx_load           <= 1'b1;
               cmdState          <= UART_IDLE;
            end  // end of UART_SEND_LF case.
            UART_SETCTL3: begin
               if (drdy == 1'b0) begin
                  cmdState       <= UART_SETCTL3;
               end
               else begin
                  uart_wr_ctl[15:12] <= ascii_to_hex(rx_charw);
                  cmdState       <= UART_SETCTL2;
               end
            end  // end of case UART_SETCTL3.
            UART_SETCTL2: begin
               if (drdy == 1'b0) begin
                  cmdState       <= UART_SETCTL2;
               end
               else begin
                  uart_wr_ctl[11:8] <= ascii_to_hex(rx_charw);
                  cmdState       <= UART_SETCTL1;
               end
            end  // end of case UART_SETCTL2.
            UART_SETCTL1: begin
               if (drdy == 1'b0) begin
                  cmdState       <= UART_SETCTL1;
               end
               else begin
                  uart_wr_ctl[7:4] <= ascii_to_hex(rx_charw);
                  cmdState       <= UART_SETCTL0;
               end
            end  // end of case UART_SETCTL1.
            UART_SETCTL0: begin
               if (drdy == 1'b0) begin
                  cmdState       <= UART_SETCTL0;
               end
               else begin
                  uart_wr_ctl[3:0] <= ascii_to_hex(rx_charw);
                  uart_wr_ctl_stb <= 1'b1;
                  cmdState       <= UART_SEND_CR;
               end
            end  // end of case UART_SETCTL1.
            UART_BADCHAR: begin
               tx_char           <= UART_CHAR_WTF;
               tx_load           <= 1'b1;
               cmdState          <= UART_SEND_CR;
            end  // end of case UART_SETCTL1.
            UART_TEST0: begin
               tx_char           <= UART_CHAR_OK0;
               tx_load           <= 1'b1;
               cmdState          <= UART_TEST1;
            end  // end of case UART_TEST0.
            UART_TEST1: begin
               tx_char           <= UART_CHAR_OK1;
               tx_load           <= 1'b1;
               cmdState          <= UART_TEST2;
            end  // end of case UART_TEST1.
            UART_TEST2: begin
               tx_char           <= UART_CHAR_OK2;
               tx_load           <= 1'b1;
               cmdState          <= UART_SEND_CR;
            end  // end of case UART_TEST2.
            UART_GETOPC7: begin
               tx_char           <= hex_to_ascii(gp_opc_cnt_i[31:28]);
               tx_load           <= 1'b1;
               cmdState          <= UART_GETOPC6;
            end  // end of UART_GETOPC7 case.
            UART_GETOPC6: begin
               tx_char           <= hex_to_ascii(gp_opc_cnt_i[27:24]);
               tx_load           <= 1'b1;
               cmdState          <= UART_GETOPC5;
            end  // end of UART_GETOPC6 case.
            UART_GETOPC5: begin
               tx_char           <= hex_to_ascii(gp_opc_cnt_i[23:20]);
               tx_load           <= 1'b1;
               cmdState          <= UART_GETOPC4;
            end  // end of UART_GETOPC5 case.
            UART_GETOPC4: begin
               tx_char           <= hex_to_ascii(gp_opc_cnt_i[19:16]);
               tx_load           <= 1'b1;
               cmdState          <= UART_GETOPC3;
            end  // end of UART_GETOPC4 case.
            UART_GETOPC3: begin
               tx_char           <= hex_to_ascii(gp_opc_cnt_i[15:12]);
               tx_load           <= 1'b1;
               cmdState          <= UART_GETOPC2;
            end  // end of UART_GETOPC3 case.
            UART_GETOPC2: begin
               tx_char           <= hex_to_ascii(gp_opc_cnt_i[11:8]);
               tx_load           <= 1'b1;
               cmdState          <= UART_GETOPC1;
            end  // end of UART_GETOPC2 case.
            UART_GETOPC1: begin
               tx_char           <= hex_to_ascii(gp_opc_cnt_i[7:4]);
               tx_load           <= 1'b1;
               cmdState          <= UART_GETOPC0;
            end  // end of UART_GETOPC1 case.
            UART_GETOPC0: begin
               tx_char           <= hex_to_ascii(gp_opc_cnt_i[3:0]);
               tx_load           <= 1'b1;
               cmdState          <= UART_PTNUSC;
            end  // end of UART_GETOPC0 case.
            UART_PTNUSC: begin
               tx_char           <= UART_CHAR_USC;
               tx_load           <= 1'b1;
               cmdState          <= UART_GETPTN3;
            end  // end of UART_PTNSPC case.
            UART_GETPTN7: begin
               tx_char           <= hex_to_ascii(ptn_opc_cnt_i[31:28]);
               tx_load           <= 1'b1;
               cmdState          <= UART_GETPTN6;
            end  // end of UART_GETOPC3 case.
            UART_GETPTN6: begin
               tx_char           <= hex_to_ascii(ptn_opc_cnt_i[27:24]);
               tx_load           <= 1'b1;
               cmdState          <= UART_GETPTN5;
            end  // end of UART_GETOPC2 case.
            UART_GETPTN5: begin
               tx_char           <= hex_to_ascii(ptn_opc_cnt_i[23:20]);
               tx_load           <= 1'b1;
               cmdState          <= UART_GETPTN4;
            end  // end of UART_GETOPC1 case.
            UART_GETPTN4: begin
               tx_char           <= hex_to_ascii(ptn_opc_cnt_i[19:16]);
               tx_load           <= 1'b1;
               cmdState          <= UART_GETPTN4;
            end
            UART_GETPTN3: begin
               tx_char           <= hex_to_ascii(ptn_opc_cnt_i[15:12]);
               tx_load           <= 1'b1;
               cmdState          <= UART_GETPTN2;
            end  // end of UART_GETOPC3 case.
            UART_GETPTN2: begin
               tx_char           <= hex_to_ascii(ptn_opc_cnt_i[11:8]);
               tx_load           <= 1'b1;
               cmdState          <= UART_GETPTN1;
            end  // end of UART_GETOPC2 case.
            UART_GETPTN1: begin
               tx_char           <= hex_to_ascii(ptn_opc_cnt_i[7:4]);
               tx_load           <= 1'b1;
               cmdState          <= UART_GETPTN0;
            end  // end of UART_GETOPC1 case.
            UART_GETPTN0: begin
               tx_char           <= hex_to_ascii(ptn_opc_cnt_i[3:0]);
               tx_load           <= 1'b1;
               cmdState          <= UART_SEND_CR;
            end
            UART_GETARG3: begin
               tx_char           <= hex_to_ascii(sys_stat_vec_i[15:12]);
               tx_load           <= 1'b1;
               cmdState          <= UART_GETARG2;
            end  // end of UART_GETARG3 case.
            UART_GETARG2: begin
               tx_char           <= hex_to_ascii(sys_stat_vec_i[11:8]);
               tx_load           <= 1'b1;
               cmdState          <= UART_GETARG1;
            end  // end of UART_GETARG2 case.
            UART_GETARG1: begin
               tx_char           <= hex_to_ascii(sys_stat_vec_i[7:4]);
               tx_load           <= 1'b1;
               cmdState          <= UART_GETARG0;
            end  // end of UART_GETARG1 case.
            UART_GETARG0: begin
               tx_char           <= hex_to_ascii(sys_stat_vec_i[3:0]);
               tx_load           <= 1'b1;
               cmdState          <= UART_SEND_CR;
            end
            default: begin
               cmdState          <= UART_IDLE;
            end  // end of "default" case.
         endcase  // end of (cmdState).
      end
   end   // end of always @(posedge clk_i).
			
   always @(posedge clk_i) begin
      if (rst_i) begin
         refclkstate             <= 1'b0;
         refclkdiv               <= 7'b0;
      end
      else begin
         if (refclkdiv == 7'b000_0000) begin
            refclkdiv            <= REF_DIV;
            refclkstate          <= ~refclkstate;
         end
         else begin
            refclkdiv            <= refclkdiv - 7'b0000_0001;
         end
      end
   end  // end of always @(posedge clk_i)


   rcvr #(.BAUD_DIV(BAUD_DIV))
   rcv1(                                    // connections to rcvr.v
       .rxd(RxD_i),                         // RX serial input
       .clk(clk_i),                         // 100MHz clock
       .rst(rst_i),                         // 
       .baudx(baudxw),
       .do(rx_charw),                       // RX data
       .drdy(drdy)                          // data ready
      );

   xmtr #(.BAUD_DIV(BAUD_DIV))
   xmt1(                                    // connections to xmtr.v
       .tbre(tbre),                         // transmit buffer empty
       .txd(TxD_o),                         // serial TX out
       .din(tx_din),                        // TX data in
       .rst(rst_i),                         // 
       .clk(clk_i),                         // 100MHz clock
       .tx_stb(tx_stb)                      // single-clock TX strobe
    );

   // convert hex digit to ASCII character
   function [7:0] hex_to_ascii;
      input [3:0] hex_val;
      begin
         if (hex_val > 8'h09)
            hex_to_ascii =  "a" + (hex_val - 8'h0a);
         else
            hex_to_ascii =  "0" + hex_val;
      end
   endfunction

   // convert ASCII character [0-9a-fA-F] to hex
   function [3:0] ascii_to_hex;
      input [7:0] char_val;
      begin
         if (char_val[7:4] == 4'h3)
            ascii_to_hex = char_val[3:0];
         else 
            case (char_val[3:0])
               4'h1: ascii_to_hex = 4'ha;
               4'h2: ascii_to_hex = 4'hb;
               4'h3: ascii_to_hex = 4'hc;
               4'h4: ascii_to_hex = 4'hd;
               4'h5: ascii_to_hex = 4'he;
               4'h6: ascii_to_hex = 4'hf;
               default: ascii_to_hex = 4'hx;
            endcase
      end    
   endfunction


   assign  version_w   = VRSN;

   assign  hw_ctl_o    = uart_wr_ctlr;
   assign  refclk_o    = refclkstate;
   assign  dbg_o       = baudxw;

endmodule
