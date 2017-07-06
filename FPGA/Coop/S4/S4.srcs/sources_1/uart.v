//----------------------------------------------------------------------------------
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
// ---------------------------------------------------------------------------------
// File name:  uart.v
// Project:    s4x7
// Author:     Roger Williams <roger.williams@ampleon.com> (RAW)
// Purpose:    Diag/debug access to s4x7 FPGA "backside" internals.
// ---------------------------------------------------------------------------------
// 0.00.1  2016-08-04 (JLC) Modified for current project.
// 0.00.2  2017-04-11 (JLC) Modified for s4 backside.
// 0.00.3  2017-06-13 (JLC) Expanded ctl/stat widths to 8 addressable 32-bit words
//
//----------------------------------------------------------------------------------


module uart #( parameter VRSN      = 16'h9876, CLK_FREQ  = 100000000, BAUD = 115200)
  (
    // infrastructure, etc.
    input                 clk_i,            // 
    input                 rst_i,            // 
    input                 rx_enbl,          // 
    input                 RxD_i,            // "RxD" from USB serial bridge to FPGA
    output                TxD_o,            // "TxD" from FPGA to USB serial bridge
    output                dbg0_o,           // Utility debug output #0.
    output                dbg1_o,           // Utility debug output #1.
    output                dbg2_o,           // Utility debug output #2.
    
    // diag/debug control signal outputs
    output      [255:0]   hw_ctl_o,
    output                auto_fifo_wr_stb_o,
    output      [3:0]     auto_fifo_wr_addr_o,
     
    // diag/debug status  signal inputs
    input       [255:0]   hw_stat_i,
    input       [31:0]    gp_opc_cnt_i,     // count of opcodes processed from top level
    input       [31:0]    ptn_opc_cnt_i,    // count of pattern opcodes processed from top level
    input       [15:0]    sys_stat_vec_i    // 16-bit status to show, system_state for now
  );

   // Freq Gen Info
   localparam  BAUD_DIV           = CLK_FREQ / BAUD - 1;

   // UART state machine state declarations (probably should be mutable as macros):
   localparam  UART_IDLE          = 8'b0000_0000;    // UART_IDLE is the reset and resting state.
   localparam  UART_WAIT_PROMPT   = 8'b0000_0001;
   localparam  UART_SEND_CR       = 8'b0000_0010;
   localparam  UART_SEND_LF       = 8'b0000_0011;
   localparam  UART_BADCHAR       = 8'b0000_0100;    // UART_BADCHAR  is an error state.
   localparam  UART_BADSTATE      = 8'b0000_0101;    // UART_BADSTATE is an error state.
   localparam  UART_TEST0         = 8'b0000_1000;    // UART_TEST* receives [x|X] and returns "OK!"
   localparam  UART_TEST1         = 8'b0000_1001;
   localparam  UART_TEST2         = 8'b0000_1010;
   localparam  UART_GETSTAT0      = 8'b0001_0000;    // UART_SETCTL* retrieves 1-of-8 32bit dbg status regs
   localparam  UART_GETSTAT1      = 8'b0001_0001;    //     [0:7] specified by UART_GETADDR.
   localparam  UART_GETSTAT2      = 8'b0001_0010;
   localparam  UART_GETSTAT3      = 8'b0001_0011;
   localparam  UART_GETSTAT4      = 8'b0001_0100;
   localparam  UART_GETSTAT5      = 8'b0001_0101;
   localparam  UART_GETSTAT6      = 8'b0001_0110;
   localparam  UART_GETSTAT7      = 8'b0001_0111;
   localparam  UART_GETADDR       = 8'b0001_1000;    // UART_GETADDR selects 1-of-8 [0:7] 32bit dbg status regs.
   localparam  UART_GETDLM        = 8'b0001_1001;    // UART_GETDLM receives the delimiter [\b|:].
   localparam  UART_SETCTL0       = 8'b0010_0000;    // UART_SETCTL* writes 1-of-8 32bit control regs
   localparam  UART_SETCTL1       = 8'b0010_0001;    //     [0:7] specified by UART_SETADDR.
   localparam  UART_SETCTL2       = 8'b0010_0010;
   localparam  UART_SETCTL3       = 8'b0010_0011;
   localparam  UART_SETCTL4       = 8'b0010_0100;
   localparam  UART_SETCTL5       = 8'b0010_0101;
   localparam  UART_SETCTL6       = 8'b0010_0110;
   localparam  UART_SETCTL7       = 8'b0010_0111;
   localparam  UART_SETADDR       = 8'b0010_1000;    // UART_SETADDR selects 1-of-8 [0:7] 32bit control regs.
   localparam  UART_SETDLM        = 8'b0010_1001;    // UART_SETDLM  sends a ':' for formatting
   localparam  UART_GETOPC0       = 8'b0011_0000;    // UART_GETOPC* retieves RMR's 32bit "opcode count".
   localparam  UART_GETOPC1       = 8'b0011_0001;
   localparam  UART_GETOPC2       = 8'b0011_0010;
   localparam  UART_GETOPC3       = 8'b0011_0011;
   localparam  UART_GETOPC4       = 8'b0011_0100;
   localparam  UART_GETOPC5       = 8'b0011_0101;
   localparam  UART_GETOPC6       = 8'b0011_0110;
   localparam  UART_GETOPC7       = 8'b0011_0111;
   localparam  UART_PTNUSC        = 8'b0000_1011;    // UART_PTNUSC puts a '_' between opcode & pattern counts.
   localparam  UART_GETPTN0       = 8'b0011_1000;    // UART_GETPTN* retieves RMR's 32bit "pattern count".
   localparam  UART_GETPTN1       = 8'b0011_1001;
   localparam  UART_GETPTN2       = 8'b0011_1010;
   localparam  UART_GETPTN3       = 8'b0011_1011;
   localparam  UART_GETPTN4       = 8'b0011_1100;
   localparam  UART_GETPTN5       = 8'b0011_1101;
   localparam  UART_GETPTN6       = 8'b0011_1110;
   localparam  UART_GETPTN7       = 8'b0011_1111;
   localparam  UART_GETARG3       = 8'b0100_0000;    // UART_GETARG* retrieves RMR's 16bit "Status".
   localparam  UART_GETARG2       = 8'b0100_0001;
   localparam  UART_GETARG1       = 8'b0100_0010;
   localparam  UART_GETARG0       = 8'b0100_0011;
   localparam  UART_GETVER0       = 8'b0101_0000;    // UART_GETVER* retrieves the 16bit FPGA version #.
   localparam  UART_GETVER1       = 8'b0101_0001;
   localparam  UART_GETVER2       = 8'b0101_0010;
   localparam  UART_GETVER3       = 8'b0101_0011;
   localparam  UART_SETAWR0       = 8'b0110_0000;    // UART_SETAWR* enables or disables  auto-writes (to FIFO) for 1-of-8 [0:7] destination FIFOs.
   localparam  UART_SETAWR1       = 8'b0110_0000;
   
  
   // ASCII Char Codes
   localparam  UART_CHAR_CR       = 8'h0d;    // CR                             NOTE:  btn[3] is used as reset!
   localparam  UART_CHAR_LF       = 8'h0a;    // LF
   localparam  UART_CHAR_GT       = 8'h3e;    // '>'
   localparam  UART_CHAR_WTF      = 8'h3f;    // '?'
   localparam  UART_CHAR_SNAFU    = 8'h21;    // '@'
   localparam  UART_CHAR_USC      = 8'h5f;    // _
   localparam  UART_CHAR_SP       = 8'h20;    // SP (space)
   localparam  UART_CHAR_UA       = 8'h41;    // 'A' | 'a':  Set AutoWrite
   localparam  UART_CHAR_LA       = 8'h61;
   localparam  UART_CHAR_UV       = 8'h56;    // 'V' | 'v':  Get Version
   localparam  UART_CHAR_LV       = 8'h76;
   localparam  UART_CHAR_UR       = 8'h52;    // 'R' | 'r':  Read Diag Data
   localparam  UART_CHAR_LR       = 8'h72;
   localparam  UART_CHAR_UB       = 8'h42;    // 'B' | 'b':  
   localparam  UART_CHAR_LB       = 8'h62;
   localparam  UART_CHAR_UL       = 8'h4C;    // 'L' | 'l':  
   localparam  UART_CHAR_LL       = 8'h6C;
   localparam  UART_CHAR_UW       = 8'h57;    // 'W' | 'w':  Write Diag Data
   localparam  UART_CHAR_LW       = 8'h77;
   localparam  UART_CHAR_UX       = 8'h58;    // 'X' | 'x':  No-Op               (just a test)
   localparam  UART_CHAR_LX       = 8'h78;
   localparam  UART_CHAR_UC       = 8'h43;    // 'C' | 'c':  Show count of opcodes_Underscore_countOfPatternOpcodes
   localparam  UART_CHAR_LC       = 8'h63;
   localparam  UART_CHAR_US       = 8'h53;    // 'S' | 's':  Show 16-bit instance arg data
   localparam  UART_CHAR_LS       = 8'h73;
   localparam  UART_CHAR_OK0      = 8'h4F;    // 'O'
   localparam  UART_CHAR_OK1      = 8'h4B;    // 'K'
   localparam  UART_CHAR_OK2      = 8'h21;    // '!'
   localparam  UART_CHAR_CLN      = 8'h3A;    // ':'
   localparam  UART_CHAR_PLUS     = 8'h2B;    // '+'
   localparam  UART_CHAR_MINUS    = 8'h2D;    // '-'
   

   reg  [31:0]            uart_rd_stat [7:0];
   reg  [3:0]             uart_csr_addr      = 4'h0; 
   reg  [31:0]            uart_wr_ctl  [7:0];
   reg  [255:0]           uart_wr_ctlr       = 256'b0;
   reg                    uart_wr_ctl_stb    = 1'b0;
   reg                    uart_wr_ctl_stbr   = 1'b0;
   wire                   uart_wr_ctl_stbw   = uart_wr_ctl_stbr & ~uart_wr_ctl_stb;

   reg                    auto_fifo_wr_stb   = 1'b0;   
   reg                    auto_fifo_wr_stbr  = 1'b0;   
   reg                    auto_fifo_wr_stbrr = 1'b0;   
   reg                    auto_fifo_wr_mode  = 1'b0;
   reg  [3:0]             auto_fifo_wr_addr  = 4'h0;

   reg  [7:0]             tx_char            = 8'b0;
   reg  [7:0]             rx_charr           = 8'b0;
   wire                   drdy;             // UART rcvr has valid rcv'd char
   wire [7:0] 		      rx_charw;
   
   // serial TX FIFO
   reg  [7:0]             tx_fifo [63:0];   // actual tx FIFO array
   reg  [7:0]             tx_din = 8'b0;    // tx FIFO input data
   reg  [5:0]             txa_addr = 6'b0;  // tx FIFO write addr
   reg  [5:0]             txb_addr = 6'b0;  // tx FIFO read  addr
   reg                    tx_load = 1'b0;
   wire                   tbre;             // UART xmtr is ready for another char
   reg                    tx_stb1 = 1'b0;
   reg                    tx_stb2 = 1'b0;

   wire                   tx_stb  = tx_stb1 & ~tx_stb2;

   wire [15:0]            version_w;
   
   wire                   rxdbg0w;
   wire                   rxdbg1w;
   wire                   txdbg0w;
   wire                   txdbg1w;
   reg                    dbg0r;
   reg                    dbg1r;
   reg                    dbg2r;
   
   // Serial TX FIFO
   always @(posedge clk_i) begin
      if (rst_i) begin
         txa_addr <= 0;
         txb_addr <= 0;
         tx_stb1 <= 0;
         tx_stb2 <= 0;
      end
      else begin
         if (tx_load) begin
            tx_fifo[txa_addr] <= tx_char;
            txa_addr <= txa_addr + 1;
         end
         tx_din <= tx_fifo[txb_addr];
         tx_stb1 <= (tbre && (txa_addr != txb_addr));
         tx_stb2 <= tx_stb1;
         if (tx_stb)
            txb_addr <= txb_addr + 1;
      end
   end  // end of always @(posedge CLK)
   // end of Serial TX FIFO

   
   // UART Rx Command Parsing State Machine
   reg  [7:0] 		cmdState     = UART_IDLE;
   reg  [7:0] 		cmdStater    = UART_IDLE;
   reg              rdStatStb    = 1'b0;

   // Capture data for R (read state) & S commands.   
   always @(posedge clk_i) begin
      if (rst_i) begin
         uart_rd_stat[7]         <= 32'b0;
         uart_rd_stat[6]         <= 32'b0;
         uart_rd_stat[5]         <= 32'b0;
         uart_rd_stat[4]         <= 32'b0;
         uart_rd_stat[3]         <= 32'b0;
         uart_rd_stat[2]         <= 32'b0;
         uart_rd_stat[1]         <= 32'b0;
         uart_rd_stat[0]         <= 32'b0;
      end
      else begin
         if (rdStatStb == 1'b1) begin
            uart_rd_stat[7]      <= hw_stat_i[255:224];
            uart_rd_stat[6]      <= hw_stat_i[223:192];
            uart_rd_stat[5]      <= hw_stat_i[191:160];
            uart_rd_stat[4]      <= hw_stat_i[159:128];
            uart_rd_stat[3]      <= hw_stat_i[127: 96];
            uart_rd_stat[2]      <= hw_stat_i[ 95: 64];
            uart_rd_stat[1]      <= hw_stat_i[ 63: 32];
            uart_rd_stat[0]      <= hw_stat_i[ 32:  0];
         end
      end
   end  // end of always @ (posedge clk).

   // Command State Machine
   always @(posedge clk_i) begin
      if (rst_i) begin
         cmdState                <= UART_IDLE;
         cmdStater               <= UART_IDLE;
         rx_charr                <= 8'b0;
         tx_char                 <= 8'b0;
         tx_load                 <= 1'b0;
         dbg0r                   <= 1'b0;
         dbg1r                   <= 1'b0;
         dbg2r                   <= 1'b0;
         rdStatStb               <= 1'b0;
         uart_wr_ctl[0]          <= 32'h0000;
         uart_wr_ctl[1]          <= 32'h0000;
         uart_wr_ctl[2]          <= 32'h0000;
         uart_wr_ctl[3]          <= 32'h0000;
         uart_wr_ctl[4]          <= 32'h0000;
         uart_wr_ctl[5]          <= 32'h0000;
         uart_wr_ctl[6]          <= 32'h0000;
         uart_wr_ctl[7]          <= 32'h0000;
         uart_wr_ctlr            <= 256'b0;
         uart_wr_ctl_stb         <= 1'b0;          // 1-tick strobe for writing control data.
         uart_wr_ctl_stbr        <= 1'b0;          // 1-tick strobe for writing control data (delayed 1-tick).
         auto_fifo_wr_mode       <= 1'b0;
         auto_fifo_wr_addr       <= 4'hF;
         auto_fifo_wr_stb        <= 1'b0;
         auto_fifo_wr_stbr       <= 1'b0;
         auto_fifo_wr_stbrr      <= 1'b0;
         end
      else begin
         // clears for one-tick signals
         rdStatStb               <= 1'b0;
	     rx_charr                <= 1'b0;
	     tx_load                 <= 1'b0;
	     dbg0r                   <= 1'b0;
         uart_wr_ctl_stb         <= 1'b0;
         uart_wr_ctl_stbr        <= uart_wr_ctl_stb;
         auto_fifo_wr_stb        <= 1'b0;
         auto_fifo_wr_stbr       <= auto_fifo_wr_stb;
         auto_fifo_wr_stbrr      <= auto_fifo_wr_stbr;
         if (uart_wr_ctl_stbw == 1'b1) begin
            uart_wr_ctlr         <= {uart_wr_ctl[7],uart_wr_ctl[6],uart_wr_ctl[5],uart_wr_ctl[4],
                                     uart_wr_ctl[3],uart_wr_ctl[2],uart_wr_ctl[1],uart_wr_ctl[0]};
         end
         
   
         // "every-time" assignments
         cmdStater                  <= cmdState;
         
         dbg1r                      <= rxdbg0w;
         dbg2r                      <= rxdbg1w;

         rx_charr                   <= rx_charw;         

         case (cmdState)
            UART_IDLE: begin
               tx_char              <= UART_CHAR_GT;
               tx_load              <= 1'b1;
               cmdState             <= UART_WAIT_PROMPT;
               dbg0r                <= 1'b1;
            end  // End of case UART_SEND_PROMPT
            UART_WAIT_PROMPT: begin
               rdStatStb            <= 1'b1;              // Load all status data.
               if (drdy == 1'b0) begin
                  cmdState          <= UART_WAIT_PROMPT;
               end
               else begin
                  case (rx_charw)
                     UART_CHAR_UV: begin
                        cmdState    <= UART_GETVER3;
                     end
                     UART_CHAR_LV: begin
                        cmdState    <= UART_GETVER3;
                     end
                     UART_CHAR_UR: begin
                        cmdState    <= UART_GETADDR;
                     end
                     UART_CHAR_LR: begin
                        cmdState    <= UART_GETADDR;
                     end
                     UART_CHAR_US: begin
                        cmdState    <= UART_GETARG3;
                     end
                     UART_CHAR_LS: begin
                        cmdState    <= UART_GETARG3;
                     end
                     UART_CHAR_UW: begin
                        cmdState    <= UART_SETADDR;
                     end
                     UART_CHAR_LW: begin
                        cmdState    <= UART_SETADDR;
                     end
                     UART_CHAR_UX: begin
                        cmdState    <= UART_TEST0;
                     end
                     UART_CHAR_LX: begin
                        cmdState    <= UART_TEST0;
                     end
                     UART_CHAR_UC: begin
                        cmdState    <= UART_GETOPC7;
                     end
                     UART_CHAR_LC: begin
                        cmdState    <= UART_GETOPC7;
                     end
                     UART_CHAR_UA: begin
                        cmdState    <= UART_SETAWR0;
                     end
                     UART_CHAR_LA: begin
                        cmdState    <= UART_SETAWR0;
                     end
                     default: begin
                        // Just ignore all other command chars.
                        cmdState    <= UART_BADCHAR;
                     end  // end of default case.
                  endcase  // endacse (rx_charr)
               end
            end  // end of UART_PROMPT case.
            UART_GETVER3: begin
               tx_char              <= hex_to_ascii(version_w[15:12]);
               tx_load              <= 1'b1;
               cmdState             <= UART_GETVER2;
            end  // end of UART_GETVER3 case.
            UART_GETVER2: begin
               tx_char              <= hex_to_ascii(version_w[11:8]);
               tx_load              <= 1'b1;
               cmdState             <= UART_GETVER1;
            end  // end of UART_GETVER2 case.
            UART_GETVER1: begin
               tx_char              <= hex_to_ascii(version_w[7:4]);
               tx_load              <= 1'b1;
               cmdState             <= UART_GETVER0;
            end  // end of UART_GETVER1 case.
            UART_GETVER0: begin
               tx_char              <= hex_to_ascii(version_w[3:0]);
               tx_load              <= 1'b1;
               cmdState             <= UART_SEND_CR;
            end  // end of UART_GETVER0 case.
            UART_GETADDR: begin
               if (drdy == 1'b0) begin
                  cmdState          <= UART_GETADDR;
               end
               else begin
                  uart_csr_addr     <= ascii_to_hex(rx_charw);
                  if (rx_charw[7:3] == 5'b0011_0)
                  begin
                     cmdState       <= UART_GETDLM;
                  end
                  else
                  begin
                     cmdState       <= UART_BADCHAR;
                  end
               end
            end  // end of UART_GETADDR case.
            UART_GETDLM: begin
               tx_char              <= UART_CHAR_CLN;
               tx_load              <= 1'b1;
               cmdState             <= UART_GETSTAT7;
            end  // end of UART_GETDLM case.
            UART_GETSTAT7: begin
               tx_char              <= hex_to_ascii(uart_rd_stat[uart_csr_addr][31:28]);
               tx_load              <= 1'b1;
               cmdState             <= UART_GETSTAT6;
            end  // end of UART_GETSTAT7 case.
            UART_GETSTAT6: begin
               tx_char              <= hex_to_ascii(uart_rd_stat[uart_csr_addr][27:24]);
               tx_load              <= 1'b1;
               cmdState             <= UART_GETSTAT5;
            end  // end of UART_GETSTAT6 case.
            UART_GETSTAT5: begin
               tx_char              <= hex_to_ascii(uart_rd_stat[uart_csr_addr][23:20]);
               tx_load              <= 1'b1;
               cmdState             <= UART_GETSTAT4;
            end  // end of UART_GETSTAT5 case.
            UART_GETSTAT4: begin
               tx_char              <= hex_to_ascii(uart_rd_stat[uart_csr_addr][19:16]);
               tx_load              <= 1'b1;
               cmdState             <= UART_GETSTAT3;
            end  // end of UART_GETSTAT4 case.
            UART_GETSTAT3: begin
               tx_char              <= hex_to_ascii(uart_rd_stat[uart_csr_addr][15:12]);
               tx_load              <= 1'b1;
               cmdState             <= UART_GETSTAT2;
            end  // end of UART_GETSTAT3 case.
            UART_GETSTAT2: begin
               tx_char              <= hex_to_ascii(uart_rd_stat[uart_csr_addr][11: 8]);
               tx_load              <= 1'b1;
               cmdState             <= UART_GETSTAT1;
            end  // end of UART_GETSTAT2 case.
            UART_GETSTAT1: begin
               tx_char              <= hex_to_ascii(uart_rd_stat[uart_csr_addr][ 7: 4]);
               tx_load              <= 1'b1;
               cmdState             <= UART_GETSTAT0;
            end  // end of UART_GETSTAT1 case.
            UART_GETSTAT0: begin
               tx_char              <= hex_to_ascii(uart_rd_stat[uart_csr_addr][ 3: 0]);
               tx_load              <= 1'b1;
               cmdState             <= UART_SEND_CR;
            end  // end of UART_GETSTAT0 case.
            UART_SETADDR: begin
               if (drdy == 1'b0) begin
                  cmdState          <= UART_SETADDR;
               end
               else begin
                  uart_csr_addr <= ascii_to_hex(rx_charw);
                  if (rx_charw[7:3] == 5'b0011_0)
                  begin
                     cmdState       <= UART_SETDLM;
                  end
                  else
                  begin
                     cmdState       <= UART_BADCHAR;
                  end
               end
            end  // end of UART_SETADDR case.
            UART_SETDLM: begin
               if (drdy == 1'b0) begin
                  cmdState          <= UART_SETDLM;
               end
               else begin
                  if ((rx_charw == UART_CHAR_CLN) || (rx_charw == UART_CHAR_SP))
                  begin
                     cmdState       <= UART_SETCTL7;
                  end
                  else
                  begin
                     cmdState       <= UART_BADCHAR;
                  end
               end
            end  // end of UART_SETDLM case.
            UART_SETCTL7: begin
               if (drdy == 1'b0) begin
                  cmdState          <= UART_SETCTL7;
               end
               else begin
                  uart_wr_ctl[uart_csr_addr][31:28] <= ascii_to_hex(rx_charw);
                  cmdState          <= UART_SETCTL6;
               end
            end  // end of case UART_SETCTL7.
            UART_SETCTL6: begin
               if (drdy == 1'b0) begin
                  cmdState          <= UART_SETCTL6;
               end
               else begin
                  uart_wr_ctl[uart_csr_addr][27:24] <= ascii_to_hex(rx_charw);
                  cmdState          <= UART_SETCTL5;
               end
            end  // end of case UART_SETCTL6.
            UART_SETCTL5: begin
               if (drdy == 1'b0) begin
                  cmdState          <= UART_SETCTL5;
               end
               else begin
                  uart_wr_ctl[uart_csr_addr][23:20] <= ascii_to_hex(rx_charw);
                  cmdState          <= UART_SETCTL4;
               end
            end  // end of case UART_SETCTL5.
            UART_SETCTL4: begin
               if (drdy == 1'b0) begin
                  cmdState          <= UART_SETCTL4;
               end
               else begin
                  uart_wr_ctl[uart_csr_addr][19:16] <= ascii_to_hex(rx_charw);
                  cmdState          <= UART_SETCTL3;
               end
            end  // end of case UART_SETCTL4.
            UART_SETCTL3: begin
               if (drdy == 1'b0) begin
                  cmdState          <= UART_SETCTL3;
               end
               else begin
                  uart_wr_ctl[uart_csr_addr][15:12] <= ascii_to_hex(rx_charw);
                  cmdState          <= UART_SETCTL2;
               end
            end  // end of case UART_SETCTL3.
            UART_SETCTL2: begin
               if (drdy == 1'b0) begin
                  cmdState          <= UART_SETCTL2;
               end
               else begin
                  uart_wr_ctl[uart_csr_addr][11: 8] <= ascii_to_hex(rx_charw);
                  cmdState          <= UART_SETCTL1;
               end
            end  // end of case UART_SETCTL2.
            UART_SETCTL1: begin
               if (drdy == 1'b0) begin
                  cmdState          <= UART_SETCTL1;
               end
               else begin
                  uart_wr_ctl[uart_csr_addr][ 7: 4] <= ascii_to_hex(rx_charw);
                  cmdState          <= UART_SETCTL0;
               end
            end  // end of case UART_SETCTL1.
            UART_SETCTL0: begin
               if (drdy == 1'b0) begin
                  cmdState          <= UART_SETCTL0;
               end
               else begin
                  uart_wr_ctl[uart_csr_addr][ 3: 0] <= ascii_to_hex(rx_charw);
                  uart_wr_ctl_stb   <= 1'b1;
                  if ((uart_csr_addr[ 3: 0] == auto_fifo_wr_addr) && (auto_fifo_wr_mode == 1'b1)) begin
                     auto_fifo_wr_stb  <= 1'b1;
                  end
                  cmdState          <= UART_SEND_CR;
               end
            end  // end of case UART_SETCTL0.
            UART_GETOPC7: begin
               tx_char              <= hex_to_ascii(gp_opc_cnt_i[31:28]);
               tx_load              <= 1'b1;
               cmdState             <= UART_GETOPC6;
            end  // end of UART_GETOPC7 case.
            UART_GETOPC6: begin
               tx_char              <= hex_to_ascii(gp_opc_cnt_i[27:24]);
               tx_load              <= 1'b1;
               cmdState             <= UART_GETOPC5;
            end  // end of UART_GETOPC6 case.
            UART_GETOPC5: begin
               tx_char              <= hex_to_ascii(gp_opc_cnt_i[23:20]);
               tx_load              <= 1'b1;
               cmdState             <= UART_GETOPC4;
            end  // end of UART_GETOPC5 case.
            UART_GETOPC4: begin
               tx_char              <= hex_to_ascii(gp_opc_cnt_i[19:16]);
               tx_load              <= 1'b1;
               cmdState             <= UART_GETOPC3;
            end  // end of UART_GETOPC4 case.
            UART_GETOPC3: begin
               tx_char              <= hex_to_ascii(gp_opc_cnt_i[15:12]);
               tx_load              <= 1'b1;
               cmdState             <= UART_GETOPC2;
            end  // end of UART_GETOPC3 case.
            UART_GETOPC2: begin
               tx_char              <= hex_to_ascii(gp_opc_cnt_i[11:8]);
               tx_load              <= 1'b1;
               cmdState             <= UART_GETOPC1;
            end  // end of UART_GETOPC2 case.
            UART_GETOPC1: begin
               tx_char              <= hex_to_ascii(gp_opc_cnt_i[7:4]);
               tx_load              <= 1'b1;
               cmdState             <= UART_GETOPC0;
            end  // end of UART_GETOPC1 case.
            UART_GETOPC0: begin
               tx_char              <= hex_to_ascii(gp_opc_cnt_i[3:0]);
               tx_load              <= 1'b1;
               cmdState             <= UART_PTNUSC;
            end  // end of UART_GETOPC0 case.
            UART_PTNUSC: begin
               tx_char              <= UART_CHAR_USC;
               tx_load              <= 1'b1;
               cmdState             <= UART_GETPTN7;
            end  // end of UART_PTNUSC case.
            UART_GETPTN7: begin
               tx_char              <= hex_to_ascii(ptn_opc_cnt_i[31:28]);
               tx_load              <= 1'b1;
               cmdState             <= UART_GETPTN6;
            end  // end of UART_GETOPC7 case.
            UART_GETPTN6: begin
               tx_char              <= hex_to_ascii(ptn_opc_cnt_i[27:24]);
               tx_load              <= 1'b1;
               cmdState             <= UART_GETPTN5;
            end  // end of UART_GETOPC6 case.
            UART_GETPTN5: begin
               tx_char              <= hex_to_ascii(ptn_opc_cnt_i[23:20]);
               tx_load              <= 1'b1;
               cmdState             <= UART_GETPTN4;
            end  // end of UART_GETOPC5 case.
            UART_GETPTN4: begin
               tx_char              <= hex_to_ascii(ptn_opc_cnt_i[19:16]);
               tx_load              <= 1'b1;
               cmdState             <= UART_GETPTN3;
            end  // end of UART_GETOPC4 case.
            UART_GETPTN3: begin
               tx_char              <= hex_to_ascii(ptn_opc_cnt_i[15:12]);
               tx_load              <= 1'b1;
               cmdState             <= UART_GETPTN2;
            end  // end of UART_GETOPC3 case.
            UART_GETPTN2: begin
               tx_char              <= hex_to_ascii(ptn_opc_cnt_i[11:8]);
               tx_load              <= 1'b1;
               cmdState             <= UART_GETPTN1;
            end  // end of UART_GETOPC2 case.
            UART_GETPTN1: begin
               tx_char              <= hex_to_ascii(ptn_opc_cnt_i[7:4]);
               tx_load              <= 1'b1;
               cmdState             <= UART_GETPTN0;
            end  // end of UART_GETOPC1 case.
            UART_GETPTN0: begin
               tx_char              <= hex_to_ascii(ptn_opc_cnt_i[3:0]);
               tx_load              <= 1'b1;
               cmdState             <= UART_SEND_CR;
            end
            UART_GETARG3: begin
               tx_char              <= hex_to_ascii(sys_stat_vec_i[15:12]);
               tx_load              <= 1'b1;
               cmdState             <= UART_GETARG2;
            end  // end of UART_GETARG3 case.
            UART_GETARG2: begin
               tx_char              <= hex_to_ascii(sys_stat_vec_i[11:8]);
               tx_load              <= 1'b1;
               cmdState             <= UART_GETARG1;
            end  // end of UART_GETARG2 case.
            UART_GETARG1: begin
               tx_char              <= hex_to_ascii(sys_stat_vec_i[7:4]);
               tx_load              <= 1'b1;
               cmdState             <= UART_GETARG0;
            end  // end of UART_GETARG1 case.
            UART_GETARG0: begin
               tx_char              <= hex_to_ascii(sys_stat_vec_i[3:0]);
               tx_load              <= 1'b1;
               cmdState             <= UART_SEND_CR;
            end
            UART_SETAWR0: begin
               if (drdy == 1'b0) begin
                  cmdState          <= UART_SETAWR0;
               end
               else begin
                  case (rx_charw)
                     UART_CHAR_PLUS: begin
                        auto_fifo_wr_mode <= 1'b0;
                        cmdState    <= UART_SEND_CR;
                     end
                     UART_CHAR_MINUS: begin
                        auto_fifo_wr_mode <= 1'b1;
                        cmdState    <= UART_SETAWR1;
                     end
                     default: begin
                        cmdState    <= UART_BADCHAR;
                     end
                  endcase  // end of case (rx_charw)
               end
            end  // end of case UART_SETAWR0.
            UART_SETAWR1: begin
               if (drdy == 1'b0) begin
                  cmdState          <= UART_SETAWR1;
               end
               else begin
                  auto_fifo_wr_addr <= ascii_to_hex(rx_charw);
                  cmdState          <= UART_SEND_CR;
               end
            end  // end of case UART_SETAWR1.
            UART_TEST0: begin
               tx_char              <= UART_CHAR_OK0;
               tx_load              <= 1'b1;
               cmdState             <= UART_TEST1;
            end  // end of UART_TEST0 case.
            UART_TEST1: begin
               tx_char              <= UART_CHAR_OK1;
               tx_load              <= 1'b1;
               cmdState             <= UART_TEST1;
            end  // end of UART_TEST1 case.
            UART_TEST2: begin
               tx_char              <= UART_CHAR_OK2;
               tx_load              <= 1'b1;
               cmdState             <= UART_SEND_CR;
            end  // end of UART_TEST2 case.
            UART_SEND_CR: begin
               tx_char              <= UART_CHAR_CR;
               tx_load              <= 1'b1;
               cmdState             <= UART_SEND_LF;
            end  // end of UART_SEND_CR case.
            UART_SEND_LF: begin
               tx_char              <= UART_CHAR_LF;
               tx_load              <= 1'b1;
               cmdState             <= UART_IDLE;
            end  // end of UART_SEND_LF case.
            default: begin
               // put bad state debug/error code here
               cmdState             <= UART_IDLE;
            end
         endcase  // end of (cmdState).
      end
   end   // end of always @(posedge clk_i).
			

   rcvr #(.BAUD_DIV(BAUD_DIV))
   rcv1(                                    // connections to rcvr.v
       .rxd(RxD_i),                         // RX serial input
       .clk(clk_i),                         // 100MHz clock
       .rst(rst_i),                         // 
       .rx_enbl(rx_enbl),                   // 
       .dorx(rx_charw),                     // RX data
       .drdy(drdy),                         // data ready
       .rxdbg1(rxdbg1w),
       .rxdbg0(rxdbg0w)
      );

   xmtr #(.BAUD_DIV(BAUD_DIV))
   xmt1(                                    // connections to xmtr.v
       .tbre(tbre),                         // transmit buffer empty
       .txd(TxD_o),                         // serial TX out
       .din(tx_din),                        // TX data in
       .tx_stb(tx_stb),                     // TX data strobe.
       .rst(rst_i),                         // 
       .clk(clk_i)                          // 100MHz clock
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


   assign  version_w              = VRSN;

   assign  hw_ctl_o               = uart_wr_ctlr;
   assign  auto_fifo_wr_stb_o     = auto_fifo_wr_stbr & ~auto_fifo_wr_stbrr;
   assign  auto_fifo_wr_addr_o    = auto_fifo_wr_addr;
   assign  dbg0_o                 = txdbg0w;
   assign  dbg1_o                 = tx_stb;
   assign  dbg2_o                 = tbre;

endmodule
