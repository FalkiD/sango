//----------------------------------------------------------------------------------
// (C) Copyright 2017, Ampleon Inc.
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
// File name:  dds.v
// Project:    s4x7
// Author:     Jeff Cooper, aa1ww.coop@gmail.com (JLC)
// Purpose:    Hardware interface to AD9954 DDS chip.
// ---------------------------------------------------------------------------------
// AD9954 Application Summary:
//     Single-Tone Mode, RefClk(~100MHz) x 4, SPI w/MSB-1st,
//     dds_MOSI change on falling edge of dds_SCLK.
//
//
// ---------------------------------------------------------------------------------
// 0.00.1  2017-06-30 (JLC) Created.
//
//
//----------------------------------------------------------------------------------

`include "timescale.v"        // Every source file needs this include


module dds_spi #( parameter VRSN      = 16'habcd, CLK_FREQ  = 100000000, SPI_CLK_FREQ=25000000)
  (
    // infrastructure, etc.
    input                  clk_i,                    // 
    input                  rst_i,                    // 
    input                  doInit_i,                 // do an init sequence. 
    output                 dds_initd_o,              // initialization done.
    input        [35:0]    hwdbg_dat_i,              // hwdbg data input.
    input                  hwdbg_we_i,               // hwdbg we.
    input        [31:0]    freqproc_dat_i,           // opcproc data input.
    input                  freqproc_we_i,            // opcproc we.
    output                 dds_fifo_full_o,          // opcproc full.
    output                 dds_fifo_empty_o,         // opcproc empty.
    output                 dds_spi_sclk_o,           // 
    output                 dds_spi_mosi_o,           //
    input                  dds_spi_miso_i,           // 
    output                 dds_spi_ss_n_o,           // 
    output                 dds_spi_iorst_o,          // 
    output                 dds_spi_ioup_o,          // 
    output                 dds_spi_sync_o,           // 
    output                 dds_spi_ps0_o,            // 
    output                 dds_spi_ps1_o,            // 
    output                 dbg0_o,                   // Utility debug output #0.
    output                 dbg1_o,                   // Utility debug output #1.
    output                 dbg2_o,                   // Utility debug output #2.
    output                 dbg3_o                    // Utility debug output #3.
  );

   // DDS SPI State Machine State Codes
   localparam  DDS_SPI_STATE_IDLE = 3'b000;
   localparam  DDS_SPI_STATE_CS0  = 3'b001;
   localparam  DDS_SPI_STATE_CS1  = 3'b010;
   localparam  DDS_SPI_STATE_SHF0 = 3'b100;
   localparam  DDS_SPI_STATE_SHF1 = 3'b101;

  
   reg  [3:0]                     dds_clk_cnt          = 4'b0;
   reg                            dds_spi_sclk         = 1'b1;
   reg                            dds_spi_wtck         = 1'b0;                 // 1-tick just prior to falling edge of dds_spi_clk
   reg                            dds_spi_wtckr        = 1'b0;                 // 1-tick just prior to falling edge of dds_spi_clk
   reg                            dds_spi_rtck         = 1'b0;                 // 1-tick just prior to rising  edge of dds_spi_clk
   reg                            dds_spi_rtckr        = 1'b0;                 // 

   reg                            dds_init_we          = 1'b0;
   reg  [35:0]                    dds_init_datr        = 36'b0;

   wire [35:0]                    dds_fifo_dati_w      = ( ({36{hwdbg_we_i}}    & hwdbg_dat_i)               | 
                                                           ({36{freqproc_we_i}} & {4'b1100, freqproc_dat_i}) |
                                                           ({36{dds_init_we}}   & dds_init_datr) ); 
   wire                           dds_fifo_we          = freqproc_we_i | hwdbg_we_i | dds_init_we;
   reg  [35:0]                    dds_fifo_datir       = 36'b0;
   reg                            dds_fifo_wer         = 1'b0;

   wire [35:0]                    dds_fifo_dato_w;
   reg                            dds_fifo_rdr         = 1'b0;
   reg                            dds_fifo_rdrr        = 1'b0;
   reg  [35:0]                    dds_fifo_dator       = 36'b0;
   
   wire                           dds_fifo_full_w;
   wire                           dds_fifo_empty_w;

   reg  [2:0]                     dds_spi_state        = DDS_SPI_STATE_IDLE;
   reg  [39:0]                    dds_ops_shftr        = 40'b0;
   reg  [6:0]                     shftCnt              = 1'b0;
   
   reg                            dds_doInitr          = 1'b0;
   reg                            dds_initing          = 1'b0;  // Load FIFO w/ init words.
   reg                            dds_spi_iorst        = 1'b0;
   reg                            dds_iorsting         = 1'b0;
   reg                            dds_init_loading     = 1'b0;
   reg  [4:0]                     dds_iorsting_cnt     = 5'b0_0000;
   reg                            dds_initd            = 1'b0;  // Completely done SPI-ing init.
   reg  [15:0]                    dds_init_op_cntr     = 4'b0000;
   
   reg                            dds_interOpGap       = 1'b0;
   reg  [4:0]                     dds_interOpGap_cnt   = 5'b0_0000;
   
   reg                            dds_spi_ss           = 1'b0;
   wire                           dds_spi_ss_s         = (~dds_fifo_empty_w & dds_spi_wtck &
                                                            (dds_spi_state == DDS_SPI_STATE_IDLE) & ~dds_init_loading & ~dds_interOpGap & ~dds_spi_ioup);
   reg                            dds_spi_ss_k         = 1'b0;
   reg                            dds_spi_do_ioup      = 1'b0;
   reg                            dds_spi_ioup_ce      = 1'b0;
   reg                            dds_spi_ioup         = 1'b0;
   reg                            dds_spi_ioupr        = 1'b0;
   reg  [4:0]                     dds_spi_ioup_cnt     = 5'b0_0000;

   
   // Generate: dds_spi_sclk   (e.g. SPI_CLK_RATIO == 8)
   //           dds_spi_wtck
   //           dds_spi_rtck
   // N = Fclk_i / Fspi_clk
   //                                |                       |                       |                       |
   //                                |                       |                       |                       |
   //                    __    __    __    __    __    __    __    __    __    __    __    __    __    __    __    __   
   // clk_i           __/  \__/  \__/  \__/  \__/  \__/  \__/| \__/  \__/  \__/  \__/| \__/  \__/  \__/  \__/| \__/  \__ 
   //                 ___ _____ _____|_____ _____ _____ _____|_____ _____ _____ _____|_____ _____ _____ _____|_____ _____
   // dds_clk_cnt     ___X__6__X__7__X__0__X__1__X__2__X__3__X__4__X__5__X__6__X__7__X__0__X__1__X__2__X__3__X__4__X__5__X
   //                      N-2   N-1 |            N/2-2 N/2-1|             N-2   N-1 |            N/2-2 N/2-1|
   //                                |                       |                       |                       |
   //                                |_______________________|                       |_______________________|
   // dds_spi_sclk    _______________/                       \_______________________/                       \__________              
   //                           _____|                       |                  _____|                       |
   // dds_spi_rtck    _________/     \_______________________|_________________/     \_______________________|__________
   //                                |                   _____                       |                   _____
   // dds_spi_wtck    _______________|__________________/    |\______________________|__________________/    |\_________
   //                                |                       |                       |                       |
   //                                |                       |                       |                       |
                                     
   always @(posedge clk_i) begin
      if (rst_i) begin
         dds_clk_cnt              <= 4'b0;
         dds_spi_sclk             <= 1'b1;
         dds_spi_wtck             <= 1'b0;
         dds_spi_wtckr            <= 1'b0;
         dds_spi_rtck             <= 1'b0;
         dds_spi_rtckr            <= 1'b0;
      end  // End of if (rst_i) then portion
      else begin
         dds_spi_wtck             <= 1'b0;
         dds_spi_wtckr            <= dds_spi_wtck;
         dds_spi_rtck             <= 1'b0;
         dds_spi_rtckr            <= dds_spi_rtck;

         dds_clk_cnt              <= dds_clk_cnt + 4'b0001;

         case(dds_clk_cnt) 
         4'b0110: begin
            dds_spi_wtck       <= 1'b1;              // dds_spi_rtck to be high during last tck
         end                                         //     before falling edge of dds_spi_sclk.
         4'b0111: begin
            dds_spi_sclk       <= 1'b0;              // falling edge of dds_spi_sclk next tick.
         end                                         //
         4'b1110: begin
            dds_spi_rtck       <= 1'b1;              // dds_spi_rtck rising edge last tck
         end
         4'b1111: begin
            dds_spi_sclk       <= 1'b1;              // dds_spi_sclk starts out as high.
            dds_clk_cnt        <= 4'b0000;           // rising  edge of dds_spi_sclk next tick.
         end
         endcase  // End of case(dds_clk_cnt)
      end  // End of if (rst_i) begin else portion
   end  // end of always @(posedge CLK)
   // end of generate dds_spi_sclk

   // dds_fifo_datir/ dds_fifo_dato_w Format:
   //
   // ++-----++-----+-----+-----++-----+-----+- - - - - - - -+-----+-----++
   // || 35  || 34  | 33  | 32  || 31  | 30  |               |  1  |  0  ||
   // ++-----++-----+-----+-----++-----+-----+- - - - - - - -+-----+-----++
   // || IO  ||     |     |     ||     |     |               |     |     ||
   // || UPDT|| A2  | A1  | A0  || D31 | D30 |               | D1  | D0  ||
   // ||     ||     |     |     ||     |     |               |     |     ||
   // ++-----++-----+-----+-----++-----+-----+- - - - - - - -+-----+-----++
   // |                                                                   |
   // |<--------- Entry from hwdbg source ----- - - - - - - ------------->|
   // |                                                                   |
   // |<1'b1>||<-----3'b100---->||                                        |
   // |      ||                 ||                                        |
   // | DO   ||  AD9954 FTW0    ||                                        |
   // | IOUP ||  (Reg Addr 4)   ||                                        |
   // |      ||                 ||                                        |
   // |<-- inserted by hw ----->||<----- Entry from freq processor ------>|
   // |                         ||                                        |
   //
   // We are using the AD9954 in Direct Frequency (i.e. "Single Tone") Mode; MSbit first.

   // dds_ops_shftr Format:
   //
   // ++-----++-----+-----+-----+-----+-----+-----+-----++-----+-----+- - - - - - - -+-----+-----++
   // || 39  || 38  | 37  | 36  | 35  | 34  | 33  | 32  || 31  | 30  |               |  1  |  0  ||
   // ++-----++-----+-----+-----+-----+-----+-----+-----++-----+-----+- - - - - - - -+-----+-----++
   // || RD/ ||     |     |     |     |     |     |     ||     |     |               |     |     ||
   // ||  __ || A6  | A5  | A4  | A3  | A2  | A1  | A0  || D31 | D30 |               | D1  | D0  ||
   // ||  WR ||     |     |     |     |     |     |     ||     |     |               |     |     ||
   // ++-----++-----+-----+-----+-----+-----+-----+-----++-----+-----+- - - - - - - -+-----+-----++
   // ||     ||     |     |     |     |     |     |     ||     |     |               |     |     ||
   // ||  0  ||  X  |  X  | A4  | A3  | A2  | A1  | A0  || D31 | D30 |               | D1  | D0  ||
   // ||     || (0) | (0) |     |     |     |     |     ||     |     |               |     |     ||
   // ++-----++-----+-----+-----+-----+-----+-----+-----++-----+-----+- - - - - - - -+-----+-----++
   //     ^      ^     ^     ^     ^     ^     ^     ^      ^     ^                     ^     ^
   //     |      |     |     |     |     |     |     |      |     |                     |     |
   //     |      |     |     |     |     |     |     |      |     |     - - - - - -     |     |
   //     |      |     |     |     |     |     |     |      |     |                     |     |
   //     |      |     |     |     |     |     |     |      +-----+-- - - - - - - - - --+-----+----- Left justified contents to be written.
   //     |      |     |     |     |     |     |     |                                               This could be 8, 16, 24, or 32 bits.
   //     |      |     |     |     |     |     |     |                                               Frequency Opcode only does 32-bit FTW0.
   //     |      |     |     |     |     |     |     |
   //     |      |     |     +-----+-----+-----+-----+----- These address AD9954 registers.
   //     |      |     |                                    HWDBG can select 5'0_0000 through 5'0 0111.
   //     |      |     |                                    Frequency Opcode always selects FTW0 = 5'b0_0100.
   //     |      |     |
   //     |      +-----+---- These are DON'T CARE so we drive 0's.
   //     |
   //     +------ Currently we ONLY WRITE so this is always 1'b0.
      
   always @(posedge clk_i)
   begin
      if (rst_i) begin
        dds_fifo_wer              <= 1'b0;
        dds_fifo_datir            <= 36'b0;
      end
      else begin
        dds_fifo_wer              <= dds_fifo_we;
        dds_fifo_datir            <= dds_fifo_dati_w;
      end
   end 
   

   // Input FIFO instantiation for DDS commands from either opcode processor or hwdbg uart.
   snglClkFifoParmd #(
      .USE_BRAM          (0),
      .WIDTH             (36),
      .DEPTH             (4)
   )
   ddsInFifo
   (
      .CLK(clk_i),
      .RST(rst_i),
      .WEN(dds_fifo_wer),
      .DI(dds_fifo_datir),
      .FULL(dds_fifo_full_w),
      .REN(dds_fifo_rdr),
      .DO(dds_fifo_dato_w),
      .MT(dds_fifo_empty_w)
   );

   
   // **************************************************
   // *                                                *   
   // * DDS SPI State Machine                          *
   // *                                                *   
   // **************************************************
   always @(posedge clk_i) begin
      if (rst_i) begin
         dds_spi_state            <= DDS_SPI_STATE_IDLE;
         dds_spi_ss               <= 1'b0;
         dds_spi_ss_k             <= 1'b0;
         dds_spi_iorst            <= 1'b0;
         dds_spi_ioup             <= 1'b0;
         dds_spi_ioupr            <= 1'b0;
         dds_spi_ioup_ce          <= 1'b0;
         dds_spi_ioup_cnt         <= 5'b0_0000;
         dds_ops_shftr            <= 40'b0;
         shftCnt                  <= 6'b00_0000;
         dds_fifo_rdr             <= 1'b0;
         dds_fifo_rdrr            <= 1'b0;
         dds_fifo_dator           <= 36'b0;
         dds_doInitr              <= 1'b0;
         dds_initing              <= 1'b0;
         dds_init_loading         <= 1'b0;
         dds_initd                <= 1'b0;
         dds_iorsting             <= 1'b0;
         dds_iorsting_cnt         <= 5'b0_0000;
         dds_init_we              <= 1'b0;
         dds_init_op_cntr         <= 4'b0000;
         dds_interOpGap           <= 1'b0;
         dds_interOpGap_cnt       <= 5'b0_0000;
      end
      else begin
         // One-tick signals
         dds_fifo_rdr             <= 1'b0;
         dds_init_we              <= 1'b0;
         
         // Everytime signals
         dds_spi_ss               <= ~dds_spi_ss_k & (dds_spi_ss | dds_spi_ss_s);
         dds_spi_ss_k             <= (shftCnt == 6'b00_0000) & (dds_clk_cnt == 4'b0110) & (dds_spi_state == DDS_SPI_STATE_SHF0);


         // Do init sequence (kicked off by doInit_i == 1'b1).
         dds_doInitr              <= doInit_i;
         if (doInit_i & ~dds_doInitr) begin
            dds_spi_state         <= DDS_SPI_STATE_IDLE;
            dds_init_loading      <= 1'b1;
            dds_initing           <= 1'b1;
            dds_initd             <= 1'b0;
            dds_init_op_cntr      <= 4'b0000;
            dds_iorsting          <= 1'b1;
            dds_iorsting_cnt      <= 5'b0_0001;
         end
         if (dds_iorsting) begin
            if (dds_iorsting_cnt == 5'b0_1111) begin
               dds_iorsting       <= 1'b0;
               dds_iorsting_cnt   <= 5'b0_0000;
            end
            else begin
               dds_iorsting_cnt   <= dds_iorsting_cnt + 5'b0_0001;
            end            
         end
         else begin
         end
         dds_spi_iorst            <= dds_iorsting;


         if (dds_interOpGap) begin
            dds_interOpGap_cnt    <= dds_interOpGap_cnt + 5'b0_0001;
            if (dds_interOpGap_cnt == 5'b1_1111) begin
               dds_interOpGap     <= 1'b0;
               dds_interOpGap_cnt <= 5'b0_0000;
            end
         end

         if (dds_initing) begin
            case (dds_init_op_cntr)
            4'b0011: begin
               dds_init_datr   <= 36'h0_00000240;
               dds_init_we     <= 1'b1;              // 1-tick signal
               dds_init_op_cntr<= dds_init_op_cntr + 4'b0001;
            end
            4'b0111: begin
               dds_init_datr   <= 36'h1_00020800;
               dds_init_we     <= 1'b1;              // 1-tick signal
               dds_init_op_cntr<= dds_init_op_cntr + 4'b0001;
            end
            4'b1011: begin
               dds_init_datr   <= 36'hC_1B637E53;    // Generates an ioup pulse that returns low after operation.
               dds_init_we     <= 1'b1;              // 1-tick signal
               dds_init_op_cntr<= dds_init_op_cntr + 4'b0001;
            end
            4'b1111: begin
               dds_init_op_cntr<= 4'b1111;
               dds_init_loading<= 1'b0;
            end
            default: begin
               dds_init_op_cntr<= dds_init_op_cntr + 4'b0001;
            end
            endcase  // End of case (dds_init_op_cntr)
         end  // End of if (dds_initing)


         // dds FIFO reads and shifting
         dds_fifo_rdr             <= dds_spi_ss_s;
         dds_fifo_rdrr            <= dds_fifo_rdr;
         dds_fifo_dator           <= dds_fifo_dato_w;
         if ( dds_fifo_rdr ) begin
            dds_ops_shftr         <= {1'b0, 4'b0000, dds_fifo_dato_w[34:0]};
         end
         else if (dds_spi_wtck) begin
            dds_ops_shftr         <= {dds_ops_shftr[38:0], 1'b0}; 
         end
         if ( dds_fifo_rdrr ) begin
            dds_spi_do_ioup       <= dds_fifo_dator[35];
            shftCnt               <= AD9954_numRegBits(dds_fifo_dator[34:32]);
         end        
         if ( dds_spi_ss & dds_spi_wtck ) begin
            shftCnt               <= shftCnt - 6'b00_0001;
         end
         
         
         // Generate dds_IOUP pulse
         if (dds_spi_ioup_ce) begin
            dds_spi_ioup_cnt      <= dds_spi_ioup_cnt  + 5'b0_0001;
            case (dds_spi_ioup_cnt)
            5'b0_1111: begin
               dds_spi_ioup       <= 1'b1;  // Assert   the IOUP pulse.
            end
            5'b1_1111: begin
               dds_spi_ioup       <= 1'b0;  // Deassert the IOUP pulse.
               dds_initing        <= 1'b0;  // If you were initing, the first IOUP pulse kills dds_initing and
               dds_initd          <= 1'b1;  //                                           sets  dds_initd.
               dds_spi_ioup_ce    <= 1'b0;
               dds_spi_ioup_cnt   <= 5'b0_0000;
               dds_interOpGap     <= 1'b1;
            end
            endcase  // End of case (dds_spi_ioup_cnt)
         end
         dds_spi_ioup             <= ~(dds_spi_ioup_cnt == 5'b1_1111) & (dds_spi_ioup | (dds_spi_ioup_cnt == 5'b0_1111));
         dds_spi_ioupr            <= dds_spi_ioup; 
         
         
         // DDS SPI State Machine: state-by-state case statement
         case (dds_spi_state)
         DDS_SPI_STATE_IDLE: begin
            if (~dds_fifo_rdr | dds_init_loading | dds_interOpGap | dds_spi_ioup) begin
               dds_spi_state      <= DDS_SPI_STATE_IDLE;
            end
            else begin
               dds_spi_state      <= DDS_SPI_STATE_CS0;
            end
         end //  End of DDS_SPI_STATE_IDLE: case.
         DDS_SPI_STATE_CS0: begin
            dds_spi_state         <= DDS_SPI_STATE_CS1;
         end //  End of DDS_SPI_STATE_CS0: case.
         DDS_SPI_STATE_CS1: begin
            if (~dds_spi_wtckr) begin
               dds_spi_state      <= DDS_SPI_STATE_CS1;
            end
            else begin
               dds_spi_state      <= DDS_SPI_STATE_SHF0;
            end
         end //  End of DDS_SPI_STATE_CS1: case.
         DDS_SPI_STATE_SHF0: begin
            if (!((dds_spi_wtck == 1'b1) && (shftCnt == 6'b00_0000))) begin
               dds_spi_state      <= DDS_SPI_STATE_SHF0;
            end
            else begin
               dds_spi_state      <= DDS_SPI_STATE_SHF1;
            end
         end //  End of DDS_SPI_STATE_SHF0: case.
         DDS_SPI_STATE_SHF1: begin
            if (dds_spi_do_ioup | dds_spi_ioup_ce) begin
               dds_spi_state         <= DDS_SPI_STATE_SHF1;
            end
            else begin
               dds_spi_state         <= DDS_SPI_STATE_IDLE;
            end
            if (dds_spi_do_ioup) begin
               dds_spi_do_ioup       <= 1'b0;
               dds_spi_ioup_ce       <= 1'b1;
            end 
            else begin
               dds_interOpGap        <= 1'b1;
            end
         end //  End of DDS_SPI_STATE_SHF0: case.
         endcase //  End of case (dds_spi_state)
      end  // End of always @(posedge clk_i)  ... DDS SPI State Machine ...
   end // End of always @(posedge clk_i)  
   
   // convert AD9954 RegAddr to # of bits in SPI (Instruction_8bits + RegLength_bits - 1)
   //  DDS_REG_CFR1_LEN   = 32 bits
   //  DDS_REG_CFR2_LEN   = 24 bits
   //  DDS_REG_ASF_LEN    = 16 bits
   //  DDS_REG_ARR_LEN    =  8 bits
   //  DDS_REG_FTW0_LEN   = 32 bits
   //  DDS_REG_POW0_LEN   = 16 bits
   //
   function [5:0] AD9954_numRegBits;
      input [2:0] dds_regAddr;
      begin
         case (dds_regAddr[2:0])
            3'h0: AD9954_numRegBits = 6'h27;  // CFR0 (# of bits - 1) + 8 = 39 decimal.
            3'h1: AD9954_numRegBits = 6'h1F;  // CFR1 (# of bits - 1) + 8 = 31 decimal.
            3'h2: AD9954_numRegBits = 6'h17;  // ASF  (# of bits - 1) + 8 = 23 decimal.
            3'h3: AD9954_numRegBits = 6'h0F;  // ARR  (# of bits - 1) + 8 = 15 decimal.
            3'h4: AD9954_numRegBits = 6'h27;  // FTW0 (# of bits - 1) + 8 = 39 decimal.
            3'h5: AD9954_numRegBits = 6'h17;  // POW0 (# of bits - 1) + 8 = 23 decimal.
            3'h6: AD9954_numRegBits = 6'h27;  // FTW1 (# of bits - 1) + 8 = 39 decimal.
            default: AD9954_numRegBits = 6'hx;
         endcase
      end    
   endfunction

   assign  dds_fifo_full_o    = dds_fifo_full_w;
   assign  dds_fifo_empty_o   = dds_fifo_empty_w;
   assign  dds_spi_mosi_o     = dds_spi_ss ? dds_ops_shftr[39] : 1'b0;
   assign  dds_spi_sclk_o     = dds_spi_ss ? dds_spi_sclk : 1'b1; 
   assign  dds_spi_ss_n_o     = ~dds_spi_ss;
   
   assign  dds_spi_iorst_o    = dds_spi_iorst;
   assign  dds_spi_ioup_o     = dds_spi_ioupr; 
   assign  dds_spi_sync_o     = 1'b0; 
   assign  dds_spi_ps0_o      = 1'b0; 
   assign  dds_spi_ps1_o      = 1'b0; 

   assign  dds_initd_o        = dds_initd;
       
   assign  dbg0_o             = dds_spi_ss;
   assign  dbg1_o             = dds_ops_shftr[39];
   assign  dbg2_o             = dds_spi_iorst;
   assign  dbg3_o             = dds_spi_ioup;

endmodule

