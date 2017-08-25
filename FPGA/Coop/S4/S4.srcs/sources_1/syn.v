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
// File name:  syn.v
// Project:    s4x7
// Author:     Jeff Cooper, aa1ww.coop@gmail.com (JLC)
// Purpose:    Hardware interface to LTC6946 Synthesizer chip.
// ---------------------------------------------------------------------------------
// LTC6946 Application Summary:
//     Set multiply a nominal 10.7MHz signal by 229.
//     Device is initialized and requires no additional settings.
//
//
// ---------------------------------------------------------------------------------
// 0.00.1  2017-08-02 (JLC) Created.
//
//
//----------------------------------------------------------------------------------

`include "timescale.v"        // Every source file needs this include


module ltc_spi #( parameter VRSN      = 16'habcd, CLK_FREQ  = 100000000, SPI_CLK_FREQ=20000000)
  (
    // infrastructure, etc.
    input                  clk_i,                    // 
    input                  rst_i,                    // 
    input                  doInit_i,                 // do an init sequence. 
    input        [11:0]    hwdbg_dat_i,              // hwdbg data input.
    input                  hwdbg_we_i,               // hwdbg we.
    output                 syn_fifo_full_o,          // opcproc full.
    output                 syn_fifo_empty_o,         // opcproc empty.
    output                 syn_spi_sclk_o,           // 
    output                 syn_spi_mosi_o,           //
    input                  syn_spi_miso_i,           // 
    output                 syn_spi_ss_n_o,           // 
    input                  syn_stat_i,               // Features set by LTC6946.reg1[5:0] (addr == 4'h1)
    output reg             syn_mute_n_o,             // 1=>RF; 0=>MUTE.
    output                 dbg0_o,                   // Utility debug output #0.
    output                 dbg1_o,                   // Utility debug output #1.
    output                 dbg2_o,                   // Utility debug output #2.
    output                 dbg3_o                    // Utility debug output #3.
  );


   // SYN SPI State Machine State Codes
   localparam  SYN_SPI_STATE_IDLE = 3'b000;
   localparam  SYN_SPI_STATE_CS0  = 3'b001;
   localparam  SYN_SPI_STATE_CS1  = 3'b010;
   localparam  SYN_SPI_STATE_SHF0 = 3'b100;
   localparam  SYN_SPI_STATE_SHF1 = 3'b101;

  
   reg  [3:0]                     syn_spi_clk_cnt      = 4'b0;
   reg                            syn_spi_sclk         = 1'b1;
   reg                            syn_spi_wtck         = 1'b0;                 // 1-tick just prior to falling edge of syn_spi_clk
   reg                            syn_spi_wtckr        = 1'b0;                 // 1-tick just prior to falling edge of syn_spi_clk
   reg                            syn_spi_rtck         = 1'b0;                 // 1-tick just prior to rising  edge of syn_spi_clk
   reg                            syn_spi_rtckr        = 1'b0;                 // 

   wire [11:0]                    syn_fifo_dati_w      = ( ({12{hwdbg_we_i}}    & hwdbg_dat_i)   | 
                                                           ({12{syn_init_we}}   & syn_init_datr) ); 
   wire                           syn_fifo_we          = hwdbg_we_i | syn_init_we;
   reg  [11:0]                    syn_fifo_datir       = 12'b0;
   reg                            syn_fifo_wer         = 1'b0;

   wire [11:0]                    syn_fifo_dato_w;
   reg                            syn_fifo_rdr         = 1'b0;
   reg                            syn_fifo_rdrr        = 1'b0;
   reg  [11:0]                    syn_fifo_dator       = 12'b0;
   
   wire                           syn_fifo_full_w;
   wire                           syn_fifo_empty_w;

   reg  [2:0]                     syn_spi_state        = SYN_SPI_STATE_IDLE;
   reg  [15:0]                    syn_ops_shftr        = 16'b0;
   reg  [5:0]                     shftCnt              = 5'b0_0000;
   
   reg                            syn_doInitr          = 1'b0;
   reg                            syn_initing          = 1'b0;  // Load FIFO w/ init words.
   reg                            syn_init_shfting     = 1'b0;  // Load FIFO w/ init words.
   reg                            syn_init_loading     = 1'b0;
   reg                            syn_initd            = 1'b0;  // Completely done SPI-ing init.
   reg  [5:0]                     syn_init_op_cntr     = 6'b00_0000;
   reg                            syn_init_we          = 1'b0;
   reg  [11:0]                    syn_init_datr;
   reg  [4:0]                     syn_init_done_cntr   = 5'b0_0000;
   
   reg                            syn_interOpGap       = 1'b0;
   reg  [4:0]                     syn_interOpGap_cnt   = 5'b0_0000;

   reg                            syn_spi_ss           = 1'b0;
   wire                           syn_spi_ss_s         = (~syn_fifo_empty_w & syn_spi_wtck &
                                                            (syn_spi_state == SYN_SPI_STATE_IDLE) &
//                                                            (~syn_init_loading | syn_fifo_full_w) &
                                                             ~syn_interOpGap);
   reg                            syn_spi_ss_k         = 1'b0;
   
   
   // Generate: syn_spi_sclk   (e.g. SPI_CLK_RATIO == 8)
   //           syn_spi_wtck
   //           syn_spi_rtck
   // 
   //                                |                       |                       |                       |
   //                                |                       |                       |                       |
   //                    __    __    __    __    __    __    __    __    __    __    __    __    __    __    __    __   
   // clk_i           __/  \__/  \__/  \__/  \__/  \__/  \__/| \__/  \__/  \__/  \__/| \__/  \__/  \__/  \__/| \__/  \__ 
   //                                |_______________________|                       |_______________________|
   // syn_spi_sclk    _______________/                       \_______________________/                       \__________              
   //                           _____|                       |                  _____|                       |
   // syn_spi_rtck    _________/     \_______________________|_________________/     \_______________________|__________
   //                                |                   _____                       |                   _____
   // syn_spi_wtck    _______________|__________________/    |\______________________|__________________/    |\_________
   //                                |                       |                       |                       |
   //                                |                       |                       |                       |
                                     
                                     
   always @(posedge clk_i) begin
      if (rst_i) begin
         syn_spi_clk_cnt          <= 4'b0000;
         syn_spi_sclk             <= 1'b1;
         syn_spi_wtck             <= 1'b0;
         syn_spi_wtckr            <= 1'b0;
         syn_spi_rtck             <= 1'b0;
         syn_spi_rtckr            <= 1'b0;
      end  // End of if (rst_i) then portion
      else begin
         syn_spi_wtck             <= 1'b0;
         syn_spi_wtckr            <= syn_spi_wtck;
         syn_spi_rtck             <= 1'b0;
         syn_spi_rtckr            <= syn_spi_rtck;

         syn_spi_clk_cnt          <= syn_spi_clk_cnt + 4'b0001;

         case(syn_spi_clk_cnt) 
         4'b0110: begin
            syn_spi_wtck       <= 1'b1;              // syn_spi_rtck to be high during last tck
         end                                         //     before falling edge of syn_spi_sclk.
         4'b0111: begin
            syn_spi_sclk       <= 1'b0;              // syn_spi_sclk falling edge next tick.
         end                                         //
         4'b1110: begin
            syn_spi_rtck       <= 1'b1;              // syn_spi_rtck to be high during last tck
         end                                         //     before rising  edge of syn_spi_sclk.
         4'b1111: begin
            syn_spi_sclk       <= 1'b1;              // syn_spi_sclk starts out as high.
            syn_spi_clk_cnt    <= 4'b0000;         // syn_spi_sclk rising  edge next tick..
         end
         endcase  // End of case(syn_spi_clk_cnt)
      end  // End of if (rst_i) begin else portion
   end  // end of always @(posedge CLK)
   // end of generate syn_spi_sclk

 
   // syn_fifo_datir/ syn_fifo_dato_w Format:
   //
   // ++-----+-----+-----+-----++-----++-----+-----+- - - - - - - -+-----+-----++
   // || 12  | 11  | 10  |  9  ||  8  ||  7  |  6  |               |  1  |  0  ||
   // ++-----+-----+-----+-----++-----++-----+-----+- - - - - - - -+-----+-----++
   // ||     |     |     |     || RD/ ||     |     |               |     |     ||
   // ||  A3 |  A2 |  A1 |  A0 ||  __ ||  D7 |  D6 |               |  D1 |  D0 ||
   // ||     |     |     |     ||  WR ||     |     |               |     |     ||
   // ++-----+-----+-----+-----++-----++-----+-----+- - - - - - - -+-----+-----++
   // |                                                                         |
   // |                                                                         |
   // |                                                                         |
   // |                                                                         |
   // |<--------- Entry from hwdbg source ----------- - - - - - - ------------->|
   // |<--------- Entry from init logic  ------------ - - - - - - ------------->|
   //
   //
   // We are using the LTC6946 to multiply the AD9954 DDS output frequency by 229.
   //                                                         _
   // The LTC6946 SPI format is 7 bits of register address, R/W (1 bit == 0), 8 bits of register data
   // (multiple bytes will auto-incr the address; not using that feature yet.).
   // 
   //
   //
   // syn_ops_shftr Format:
   //
   // ++-----+-----+-----+-----+-----+-----+-----++-----++-----+-----+- - - - - - - -+-----+-----++
   // ||  15 |  14 |  13 |  12 | 11  | 10  |  9  ||  8  ||  7  |  6  |               |  1  |  0  ||
   // ++-----+-----+-----+-----+-----+-----+-----++-----++-----+-----+- - - - - - - -+-----+-----++
   // ||     |     |     |     |     |     |     || RD/ ||     |     |               |     |     ||
   // || A6  | A5  | A4  | A3  | A2  | A1  | A0  ||  __ || D31 | D30 |               | D1  | D0  ||
   // ||     |     |     |     |     |     |     ||  WR ||     |     |               |     |     ||
   // ++-----+-----+-----+-----+-----+-----+-----++-----++-----+-----+- - - - - - - -+-----+-----++
   // ||     |     |     |     |     |     |     ||   _ ||     |     |               |     |     ||
   // ||  X  |  X  |  X  | A3  | A2  | A1  | A0  || R/W || D31 | D30 |               | D1  | D0  ||
   // || (0) | (0) | (0) |     |     |     |     || (0) ||     |     |               |     |     ||
   // ++-----+-----+-----+-----+-----+-----+-----++-----++-----+-----+- - - - - - - -+-----+-----++
   //     ^      ^     ^     ^     ^     ^     ^     ^      ^     ^                     ^     ^
   //     |      |     |     |     |     |     |     |      |     |                     |     |
   //     |      |     |     |     |     |     |     |      |     |     - - - - - -     |     |
   //     |      |     |     |     |     |     |     |      |     |                     |     |
   //     |      |     |     |     |     |     |     |      +-----+-- - - - - - - - - --+-----+---- Data Byte MSB-First.
   //     |      |     |     |     |     |     |     |
   //     |      |     |     |     |     |     |     +----------------------- Currently we ONLY WRITE so this is always 1'b0.
   //     |      |     |     |     |     |     |      
   //     +------+-----+-----+-----+-----+-----+----------- These address LTC6946 registers.
   //     ^
   //     |
   //     |
   //     +--------------------------------- FIRST BIT SHIFTED OUT OF FPGA.
   //      
   //      
      
   always @(posedge clk_i)
   begin
      if (rst_i) begin
        syn_fifo_wer              <= 1'b0;
        syn_fifo_datir            <= 12'b0;
      end
      else begin
        syn_fifo_wer              <= syn_fifo_we;
        syn_fifo_datir            <= syn_fifo_dati_w;
      end
   end 
   

   always @(posedge clk_i)
   begin
      if (rst_i) begin
        syn_fifo_wer              <= 1'b0;
        syn_fifo_datir            <= 12'b0;
      end
      else begin
        syn_fifo_wer              <= syn_fifo_we;
        syn_fifo_datir            <= syn_fifo_dati_w;
      end
   end 
   

   // Input FIFO instantiation for SYN commands from either opcode processor or hwdbg uart or init logic.
   snglClkFifoParmd #(
      .USE_BRAM          (0),
      .WIDTH             (12),
      .DEPTH             (8)
   )
   synInFifo
   (
      .CLK(clk_i),
      .RST(rst_i),
      .WEN(syn_fifo_wer),
      .DI(syn_fifo_datir),
      .FULL(syn_fifo_full_w),
      .REN(syn_fifo_rdr),
      .DO(syn_fifo_dato_w),
      .MT(syn_fifo_empty_w)
   );


   // **************************************************
   // *                                                *   
   // * SYN SPI State Machine                          *
   // *                                                *   
   // **************************************************
   always @(posedge clk_i) begin
      if (rst_i) begin
         syn_spi_state            <= SYN_SPI_STATE_IDLE;
         syn_spi_ss               <= 1'b0;
         syn_spi_ss_k             <= 1'b0;
         syn_ops_shftr            <= 16'b0;
         shftCnt                  <= 5'b0_0000;
         syn_fifo_rdr             <= 1'b0;
         syn_fifo_rdrr            <= 1'b0;
         syn_fifo_dator           <= 12'b0;
         syn_doInitr              <= 1'b0;
         syn_initing              <= 1'b0;
         syn_init_loading         <= 1'b0;
         syn_init_shfting         <= 1'b0;
         syn_init_we              <= 1'b0;
         syn_init_datr            <= 12'b0;
         syn_init_op_cntr         <= 6'b00_0000;
         syn_initd                <= 1'b0;
         syn_interOpGap           <= 1'b0;
         syn_interOpGap_cnt       <= 5'b0_0000;
         syn_mute_n_o             <= 1'b0;          // Mute until init done
         syn_init_done_cntr       <= 5'b0_0001; 
      end
      else begin
         // One-tick signals
         syn_fifo_rdr             <= 1'b0;
         syn_init_we              <= 1'b0;
         
         // Everytime signals
         syn_spi_ss               <= ~syn_spi_ss_k & (syn_spi_ss | syn_spi_ss_s);
         syn_spi_ss_k             <= (shftCnt == 5'b0_0000) & (syn_spi_clk_cnt == 4'b0110) & (syn_spi_state == SYN_SPI_STATE_SHF0);


         // Do init sequence (kicked off by doInit_i == 1'b1).
         syn_doInitr              <= doInit_i;
         if (doInit_i & ~syn_doInitr) begin
            syn_spi_state         <= SYN_SPI_STATE_IDLE;
            syn_init_loading      <= 1'b1;
            syn_init_shfting      <= 1'b1;
            syn_initing           <= 1'b1;
            syn_initd             <= 1'b0;
            syn_init_op_cntr      <= 6'b00_0000;
            syn_mute_n_o          <= 1'b0;          // Mute until init done
         end
         
         if (syn_init_loading & ~syn_fifo_full_w) begin
            if (syn_init_op_cntr != 6'b11_1111) begin
               syn_init_op_cntr <= syn_init_op_cntr + 6'b00_0001;
            end
            case (syn_init_op_cntr)
            6'b00_0011: begin
               syn_init_datr   <= 12'h2_0A;
               syn_init_we     <= 1'b1;              // 1-tick signal
               // syn_init_op_cntr<= syn_init_op_cntr + 5'b0_0001;
            end
            6'b00_0111: begin
               syn_init_datr   <= 12'h3_10;
               syn_init_we     <= 1'b1;              // 1-tick signal
               // syn_init_op_cntr<= syn_init_op_cntr + 5'b0_0001;
            end
            6'b00_1011: begin
               syn_init_datr   <= 12'h4_01;
               syn_init_we     <= 1'b1;              // 1-tick signal
               // syn_init_op_cntr<= syn_init_op_cntr + 5'b0_0001;
            end
            6'b00_1111: begin
               syn_init_datr   <= 12'h5_00;
               syn_init_we     <= 1'b1;              // 1-tick signal
               // syn_init_op_cntr<= syn_init_op_cntr + 5'b0_0001;
            end
            6'b01_0011: begin
               syn_init_datr   <= 12'h6_E5;
               syn_init_we     <= 1'b1;              // 1-tick signal
               // syn_init_op_cntr<= syn_init_op_cntr + 5'b0_0001;
            end
            6'b01_0111: begin
               syn_init_datr   <= 12'h7_83;
               syn_init_we     <= 1'b1;              // 1-tick signal
               // syn_init_op_cntr<= syn_init_op_cntr + 5'b0_0001;
            end
            6'b01_1011: begin
               syn_init_datr   <= 12'h8_F9;
               syn_init_we     <= 1'b1;              // 1-tick signal
               // syn_init_op_cntr<= syn_init_op_cntr + 5'b0_0001;
            end
            6'b01_1111: begin
               syn_init_datr   <= 12'h9_1A;
               syn_init_we     <= 1'b1;              // 1-tick signal
               // syn_init_op_cntr<= syn_init_op_cntr + 5'b0_0001;
            end
            6'b10_0011: begin
               syn_init_datr   <= 12'hA_C0;          // 25-Aug we want a big delay before sending this, time for CAL to finish
               syn_init_we     <= 1'b1;              // 1-tick signal
               // syn_init_op_cntr<= syn_init_op_cntr + 5'b0_0001;
            end
            6'b10_0111: begin
               syn_init_datr   <= 12'h2_08;
               syn_init_we     <= 1'b1;              // 1-tick signal
               // syn_init_op_cntr<= syn_init_op_cntr + 5'b0_0001;
            end
            6'b10_1011: begin
//               syn_init_op_cntr<= 5'b1_1111;
            end
            6'b11_1111: begin
               syn_init_loading<= 1'b0;
            end
            default: begin
            end
            endcase  // End of case (syn_init_op_cntr)
         end  // End of if (syn_init_loading)

         if (syn_interOpGap) begin
            syn_interOpGap_cnt    <= syn_interOpGap_cnt + 5'b0_0001;
            if (syn_interOpGap_cnt == 5'b1_1111) begin
               syn_interOpGap     <= 1'b0;
               syn_interOpGap_cnt <= 5'b0_0000;
            end
         end


         // syn FIFO reads and shifting
         syn_fifo_rdr             <= syn_spi_ss_s;
         syn_fifo_rdrr            <= syn_fifo_rdr;
         syn_fifo_dator           <= syn_fifo_dato_w;
         if ( syn_fifo_rdr ) begin
            syn_ops_shftr         <= {3'b000, syn_fifo_dato_w[11:8], 1'b0,   syn_fifo_dato_w[7:0]};
            //                       |<- 7-bit full LTC6946 addr ->|<- Wn ->|<- LTC6946 Reg data ->|
         end
         else if (syn_spi_wtck) begin
            syn_ops_shftr         <= {syn_ops_shftr[14:0], 1'b0}; 
         end
         if ( syn_fifo_rdrr ) begin
            shftCnt               <= 5'b0_1111;
         end        
         if ( syn_spi_ss & syn_spi_wtck ) begin
            shftCnt               <= shftCnt - 6'b00_0001;
         end
         
         
         // SYN SPI State Machine: state-by-state case statement
         case (syn_spi_state)
         SYN_SPI_STATE_IDLE: begin
//            if (~syn_fifo_rdr | syn_init_loading | syn_interOpGap) begin
            if (~syn_fifo_rdr | syn_interOpGap) begin
               syn_spi_state      <= SYN_SPI_STATE_IDLE;
            end
            else begin
               syn_spi_state      <= SYN_SPI_STATE_CS0;
            end
         end //  End of SYN_SPI_STATE_IDLE: case.
         SYN_SPI_STATE_CS0: begin
            syn_spi_state         <= SYN_SPI_STATE_CS1;
         end //  End of SYN_SPI_STATE_CS0: case.
         SYN_SPI_STATE_CS1: begin
            if (~syn_spi_wtckr) begin
               syn_spi_state      <= SYN_SPI_STATE_CS1;
            end
            else begin
               syn_spi_state      <= SYN_SPI_STATE_SHF0;
            end
         end //  End of SYN_SPI_STATE_CS1: case.
         SYN_SPI_STATE_SHF0: begin
            if (!((syn_spi_wtck == 1'b1) && (shftCnt == 5'b0_0000))) begin
               syn_spi_state      <= SYN_SPI_STATE_SHF0;
            end
            else begin
               syn_spi_state      <= SYN_SPI_STATE_SHF1;
            end
         end //  End of SYN_SPI_STATE_SHF0: case.
         SYN_SPI_STATE_SHF1: begin
            syn_spi_state         <= SYN_SPI_STATE_IDLE;
            syn_interOpGap        <= 1'b1;
            if (syn_init_shfting) begin
               syn_init_done_cntr <= syn_init_done_cntr + 5'b0_0001; 
            end
         end //  End of SYN_SPI_STATE_SHF1: case.
         endcase //  End of case (syn_spi_state)
         
         if(syn_initing && (syn_init_done_cntr == 5'b0_1011)) begin
            syn_initing           <= 1'b0;
            syn_init_shfting      <= 1'b0;
            syn_initd             <= 1'b1;
            syn_mute_n_o          <= 1'b1; // Unmute
         end
         
      end  // End of always @(posedge clk_i)  ... SYN SPI State Machine ...
   end // End of always @(posedge clk_i)  
   

   assign  syn_fifo_full_o    = syn_fifo_full_w;
   assign  syn_fifo_empty_o   = syn_fifo_empty_w;
   assign  syn_spi_mosi_o     = syn_spi_ss ? syn_ops_shftr[15] : 1'b0;
   assign  syn_spi_sclk_o     = syn_spi_ss ? syn_spi_sclk : 1'b1; 
   assign  syn_spi_ss_n_o     = ~syn_spi_ss;
   
   assign  dbg0_o             = syn_spi_ss;
   assign  dbg1_o             = syn_ops_shftr[15];
   assign  dbg2_o             = syn_spi_sclk;
   assign  dbg3_o             = syn_initing;

endmodule

