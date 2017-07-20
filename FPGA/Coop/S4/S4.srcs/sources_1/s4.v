//------------------------------------------------------------------------------
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
// -----------------------------------------------------------------------------
// Company:         Ampleon
// Engineer:        Rick Rigby
// 
// Create Date:     03/23/2016 08:52:50 AM
// Design Name:     s4    [ top-level instance (for actual hardware) ]
// File Name:       s4.v
// Module Name:     s4
// Project Name:    Sango s4
// Target Devices:  xc7a35ticsg324-1L (debug Arty7)
//                  xc7a35tlftg256-2L (actual s4 HW)
// Tool Versions:   Vivado 2015.4 (RMR) & 2016.2 & 2016.4 (JLC)
// Description:     10ns CLK
//                  Previous versions of the s4 HDL were based on either simulation
//                  testbenches or the Digilent Arty7 evaluation board.  Beginning
//                  2017-Mar, s4.v refers to the actual hardware's top-level instance.
// 
// 
// 
// 
// 
//  ________          ________          ________          ________          ________          ________          ________          
// /        \________/        \________/        \________/        \________/        \________/        \________/        \________
//
//    BEGIN:  Hierarchy table    (JLC 03/17/2017 - 05/23/2017).
//
// Hierarchy:                                                         Scope:
// ----------------------------------------------------------------   -----------------------------------------------------------
//    s4.v                                                            (s4 )    
//        version.v                                                   (NOTE: included by most/every non-ip *.v)
// 
//        
//        mmc_tester                     mmc_test_pack.vhd            (s4 ....mmc_tester_0)
//          auto_baud_with_tracking      auto_baud_pack.vhd           (s4 ......auto_baud1)
//          async_syscon                 async_syscon_pack            (s4 ......syscon1)
//            uart_sqclk                 uart_sqclk_pack.vhd          (s4 ........uart1)
//            async_syscon               async_syscon_pack.vhd        (s4 ........syscon1)
//            flancters (various)        flancter_pack.vhd
//            flancter_rising_pulseout   mmc_test_pack.vhd            (s4 ......t_rx_gdcount_reset)  
//            flancter_rising_pulseout   mmc_test_pack.vhd            (s4 ......t_rx_crc_bdcount_reset)
//            flancter_rising_pulseout   mmc_test_pack.vhd            (s4 ......t_rx_stp_bdcount_reset)
//            flancter_rising_pulseout   mmc_test_pack.vhd            (s4 ......t_rx_dat_count_reset)
//            flancter_rising_pulseout   mmc_test_pack.vhd            (s4 ......reg_dbus_size_reset)
//            test_cmd_receiver          mmc_test_pack.vhd            (s4 ......mmc_test_cmd_rx)
//              ucrc_ser                 ucrc_pack.vhd                (s4 ........crc0)
//            dds_constant_squarewave    mmc_test_pack.vhd            (s4 ......tlm_1us_unit)
//            swiss_army_knife           mmc_test_pack.vhd            (s4 ......tlm_fifo_unit)
//            swiss_army_ram             fifo_pack.vhd                (s4 ......fifo_ram)
//            flancter_rising_pulseout   mmc_test_pack.vhd            (s4 ......tlm_start_pulser)
//            swiss_army_ram             mmc_test_pack.vhd            (s4 ......host_0_bram_0)
//            sd_controller_8bit_bram    mmc_test_pack.vhd            (s4 ......sd_host_0)
//              dds_squarewave           sd_host_pack.vhd             (s4 ........sd_clk_dds)
//              sd_cmd_host              sd_host_pack.vhd             (s4 ........cmd_host_0)
//                ucrc_ser               ucrc_pack.vhd                (s4 ........crc0)
//              sd_data_8bit_host        sd_host_pack.vhd             (s4 ........sd_data_host0)
//              edge_detector            sd_host_pack.vhd             (s4 ........cmd_int_rst_edge_detect)
//              edge_detector            sd_host_pack.vhd             (s4 ........data_int_rst_edge_detect)
//            mmc_data_pipe              mmc_test_pack.vhd            (s4 ......mmc_slave)
//              sd_card_emulator         sd_card_pack.vhd             (s4 ........mmc_1)
//              swiss_army_ram           sd_card_pack.vhd             (s4 ..........ext_csd_ram)
//              sd_card_cmd_rx           sd_card_pack.vhd             (s4 ..........cmd_receiver)
//                ucrc_ser               ucrc_pack.vhd                (s4 ............crc0)
//              sd_card_responder        sd_card_pack.vhd             (s4 ..........R1_responder)
//              sd_card_responder        sd_card_pack.vhd             (s4 ..........R2_CID_responder)
//              sd_card_responder        sd_card_pack.vhd             (s4 ..........R2_CSD_responder)
//              sd_card_responder        sd_card_pack.vhd             (s4 ..........R3_responder)
//              sd_card_responder        sd_card_pack.vhd             (s4 ..........R4_responder)
//              sd_card_data_unit        sd_card_pack.vhd             (s4 ..........sd_card_d_handler)
//            swiss_army_fifo_cdc        sd_card_pack.vhd             (s4 ........fifo_from_mmc)
//              swiss_army_ram           sd_card_pack.vhd             (s4 ..........fifo_ram)
//            swiss_army_fifo_cdc        sd_card_pack.vhd             (s4 ........fifo_to_mmc)
//              swiss_army_ram           sd_card_pack.vhd             (s4 ..........fifo_ram)
//            swiss_army_ram             sd_card_pack.vhd             (s4 ........pipe_ram)
//            swiss_army_fifo            mmc_test_pack.vhd            (s4 ......syn_spi_fifo)
//              swiss_army_ram           sd_card_pack.vhd             (s4 ..........fifo_ram)
//            spi                        mmc_test_pack.vhd            (s4 ......syn_spi)
//                                                                                  ^
//               NOTE: "Syn_spi"          is instantiated in mmc_test_pack.vhd -----+
//                      and is defined in spi_master.v.
//          
//        opcodes                        opcodes.v                    (s4 ......opcode_processor)
//
//        spix
//
//        hwdbg_uart                     uart.v                       (s4 ......hwuart)
//          
//          
//    END:    Hierarchy table    (JLC 03/17/2017 - 05/23/2017).
//
//  ________          ________          ________          ________          ________          ________          ________          
// /        \________/        \________/        \________/        \________/        \________/        \________/        \________
//
// 
// 
// Revision 0.00.1  early/2016 RMR File Created
// Revision 0.00.1  08/24/2016 JLC Included in debug repository w/ visual changes.
// Revision 1.00.1  03/07/2017 JLC Began converting from tb_arty.v/arty_main.v to initial S4 board (s4.v).
// Revision 1.00.1  04/11/2017 JLC Cont'd by adding HW debug UART.
// Revision 1.00.2  04/25/2017 JLC Updated mmc_tester w/ RMR's dbg_spi_* and DBG_enables interface.
// Revision 1.00.3  05/23/2017 JLC Updated mmc_tester w/ RMR's dbg_spi_* and DBG_enables interface.
// Revision 1.00.3  06/12/2017 JLC Updated mmc_tester w/ RMR's dbg_spi_* and DBG_enables interface.
// Revision 1.00.4  06/13/2017 JLC Updated HW debug UART (256 bit ctl r/w bus).
// Revision 1.00.5  06/28/2017 JLC Reinplemented `define JLC_TEMP_NO_MMCM.
//
// Additional Comments: General structure/sequence:
//   Fifo's at top level for: opcodes and opcode processor output
//   such as frequency, power, bias, phase, pulse, etc.
//
//   Processor modules for each item, frequency, power, phase, etc
//   will process their respective fifo data and generate SPI data
//   to be sent to hardware.
//
//   Each SPI device has its own SPI interface fifo at top level. 
//   SPI data is written by opcode processor into the correct SPI fifo.
//
//
//   13-Jul Debugging note. The fifo_count shown while simulating takes one
//   extra clock tick to show.   
// 
// -----------------------------------------------------------------------------

`include "version.v"
`include "status.h"
`include "timescale.v"

// -----------------------------------------------------------------------------
// `define's
// -----------------------------------------------------------------------------

// >>>>> John Clayton's `define's <<<<<
// 
/*
`define ENTRIES         16
`define MMC_SECTOR_SIZE 512

// For displaying output with LED's. 50MHz clock
`define MS750      750000000/20     // 750e6 NS/Period = 750ms
`define MS250      250000000/20     // 250 ms
`define MS500      500000000/20     // 500 ms
// Flash 16-bits using 4 led'S every 5 seconds
`define MS2000     2000000000/20    // 2 seconds 
`define MS2500     2500000000/20    // 2.5 seconds 
`define MS3000     3000000000/20    // 3 seconds 
`define MS3500     3500000000/20    // 3.5 seconds 

`define MS5000     250000000        // 5 seconds

`define US150      150000/20        // 150 us
`define MS001      1500000/20       // 1.5ms 
*/

// >>>>> Coop's `define's <<<<<
// 
`define JLC_TEMP_NO_MMCM 1             // 1 -> Don't use MMCME2_BASE; Use 100MHz straight in.  0 -> Use MMCME2_BASE.
`define JLC_TEMP_NO_L12 1              // Temp workaround depop'd L12. JLC 03/17/2017    JLC_TEMP_NO_L12> (causes <JLC_TEMP_CLK>)
`define JLC_TEMP_CLK 1                 //  "       "        "      "                     JLC_TEMP_CLK
`define GLBL_CLK_FREQ_BRD 100000000.0  //  "       "        "      "                     JLC_TEMP_CLK
`define GLBL_CLK_FREQ_MCU 102000000.0  //  "       "        "      "                     JLC_TEMP_CLK
`define CLKFB_FACTOR_BRD 10.000        //  "       "        "      "                     JLC_TEMP_CLK
`define CLKFB_FACTOR_MCU 9.800         //  "       "        "      "                     JLC_TEMP_CLK
`define GLBL_MMC_FILL_LEVEL_BITS 16
`define GLBL_RSP_FILL_LEVEL_BITS 10
`define PWR_FIFO_FILL_BITS       4

// -----------------------------------------------------------------------------

module s4  
(
  // commented out as per <JLC_TEMP_NO_L12> and <JLC_TEMP_CLK>
  //input              FPGA_CLK,           //  P10   I        + Diff FPGA CLK From S4 Board U34/Si53307
  //input              FPGA_CLKn,          //  N10   I        - and A3/100MHx Oscillator can.
  output             ACTIVE_LEDn,        //  T14   O       

  inout              MMC_CLK,            //  N11   I        MCU<-->MMC-Slave I/F
  output             MMC_IRQn,           //  P8    O        MCU SDIO_SD pin; low=MMC_Card_Present.
  inout              MMC_CMD,            //  R7    I       

  inout              MMC_DAT7,           //  R6    IO      
  inout              MMC_DAT6,           //  T5    IO      
  inout              MMC_DAT5,           //  T10   IO      
  inout              MMC_DAT4,           //  T9    IO      
  inout              MMC_DAT3,           //  T8    IO      
  inout              MMC_DAT2,           //  T7    IO      
  inout              MMC_DAT1,           //  R8    IO      
  inout              MMC_DAT0,           //  P8    IO      

  output             TRIG_OUT,           //  M16   O       
  input              TRIG_IN,            //  N13   I  

  output             FPGA_TXD,           //  N16   O        MMC UART
  input              FPGA_RXD,           //  P15   I        MMC UART

                                         //     FPGA_MCLK is temporarily 102MHz LVCMOS33 FPGA Clk Input.  <JLC_TEMP_NO_L12>
  input              FPGA_MCLK,          //  R13   I                       
                                         //     FPGA_M*   is HW DBG I/F
  input              FPGA_MCU1,          //  P10   I 
  output             FPGA_MCU2,          //  P11   O
  output             FPGA_MCU3,          //  R12   O    
  output             FPGA_MCU4,          //  R13   O        
  input              MCU_TRIG,           //  T13   I       

  output             VGA_MOSI,           //  B7    O        RF Power Setting SPI
  output             VGA_SCLK,           //  B6    O        I/F
  output             VGA_SSn,            //  B5    O       
  output             VGA_VSW,            //  A5    O       
  output             VGA_VSWn,           //  A3    O       

  output             SYN_MOSI,           //  B2    O        LTC6946 RF Synth SPI I/F
  input              SYN_MISO,           //  A2    I       
  output             SYN_SCLK,           //  C1    O       
  output             SYN_SSn,            //  C1    O
  input              SYN_STAT,           //  B1    O
  output             SYN_MUTE,           //  E2    O

  output             DDS_MOSI,           //  F2    O        AD9954 DDS SPI+ I/F
  input              DDS_MISO,           //  E1    I
  output             DDS_SSn,            //  G2    O
  output             DDS_SCLK,           //  G1    O       
  output             DDS_IORST,          //  H2    O       
  output             DDS_IOUP,           //  H1    O       
  output             DDS_SYNC,           //  K1    O
  output             DDS_PS0,            //  J1    O
  output             DDS_PS1,            //  L2    O

  output             RF_GATE,            //  C2    O        RF On/Off Keying/Biasing
  output             RF_GATE2,           //  C3    O       
  output             DRV_BIAS_EN,        //  A3    O                 
  output             PA_BIAS_EN,         //  K2    O                 

  output             ZMON_EN,            //  T2    O        ZMon SPI Cnvrt & Read I/F
  output             CONV,               //  M1    O
  output             ADC_SCLK,           //  R1    O
  input              ADCF_SDO,           //  N1    I
  input              ADCR_SDO,           //  P1    I
  input              ADCTRIG,            //  T12   I        CPU ZMon Req

  output             FPGA_TXD2,          //  R11   O        HW DBG UART
  input              FPGA_RXD2           //  R10   I        HW DBG UART
);

//----------------------------------------------------------------------------------------------

// Local signals
wire         clk_diff_rcvd;
wire         clkin;
wire         clkfbprebufg;
wire         clk100prebufg;
wire         clk200prebufg;
wire         clk050prebufg;
wire         clkfb;
wire         clk100;
wire         clk200;
wire         clk050;

// The current system state:
wire [15:0]   frequency;
reg  [11:0]  dbm_x10;

//// Initialize ourselves at startup
//wire        initialized = 1'b0;
//reg  [3:0]  init_clks = 4'd10; 

// Use 0x4000 if dbg_enables to turn ON SPI debugger mode
// Otherwise SPI outputs are driven by various processor modules
wire         dbg_spi_mode;

// <JLC_TEMP_RST>
wire         dbg_sys_rst_i;
reg  [9:0]   dbg_sys_rst_sr   = 0; //10'b0;
reg          dbg_sys_rst_n    = 1'b1;

// <JLC_TEMP_DBG>
reg  [39:0]  count1;
reg  [25:0]  count2;
reg          count2tc = 1'b0;
reg  [15:0]  count3;
reg  [15:0]  count4;

wire         sys_clk;
wire         sys_rst_n;
wire         mmcm_rst_i;
wire         mmcm_pwrdn_i;
wire         mmcm_locked_o;

// MMC tester
wire         mmc_clk;
wire         mmc_clk_oe;
wire         mmc_cmd;
wire         mmc_cmd_oe;
wire         mmc_cmd_zzz;
wire         mmc_cmd_choice;
wire  [7:0]  mmc_dat;
wire  [7:0]  mmc_dat_zzz;
wire  [7:0]  mmc_dat_choice1;
wire  [7:0]  mmc_dat_choice2;
reg   [7:0]  mmc_dat_choice3;
wire         mmc_od_mode;
wire         mmc_dat_oe;
wire  [1:0]  mmc_dat_siz;
wire         mmc_tlm;

// MMC card I/O proxy signals
wire  [7:0]  MMC_DAT_i;

// Backside HW signals  
wire [255:0] tdbgw;
reg  [255:0] tdbgr;

wire         syscon_rxd;
wire         syscon_txd;

// 12-Jul LPC MMC interface is not working so we must use 
// MMC UART back door from mmc_tester debugger
// to receive opcodes & send responses
// Use 16 32-bit words to transfer 64 byte opcode blocks
wire            opc_load_new;       // Load new opcode block into opcode fifo, from mmc_tester
reg             opc_load_ack;       // Done loading opcodes block
wire [31:0]     opc_dat0;
wire [31:0]     opc_dat1;
wire [31:0]     opc_dat2;
wire [31:0]     opc_dat3;
wire [31:0]     opc_dat4;
wire [31:0]     opc_dat5;
wire [31:0]     opc_dat6;
wire [31:0]     opc_dat7;
wire [31:0]     opc_dat8;
wire [31:0]     opc_dat9;
wire [31:0]     opc_datA;
wire [31:0]     opc_datB;
wire [31:0]     opc_datC;
wire [31:0]     opc_datD;
wire [31:0]     opc_datE;
wire [31:0]     opc_datF;
reg  [31:0]     opc_inreg;          // Mux'd above 16 wires
// same for the opcode processor response, goes through mmc_tester debug uart
reg             opc_rsp_new;       // Send opcode response block to mmc_tester uart
wire            opc_rsp_ack;       // Done sending response
reg  [31:0]     opc_rsp0;
reg  [31:0]     opc_rsp1;
reg  [31:0]     opc_rsp2;
reg  [31:0]     opc_rsp3;
reg  [31:0]     opc_rsp4;
reg  [31:0]     opc_rsp5;
reg  [31:0]     opc_rsp6;
reg  [31:0]     opc_rsp7;
reg  [31:0]     opc_rsp8;
reg  [31:0]     opc_rsp9;
reg  [31:0]     opc_rspA;
reg  [31:0]     opc_rspB;
reg  [31:0]     opc_rspC;
reg  [31:0]     opc_rspD;
reg  [31:0]     opc_rspE;
reg  [31:0]     opc_rspF;
reg  [31:0]     opc_outreg;         // Mux'd above 16 response wires

// opcode processor wires:
reg          opc_enable;                // control needed...      
wire         opc_fifo_enable;           // enable opcode processor in & out fifo's
wire         opc_fifo_rst;              // reset for opcode processor fifo's
reg  [7:0]   opc_fifo_dat_i;            // mmc_tester opcode fifo writes can go here
reg          opc_fifo_wen;              // opcode fifo write line
wire         opc_fifo_mt;               // opcode fifo empty flag
wire [`GLBL_RSP_FILL_LEVEL_BITS-1:0] opc_fifo_count;   // opcode fifo fill level
wire [7:0]   opc_fifo_dat_o;            // opcode processor reads from here
wire         opc_fifo_ren;              // opcode fifo read line 
wire         opc_fifo_full;             // used?

wire [15:0]  opc_sys_st_w;            // s4 system state (e.g. running a pattern)
wire [31:0]  opc_mode_w;              // MODE opcode can set system-wide flags

wire [7:0]   opc_rspf_w;              // to fifo, response bytes(status, measurements, echo, etc)
wire         opc_rspf_wen;            // response fifo write enable
wire         opc_rspf_mt;             // response fifo empty flag
wire         opc_rspf_fl;             // response fifo full  flag
wire         opc_rspf_rdy;            // response fifo is waiting
reg          opc_rspf_ren;            // response fifo read enable
wire [7:0]   opc_rspf_dat_o;          // response fifo output data, used to generate response block
wire [`GLBL_RSP_FILL_LEVEL_BITS-1:0] opc_rsp_lng;    // update response length when response is ready
wire [`GLBL_RSP_FILL_LEVEL_BITS-1:0] opc_rsp_cnt;    // response fifo count, opcode processor asserts 

// Frequency processor wires
wire [31:0]  frq_fifo_dat_i;          // to fifo from opc, frequency output in MHz
wire         frq_fifo_wen;            // frequency fifo write enable
wire [31:0]  frq_fifo_dat_o;          // to frequency processor
wire         frq_fifo_ren;            // frequency fifo read enable
wire         frq_fifo_mt;             // frequency fifo empty flag
wire         frq_fifo_full;           // frequency fifo full flag
wire [5:0]   frq_fifo_count;
wire [31:0]  ft_bytes;                // frequency tuning word SPI bytes for DDS SPI
wire [7:0]   frq_status;              // frequency processor status

// Power processor wires
wire [38:0] pwr_fifo_dat_i;          // to fifo from opc, power or cal value. 
                                      // Upper 7 bits are opcode, cal or user power
wire        pwr_fifo_wen;            // power fifo write enable
wire [38:0] pwr_fifo_dat_o;          // to power processor
wire        pwr_fifo_ren;            // power fifo read enable
wire        pwr_fifo_mt;             // power fifo empty flag
wire        pwr_fifo_full;           // power fifo full flag
wire [7:0]  pwr_status;              // power processor status
wire [`PWR_FIFO_FILL_BITS-1:0]   pwr_fifo_count;
// power processor outputs, mux'd to main outputs
wire        pwr_mosi;
wire        pwr_sclk;
wire        pwr_ssn;       
wire        pwr_vsw;       

// Bias enable wire
wire         bias_en;                  // bias control

// pattern opcodes are saved in pattern RAM.
wire         ptn_wr_en_w;             // opcode processor saves pattern opcodes to pattern RAM 
wire [15:0]  ptn_addr_w;              // address 
wire [95:0]  ptn_data_w;              // 12 bytes, 3 bytes patClk tick, 9 bytes for opcode, length, and data   
wire         ptn_processor_en_w;      // Run pattern processor 
wire [15:0]  ptn_start_addr_w;        // address 

wire [31:0]  opc_count;               // count opcodes for status info                     
wire [7:0]   opc_status;              // NULL opcode terminates, done=0, or error code
wire [6:0]   opc_state;               // For debugging
    
//    // Debugging
wire [7:0]   last_opcode;
//wire [15:0]  last_length_w;

// SPI debugging connections for w 03000030 command
// Write up to 14 byte to SPI device
wire [7:0]   arr_spi_bytes [13:0];
wire [3:0]   dbg_spi_bytes;      // bytes to send
reg  [3:0]   dbg_spi_count;      // down counter
wire         dbg_spi_start;
wire         dbg_spi_busy;
reg          dbg_spi_done;
wire [2:0]   dbg_spi_device;       // 1=VGA, 2=SYN, 3=DDS, 4=ZMON
wire [15:0]  dbg_enables; // = 1'b0;          // toggle various enables/wires

// 11-Jul HWDBG UART work, opc connected to mmc_tester 12-Jul
//   wire                   opc_fifo_wr_en;    // ZZM wr enable to opcode input fifo.
//   wire                   opc_fifo_rd_en;    // ZZM
//   //wire [7:0]             opc_fifo_dat_i;    // ZZM
//   wire [7:0]             opc_fifo_dat_o;    // ZZM
//   reg                    opc_fifo_wr_enr;   // ZZM
//   reg                    opc_fifo_wr_enrr;  // ZZM
//   reg                    opc_fifo_rd_enr;   // ZZM
//   reg                    opc_fifo_rd_enrr;  // ZZM
//   //wire [9:0]             opcode_fifo_count; // ZZM
//   wire                   opcode_fifo_empty; // ZZM
//   wire                   extd_fifo_wr_stb_w;// ZZM

//------------------------------------------------------------------------
// Start of logic

assign  mmcm_rst_i    = 1'b0;
assign  mmcm_pwrdn_i  = 1'b0;

// ******************************************************************************
// *  SYSTEM CLOCKS:                                                            *
// *  -------------                                                             *
// *                                                                            *
// *    External:                                                               *
// *    --------                                                                *
// *      FPGA_CLK / FPGA_CLKn = 100MHz Diff-Pair from Si514                    *
// *      FPGA_MCLK            = 102MHz from LP43S57 / MCU                      *
// *                                                                            *
// *    Internal:                                                               *
// *    --------                                                                *
// *      clkin      output of BUFG instance: "BUFG_clkin"                      *
// *      sys_clk    100 MHz FPGA-wide clock.                                   *
// *      clk200     200 MHz FPGA-wide clock.                                   *
// *      clk100     100 MHz FPGA-wide clock.                                   *
// *      clk050      50 MHz FPGA-wide clock.                                   *
// *                                                                            *
// *                                                                            *
// ******************************************************************************
//

// Following MMCME2_BASE instantiation snarfed & modified from:
//   MMCME2_BASE: Base Mixed Mode Clock Manager
//   7 Series
//   Xilinx HDL Libraries Guide, version 14.7
//     7-Series 2016.4 ug768 (HDL Libs, etc.) pp. 302-307    &
//     7-Series 2016.4 ug472 (Clocking)       pp.  65- 94
//
// From Artix-7 DC/AC Characteristics DS181:
//   MMCM_Fvcomin =  600MHz
//   MMCM_Fvcomax = 1440MHz
//   Arithmetic Average = 1022MHz
//   Geometric  Average =  930MHz
//   So, use    Fpfd    = 1000MHz (= 1GHz)
//
//

//  <JLC_TEMP_NO_MMCM>
`ifndef JLC_TEMP_NO_MMCM
MMCME2_BASE #(
  .BANDWIDTH("OPTIMIZED"), // Jitter programming (OPTIMIZED, HIGH, LOW)
  .CLKFBOUT_MULT_F(`CLKFB_FACTOR_MCU),  // Multiply value for all CLKOUT (2.000-64.000)   = Fpfd/Fclkin1  <JLC_TEMP_CLK>
  .CLKFBOUT_PHASE(0.000),  // Phase offset in degrees of CLKFB (-360.000-360.000).
  .CLKIN1_PERIOD(9.800),  // Input clock period in ns to ps resolution (i.e. 33.333 is 30 MHz).           <JLC_TEMP_CLK>
  // CLKOUT0_DIVIDE - CLKOUT6_DIVIDE: Divide amount for each CLKOUT (1-128)
  .CLKOUT0_DIVIDE_F(10),   // 1000MHz / 10.0 = 100MHz  Divide amount for CLKOUT0 (1.000-128.000).
  .CLKOUT1_DIVIDE(5),      // 1000MHz /  5.0 = 200MHz
  .CLKOUT2_DIVIDE(20),     // 1000MHz / 20.0 =  50MHz
  .CLKOUT3_DIVIDE(1),
  .CLKOUT4_DIVIDE(1),
  .CLKOUT5_DIVIDE(1),
  .CLKOUT6_DIVIDE(1),
  // CLKOUT0_DUTY_CYCLE - CLKOUT6_DUTY_CYCLE: Duty cycle for each CLKOUT (0.01-0.99).
  .CLKOUT0_DUTY_CYCLE(0.50),
  .CLKOUT1_DUTY_CYCLE(0.50),
  .CLKOUT2_DUTY_CYCLE(0.50),
  .CLKOUT3_DUTY_CYCLE(0.50),
  .CLKOUT4_DUTY_CYCLE(0.50),
  .CLKOUT5_DUTY_CYCLE(0.50),
  .CLKOUT6_DUTY_CYCLE(0.50),
  // CLKOUT0_PHASE - CLKOUT6_PHASE: Phase offset for each CLKOUT (-360.000-360.000).
  .CLKOUT0_PHASE(0.000),
  .CLKOUT1_PHASE(0.000),
  .CLKOUT2_PHASE(0.000),
  .CLKOUT3_PHASE(0.000),
  .CLKOUT4_PHASE(0.000),
  .CLKOUT5_PHASE(0.000),
  .CLKOUT6_PHASE(0.000),
  .CLKOUT4_CASCADE("FALSE"), // Cascade CLKOUT4 counter with CLKOUT6 (FALSE, TRUE)
  .DIVCLK_DIVIDE(1),         // Master division value (1-106):   Fpfd = CLKIN1/DIVCLK_DIVIDE.
  .REF_JITTER1(0.010),       // Reference input jitter in UI (0.000-0.999).
  .STARTUP_WAIT("FALSE")     // Delays DONE until MMCM is locked (FALSE, TRUE)
)
MMCME2_BASE_inst (
  // Clock Outputs: 1-bit (each) output: User configurable clock outputs
  .CLKOUT0(clk100prebufg), // 1-bit output: CLKOUT0
  .CLKOUT0B(), // 1-bit output: Inverted CLKOUT0
  .CLKOUT1(clk200prebufg), // 1-bit output: CLKOUT1
  .CLKOUT1B(), // 1-bit output: Inverted CLKOUT1
  .CLKOUT2(clk050prebufg), // 1-bit output: CLKOUT2
  .CLKOUT2B(), // 1-bit output: Inverted CLKOUT2
  .CLKOUT3(), // 1-bit output: CLKOUT3
  .CLKOUT3B(), // 1-bit output: Inverted CLKOUT3
  .CLKOUT4(), // 1-bit output: CLKOUT4
  .CLKOUT5(), // 1-bit output: CLKOUT5
  .CLKOUT6(), // 1-bit output: CLKOUT6
  // Feedback Clocks: 1-bit (each) output: Clock feedback ports
  .CLKFBOUT(clkfbprebufg), // 1-bit output: Feedback clock
  .CLKFBOUTB(), // 1-bit output: Inverted CLKFBOUT
  // Status Ports: 1-bit (each) output: MMCM status ports
  .LOCKED(mmcm_locked_o), // 1-bit output: LOCK
  // Clock Inputs: 1-bit (each) input: Clock input
  .CLKIN1(clkin), // 1-bit input: Clock
  // Control Ports: 1-bit (each) input: MMCM control ports
  .PWRDWN(mmcm_pwrdn_i), // 1-bit input: Power-down
  .RST(mmcm_rst_i), // 1-bit input: Reset
  // Feedback Clocks: 1-bit (each) input: Clock feedback ports
  .CLKFBIN(clkfb) // 1-bit input: Feedback clock
);
// End of MMCME2_BASE_inst instantiation

  BUFG BUFG_clkfb  (.I(clkfbprebufg),  .O(clkfb));
  BUFG BUFG_clk100 (.I(clk100prebufg), .O(clk100));
  BUFG BUFG_clk200 (.I(clk200prebufg), .O(clk200));
  BUFG BUFG_clk050 (.I(clk050prebufg), .O(clk050));
  assign sys_clk   = clk100;
`else
  assign sys_clk   = clkin;
`endif

//  <JLC_TEMP_NO_L12>
`ifndef JLC_TEMP_NO_L12
  IBUFGDS IBUFGDS_clkin  (.I(FPGA_CLK), .IB(FPGA_CLKn), .O(clk_diff_rcvd));
  BUFG BUFG_clkin  (.I(clk_diff_rcvd),    .O(clkin));
`else
  BUFG BUFG_clkin  (.I(FPGA_MCLK),   .O(clkin));
`endif

// Create a "hwdbg dbg_sys_rst_n" synchronous self-timed pulse. <JLC_TEMP_RST>
always @(posedge sys_clk)
begin
  dbg_sys_rst_sr <= {dbg_sys_rst_sr[8:0], dbg_sys_rst_i};
  dbg_sys_rst_n <= !(&{!dbg_sys_rst_sr[9], | dbg_sys_rst_sr[8:0]});  // output 9 ticks of dbg_sys_rst_n == 1'b0.
end

assign sys_rst_n = MCU_TRIG ? 1'b0 : dbg_sys_rst_n;

/////////////////////////////////////////////////////////
// Important system globals & assignments              //
/////////////////////////////////////////////////////////
assign opc_fifo_enable = 1'b1;
assign opc_fifo_rst = 1'b0;

// Create a "time-alive" counter.
//   2^40 @ 100MHz wraps at ~3.05 hours.
//
always @(posedge sys_clk)
  if (!sys_rst_n) begin
    count1 <= 0;
  end
  else begin
    count1 <= count1+1;
  end


// Create a "blink" counter.
//   2^26 @ 100MHz wraps at ~1.5  seconds.
//   2^40 @ 100MHz wraps at ~3.05 hours.
//
always @(posedge sys_clk)
  if (!sys_rst_n) begin
    count2     <= 0;
    count2tc   <= 1'b0;
  end
  else begin
    count2     <= count2+1;
    count2tc   <= (count2 == 26'h3FFFFFF);
  end


// Create another "blink" counter (16-bit).
//   2^16 @ 200MHz wraps at ~0.328 us.
//
always @(posedge clk200)
  if (!sys_rst_n) begin
    count3 <= 16'h0000;
  end
  else begin
    count3 <= count3+1;
  end


// Create another "blink" counter (16-bit).
//   2^16 @ 50MHz wraps at ~1.311 ms.
//
always @(posedge clk050)
  if (!sys_rst_n) begin
    count4 <= 16'h0000;
  end
  else begin
    count4 <= count4+1;
  end

// Initialize things at startup
always @(posedge sys_clk) begin
//  if (!initialized) begin


 // end
end

  // Instantiate VHDL fifo that mmc_tester instance 
  // is using to store opcodes (opcode processor input fifo)
  swiss_army_fifo #(
    .USE_BRAM(1),           // BRAM=1 requires 1 extra clock before read data is ready
    .WIDTH(8),
    .DEPTH(512),
    .FILL_LEVEL_BITS(10),
    .PF_FULL_POINT(511),
    .PF_FLAG_POINT(256),
    .PF_EMPTY_POINT(1)
  ) input_opcodes(
      .sys_rst_n(sys_rst_n),
      .sys_clk(sys_clk),
      .sys_clk_en(opc_fifo_enable),
        
      .reset_i(opc_fifo_rst),
        
      .fifo_wr_i(opc_fifo_wen),
      .fifo_din(opc_fifo_dat_i),
        
      .fifo_rd_i(opc_fifo_ren),
      .fifo_dout(opc_fifo_dat_o),
        
      .fifo_fill_level(opc_fifo_count),
      .fifo_full(opc_fifo_full),
      .fifo_empty(opc_fifo_mt),
      .fifo_pf_full(),
      .fifo_pf_flag(),
      .fifo_pf_empty()           
  );

  // Instantiate VHDL fifo that opcode processor instance 
  // is using to store responses (opcode processor output fifo)
    //////////////////////////////////////////////
  // The response to all opcodes will be 
  // written to this fifo. This fifo will be
  // used for status, echo, and measurement
  // opcodes.
  swiss_army_fifo #(
    .USE_BRAM(1),               // BRAM=1 requires 1 extra clock before read data is ready
    .WIDTH(8),
    .DEPTH(512),
    .FILL_LEVEL_BITS(10),
    .PF_FULL_POINT(511),
    .PF_FLAG_POINT(256),
    .PF_EMPTY_POINT(1)
  ) opcode_response(
      .sys_rst_n(sys_rst_n),
      .sys_clk(sys_clk),
      .sys_clk_en(opc_fifo_enable),
      
      .reset_i(opc_fifo_rst),
      
      .fifo_wr_i(opc_rspf_wen),                 // response fifo write enable
      .fifo_din(opc_rspf_w),                    // to fifo, response bytes(status, measurements, echo, etc)
      
      .fifo_rd_i(opc_rspf_ren),                 // response fifo read enable
      .fifo_dout(opc_rspf_dat_o),               // response fifo output data, used to generate response block
      
      .fifo_fill_level(opc_rsp_cnt),            // response fifo count
      .fifo_full(opc_rspf_fl),                  // response fifo full  flag
      .fifo_empty(opc_rspf_mt),                 // response fifo empty flag
      .fifo_pf_full(),
      .fifo_pf_flag(),
      .fifo_pf_empty()           
  );


///////////////////////////////////////////////////////////////////////
// Frequency FIFO
// variables for frequency FIFO, written by opcode processor, 
// read by frequency processor module
///////////////////////////////////////////////////////////////////////
  // Instantiate fifo that the opcode processor is using to store frequencies
  swiss_army_fifo #(
    .USE_BRAM(1),
    .WIDTH(32),
    .DEPTH(64),
    .FILL_LEVEL_BITS(6),
    .PF_FULL_POINT(63),
    .PF_FLAG_POINT(32),
    .PF_EMPTY_POINT(1)
  ) freq_fifo(
    .sys_rst_n(sys_rst_n),
    .sys_clk(sys_clk),
    .sys_clk_en(opc_fifo_enable),
        
    .reset_i(opc_fifo_rst),
        
    .fifo_wr_i(frq_fifo_wen),
    .fifo_din(frq_fifo_dat_i),
        
    .fifo_rd_i(frq_fifo_ren),
    .fifo_dout(frq_fifo_dat_o),
        
    .fifo_fill_level(frq_fifo_count),
    .fifo_full(frq_fifo_full),
    .fifo_empty(frq_fifo_mt),
    .fifo_pf_full(),
    .fifo_pf_flag(),
    .fifo_pf_empty()           
  );
              
  ///////////////////////////////////////////////////////////////////////
  // Power FIFO
  // variables for power FIFO, written by opcode processor, 
  // read by power processor module
  // opcode is written in upper 7 bits so power processsor knows
  // if it's user power opcode or cal opcode
  ///////////////////////////////////////////////////////////////////////
    // Instantiate fifo that the opcode processor is using to store power values
    swiss_army_fifo #(
      .USE_BRAM(1),
      .WIDTH(39),
      .DEPTH(16),
      .FILL_LEVEL_BITS(`PWR_FIFO_FILL_BITS),
      .PF_FULL_POINT(15),
      .PF_FLAG_POINT(8),
      .PF_EMPTY_POINT(1)
    ) pwr_fifo(
      .sys_rst_n(sys_rst_n),
      .sys_clk(sys_clk),
      .sys_clk_en(opc_fifo_enable),
          
      .reset_i(opc_fifo_rst),
          
      .fifo_wr_i(pwr_fifo_wen),
      .fifo_din(pwr_fifo_dat_i),
          
      .fifo_rd_i(pwr_fifo_ren),
      .fifo_dout(pwr_fifo_dat_o),
          
      .fifo_fill_level(pwr_fifo_count),
      .fifo_full(pwr_fifo_full),
      .fifo_empty(pwr_fifo_mt),
      .fifo_pf_full(),
      .fifo_pf_flag(),
      .fifo_pf_empty()           
    );
                
                
// ******************************************************************************
// *                                                                            *
// *  mmc_tester:  The MMC Slave + Related Debug/Test HW                        *
// *                                                                            *
// ******************************************************************************
  mmc_tester #(
    .SYS_CLK_RATE         (`GLBL_CLK_FREQ_MCU),
    .SYS_LEDS             (16),    // <TBD> Eventually these need to go away.
    .SYS_SWITCHES         (8),     // <TBD> Eventually these need to go away.
    .EXT_CSD_INIT_FILE    ("ext_csd_init.txt"), // Initial contents of EXT_CSD
    .HOST_RAM_ADR_BITS    (14), // Determines amount of BRAM in MMC host
    .MMC_FIFO_DEPTH       (65536), // (2048),
    .MMC_FILL_LEVEL_BITS  (`GLBL_MMC_FILL_LEVEL_BITS),    // (16),
    .RSP_FILL_LEVEL_BITS  (`GLBL_RSP_FILL_LEVEL_BITS),    // (10),
    .MMC_RAM_ADR_BITS     (9)      // 512 bytes, 1st sector (17)
  ) mmc_tester_0 (

    // Asynchronous reset
    .sys_rst_n         (sys_rst_n),
    .sys_clk           (sys_clk),

    // Asynchronous serial interface
    .cmd_i             (syscon_rxd),
    .resp_o            (syscon_txd),

    // Board related
    .switch_i           (),
    .led_o             (),

    // Interface for SD/MMC traffic logging
    // via asynchronous serial transmission
    .tlm_send_i        (1'b0),
    .tlm_o             (mmc_tlm),

    // Tester Function Enables
    .slave_en_i        (1'b1),
`ifdef XILINX_SIMULATOR
    .host_en_i         (1'b1),
`else
    .host_en_i         (1'b0),
`endif

    // SD/MMC card signals
    .mmc_clk_i         (MMC_CLK),
    .mmc_clk_o         (mmc_clk),
    .mmc_clk_oe_o      (mmc_clk_oe),
    .mmc_cmd_i         (MMC_CMD),
    .mmc_cmd_o         (mmc_cmd),
    .mmc_cmd_oe_o      (mmc_cmd_oe),
    .mmc_dat_i         (MMC_DAT_i),
    .mmc_dat_o         (mmc_dat),
    .mmc_dat_oe_o      (mmc_dat_oe),
    .mmc_od_mode_o     (mmc_od_mode),  // open drain mode, applies to sd_cmd_o and sd_dat_o
    .mmc_dat_siz_o     (mmc_dat_siz),
    
    // 31-Mar RMR added a crapload of debug signals
    // signals for spi debug data written to MMC debug terminal (03000030 X Y Z...)
    .dbg_spi_data0_o    (arr_spi_bytes[0]),
    .dbg_spi_data1_o    (arr_spi_bytes[1]),
    .dbg_spi_data2_o    (arr_spi_bytes[2]),
    .dbg_spi_data3_o    (arr_spi_bytes[3]),
    .dbg_spi_data4_o    (arr_spi_bytes[4]),
    .dbg_spi_data5_o    (arr_spi_bytes[5]),
    .dbg_spi_data6_o    (arr_spi_bytes[6]),
    .dbg_spi_data7_o    (arr_spi_bytes[7]),
    .dbg_spi_data8_o    (arr_spi_bytes[8]),
    .dbg_spi_data9_o    (arr_spi_bytes[9]),
    .dbg_spi_dataA_o    (arr_spi_bytes[10]),
    .dbg_spi_dataB_o    (arr_spi_bytes[11]),
    .dbg_spi_dataC_o    (arr_spi_bytes[12]),
    .dbg_spi_dataD_o    (arr_spi_bytes[13]),
    .dbg_spi_bytes_io   (dbg_spi_bytes),
    .dbg_spi_start_o    (dbg_spi_start),
    .dbg_spi_device_o   (dbg_spi_device),   // 1=VGA, 2=SYN, 3=DDS, 4=ZMON
    .dbg_spi_busy_i     (dbg_spi_busy),     // asserted while top processes SPI bytes
    .dbg_enables_o      (dbg_enables),
    
    // opcode_processor (instantiation of opcodes module) refactored to top level (arty_main.v or s4.v).
    // connect the mmc fifo's to the opcode processor here.
    // 12-Jul first article must use back-door UART entry since LPC MMC interface is not working
    .bkd_opc_load_new   (opc_load_new),
    .bkd_opc_load_ack   (opc_load_ack),
    .bkd_opc_dat0_o    (opc_dat0),
    .bkd_opc_dat1_o    (opc_dat1),
    .bkd_opc_dat2_o    (opc_dat2),
    .bkd_opc_dat3_o    (opc_dat3),
    .bkd_opc_dat4_o    (opc_dat4),
    .bkd_opc_dat5_o    (opc_dat5),
    .bkd_opc_dat6_o    (opc_dat6),
    .bkd_opc_dat7_o    (opc_dat7),
    .bkd_opc_dat8_o    (opc_dat8),
    .bkd_opc_dat9_o    (opc_dat9),
    .bkd_opc_datA_o    (opc_datA),
    .bkd_opc_datB_o    (opc_datB),
    .bkd_opc_datC_o    (opc_datC),
    .bkd_opc_datD_o    (opc_datD),
    .bkd_opc_datE_o    (opc_datE),
    .bkd_opc_datF_o    (opc_datF),

    .bkd_rsp_i          (opc_rsp_new),       // Send opcode response block to mmc_tester uart
    .bkd_rsp_ack_o      (opc_rsp_ack),       // Done sending response
    .bkd_rsp_dat0_i     (opc_rsp0),
    .bkd_rsp_dat1_i     (opc_rsp1),
    .bkd_rsp_dat2_i     (opc_rsp2),
    .bkd_rsp_dat3_i     (opc_rsp3),
    .bkd_rsp_dat4_i     (opc_rsp4),
    .bkd_rsp_dat5_i     (opc_rsp5),
    .bkd_rsp_dat6_i     (opc_rsp6),
    .bkd_rsp_dat7_i     (opc_rsp7),
    .bkd_rsp_dat8_i     (opc_rsp8),
    .bkd_rsp_dat9_i     (opc_rsp9),
    .bkd_rsp_datA_i     (opc_rspA),
    .bkd_rsp_datB_i     (opc_rspB),
    .bkd_rsp_datC_i     (opc_rspC),
    .bkd_rsp_datD_i     (opc_rspD),
    .bkd_rsp_datE_i     (opc_rspE),
    .bkd_rsp_datF_i     (opc_rspF),

//    .opc_fif_dat_o     (opc_fifo_dat_i),
//    .opc_fif_wen_o     (opc_fifo_wen),
//    .opc_fif_wmt_i     (opc_fifo_mt),
//    .opc_fif_wmt_i     (opc_fifo_mt),
//    .opc_rd_cnt_i      (opc_fifo_count), 
//    .opc_sys_st_o      (opc_sys_st_w),
//    .opc_mode_i        (opc_mode_w),
//    .opc_rspf_i        (opc_rspf_w),
//    .opc_rspf_we_i     (opc_rspf_we_w),
//    .opc_rspf_mt_o     (opc_rspf_mt_w),
//    .opc_rspf_fl_o     (opc_rspf_fl_w),
//    .opc_rspf_rdy_i    (opc_rspf_rdy_w),
//    .opc_rsp_cnt_o     (opc_rsp_cnt_w),
    // Debugging
    .opc_oc_cnt_i      ({8'd0, last_opcode[7:0], opc_count[15:0]}),   // last_opcode__opcodes_procesed
    .opc_status1_i     ({9'd0, opc_state, 8'd0, opc_status}),         // opc_state__opc_status
    // rsp_fifo_count__opc_fifo_count
    .opc_status2_i     ({10'd0, frq_fifo_count[5:0], 6'd0, opc_fifo_count[`GLBL_RSP_FILL_LEVEL_BITS-1:0]})
    );

  // Frequency processor instance. 
  // Input:requested frequency in MHz in fifo
  // Output:Programs DDS chip on DDS SPI
  freq_s4 freq_processor
  (
    .sys_clk            (sys_clk),
    .sys_rst_n          (sys_rst_n),
    
    .freq_en            (opc_enable),
    .spi_idle           (1'b1),

    // Frequency(ies) are in Hz in input fifo
    .frq_fifo_i         (frq_fifo_dat_o),       // frequency fifo
    .frq_fifo_ren_o     (frq_fifo_ren),         // fifo read line
    .frq_fifo_empty_i   (frq_fifo_mt),          // fifo empty flag
    .frq_fifo_count_i   (frq_fifo_count),       // fifo count, for debug message only

    .ftw_o              (ft_bytes),             // Debug only, tuning word output, SPI bytes to DDS SPI          

    .frequency_o        (frequency),            // System frequency so all modules can access

    .status_o           (frq_status)            // 0=Busy, SUCCESS when done, or an error code
  );

  // Power processor instance. 
  // Input:requested power in dBm or a cal value in fifo
  // Output:Programs DAC7563 chip on VGA SPI
  power #(
    .FILL_BITS(`PWR_FIFO_FILL_BITS)
  )
  pwr_processor 
  (
    .sys_clk            (sys_clk),
    .sys_rst_n          (sys_rst_n),
    
    .power_en           (opc_enable),

    .pwr_fifo_i         (pwr_fifo_dat_o),       // power processor fifo input
    .pwr_fifo_ren_o     (pwr_fifo_ren),         // power processor fifo read line
    .pwr_fifo_mt_i      (pwr_fifo_mt),          // power fifo empty flag
    .pwr_fifo_count_i   (pwr_fifo_count),       // power fifo count

    .VGA_MOSI_o         (pwr_mosi),
    .VGA_SCLK_o         (pwr_sclk),
    .VGA_SSn_o          (pwr_ssn),       
    .VGA_VSW_o          (pwr_vsw),              // Gain mode control

    .frequency_i        (frequency),            // current system frequency
    
    .status_o           (pwr_status)            // 0=busy, SUCCESS when done, or an error code
  );

// ******************************************************************************
// *                                                                            *
// *  03/28/2017  JLC                                                           *
// *    - refactored opcode processor instantiation now at top-level.           *
// *                                                                            *
// ******************************************************************************

  opcodes #(
     .RSP_FILL_LEVEL_BITS(`GLBL_RSP_FILL_LEVEL_BITS)
  ) opcode_processor (
    .sys_rst_n                  (sys_rst_n),
    .sys_clk                    (sys_clk),

    .enable                     (opc_enable),

    .fifo_dat_i                 (opc_fifo_dat_o),   // fifo read data bus
    .fifo_rd_en_o               (opc_fifo_ren),     // fifo read line
    .fifo_rd_empty_i            (opc_fifo_mt),      // fifo empty flag
    .fifo_rd_count_i            (opc_fifo_count),   // fifo fill level

    .system_state_i             (opc_sys_st_w),     // s4 system state (e.g. running a pattern)
    .mode_o                     (opc_mode_w),       // MODE opcode can set system-wide flags

    .response_o                 (opc_rspf_w),       // to fifo, response bytes(status, measurements, echo, etc)
    .response_wr_en_o           (opc_rspf_wen),     // response fifo write enable
    .response_fifo_empty_i      (opc_rspf_mt),      // response fifo empty flag
    .response_fifo_full_i       (opc_rspf_fl),      // response fifo full  flag
    // response_ready when fifo_length==response_length
    .response_ready_o           (opc_rspf_rdy),     // response fifo is waiting
    .response_length_o          (opc_rsp_lng),      // update response length when response is ready
    .response_fifo_count_i      (opc_rsp_cnt),      // response fifo count

    .frequency_o                (frq_fifo_dat_i),   // to fifo, frequency output in MHz
    .frq_wr_en_o                (frq_fifo_wen),     // frequency fifo write enable
    .frq_fifo_empty_i           (frq_fifo_mt),      // frequency fifo empty flag
    .frq_fifo_full_i            (frq_fifo_full),    // frequency fifo full flag
                                                    
    .power_o                    (pwr_fifo_dat_i),   // to fifo, power & opcode in upper 7 bits
    .pwr_wr_en_o                (pwr_fifo_wen),     // power fifo write enable
//    .pwr_fifo_empty_i,          (pwr_fifo_mt),      // power fifo empty flag
//    .pwr_fifo_full_i,           (pwr_fifo_full),    // power fifo full flag
                                                    
//    .pulse_o,          // to fifo, pulse opcode
//    .pulse_wr_en_o,           // pulse fifo write enable
//    .pulse_fifo_empty_i,           // pulse fifo empty flag
//    .pulse_fifo_full_i,            // pulse fifo full flag
                                                    
    .bias_enable_o              (bias_en),          // bias control
                                                    
    // pattern opcodes are saved in pattern RAM.
//    .ptn_wr_en_o,             // opcode processor saves pattern opcodes to pattern RAM 
//    .ptn_addr_o,       // address 
//    .ptn_data_o,       // 12 bytes, 3 bytes patClk tick, 9 bytes for opcode, length, and data   
//    .ptn_data_i,           // 12 bytes, 3 bytes patClk tick, 9 bytes for opcode, length, and data   
                                                    
//    .ptn_processor_en_o,      // Run pattern processor 
//    .[15:0] ptn_start_addr_o, // address 
                                                    
    .opcode_counter_o           (opc_count),     // count opcodes for status info   
                                                        
    // Debugging
    .status_o                   (opc_status),         // NULL opcode terminates, done=0, or error code
    .state_o                    (opc_state),          // For debugger display
    .last_opcode_o              (last_opcode)         //
    // .last_length_o              ()                   //    
  );
  
// ******************************************************************************
// *                                                                            *
// *  spi:  Initial SPI instance for debugging s4 HW                            *
// *        31-Mar-2017 Add SPI instances to debug on s4                        *
// *        We'll run at 12.5MHz (100MHz/8), CPOL=0, CPHA=0                     *
// *                                                                            *
// ******************************************************************************

  reg         SPI_MISO;
  wire        SPI_MOSI;
  wire        SPI_SCLK;
  reg         SPI_SSn;
  
  reg         spi_run = 0;
  reg  [7:0]  spi_write;
  wire [7:0]  spi_read;
  wire        spi_busy;         // 'each byte' busy
  wire        spi_done_byte;    // 1=done with a byte, data is valid
  spi #(.CLK_DIV(3)) syn_spi 
  (
      .clk(sys_clk),
      .rst(!sys_rst_n),
      .miso(SPI_MISO),
      .mosi(SPI_MOSI),
      .sck(SPI_SCLK),
      .start(spi_run),
      .data_in(spi_write),
      .data_out(spi_read),
      .busy(spi_busy),
      .new_data(spi_done_byte)     // 1=signal, data_out is valid
  );
  
  // Run the debug SPI instance
  `define SPI_IDLE            4'd0
  `define SPI_FETCH_DEVICE    4'd1
  `define SPI_START_WAIT      4'd2
  `define SPI_WRITING         4'd3
  `define SPI_SSN_OFF         4'd4
  
  reg [3:0]   spi_state    = `SPI_IDLE;    
  
  always @(posedge sys_clk) begin
    if(sys_rst_n == 1'b0) begin
      SPI_SSn <= 1'b1;
      spi_state <= `SPI_IDLE;    
    end
    else begin
      case(spi_state)
      `SPI_IDLE: begin
        if(dbg_spi_start) begin
          spi_run <= 1'b1;
          dbg_spi_count <= 0;
          spi_write <= arr_spi_bytes[0];
          spi_state <= `SPI_START_WAIT;
          SPI_SSn <= 1'b0;
        end
        else
          SPI_SSn = 1'b1;
      end
      `SPI_FETCH_DEVICE: begin
      end
      `SPI_START_WAIT: begin
        if(spi_busy == 1'b1) begin
          dbg_spi_count <= dbg_spi_count + 1;
          spi_state <= `SPI_WRITING;
        end
      end
      `SPI_WRITING: begin
        if(spi_done_byte == 1'b1) begin
          // ready for next byte 
          if(dbg_spi_count == dbg_spi_bytes) begin
            spi_run <= 1'b0;
            dbg_spi_done <= 1'b1;        
            spi_state <= `SPI_SSN_OFF;
          end
          else begin
            spi_write <= arr_spi_bytes[dbg_spi_count];
            spi_state <= `SPI_START_WAIT;
          end
        end
      end
      `SPI_SSN_OFF: begin
        if(spi_busy == 1'b0) begin
          SPI_SSn <= 1'b1;
          spi_state <= `SPI_IDLE;
        end
      end
      endcase
    end
  end


// ******************************************************************************
// *                                                                            *
// *  Load opcode fifo from the mmc_tester instance                             *
// *  (Initially using mmc debug uart)                                          *
// *  Load the opcode processor fifo using back-door UART                       *
// *                                                                            *
// ******************************************************************************
  reg  [4:0]    bkd_opc_state;
  reg  [5:0]    bkd_counter;
  `define BKD_COUNT 6'd63
  `define BKD_IDLE  5'd0
  `define BKD_WR0   5'd1
  `define BKD_WR1   5'd2
  `define BKD_WR2   5'd3
  `define BKD_WR3   5'd4
  `define BKD_NEXT  5'd5
  `define BKD_WRREG 5'd6
  `define BKD_DONE  5'd7
  `define BKD_SPCR  5'd8
  `define BKD_BUG   5'd9
  always @(posedge sys_clk) begin
    if(!sys_rst_n) begin
      opc_load_ack <= 1'b0;
      bkd_opc_state <= `BKD_IDLE;
      bkd_counter <= 6'd0;
      opc_enable <= 1'b0;
    end
    else if(opc_load_new == 1'b1) begin
      if(opc_load_ack == 1'b0) begin    // we haven't loaded opc yet
        case(bkd_opc_state)
        `BKD_IDLE: begin
          opc_inreg <= opc_dat0;   
          opc_load_ack <= 1'b0;
          bkd_counter <= 6'd0;
          bkd_opc_state <= `BKD_WR0;
        end
        `BKD_WR0: begin
          opc_fifo_dat_i <= opc_inreg[7:0];
          opc_fifo_wen <= 1'b1;     // writes on 1st clock even though count takes another clock to update
          bkd_counter <= bkd_counter + 1;
          bkd_opc_state <= `BKD_WR1;
        end
        `BKD_WR1: begin
          opc_fifo_dat_i <= opc_inreg[15:8];
          bkd_counter <= bkd_counter + 1;
          bkd_opc_state <= `BKD_WR2;
        end
        `BKD_WR2: begin
          opc_fifo_dat_i <= opc_inreg[23:16];
          bkd_counter <= bkd_counter + 1;
          bkd_opc_state <= `BKD_WR3;
        end
        `BKD_WR3: begin
          opc_fifo_dat_i <= opc_inreg[31:24];
          bkd_counter <= bkd_counter + 1;
          if(bkd_counter == `BKD_COUNT)
            bkd_opc_state <= `BKD_DONE;
          else
            bkd_opc_state <= `BKD_NEXT;
        end
        `BKD_NEXT: begin // Next word
          case(bkd_counter) 
          4:  opc_inreg <= opc_dat1;           
          8:  opc_inreg <= opc_dat2;           
          12: opc_inreg <= opc_dat3;           
          16: opc_inreg <= opc_dat4;           
          20: opc_inreg <= opc_dat5;           
          24: opc_inreg <= opc_dat6;           
          28: opc_inreg <= opc_dat7;           
          32: opc_inreg <= opc_dat8;           
          36: opc_inreg <= opc_dat9;           
          40: opc_inreg <= opc_datA;           
          44: opc_inreg <= opc_datB;           
          48: opc_inreg <= opc_datC;           
          52: opc_inreg <= opc_datD;           
          56: opc_inreg <= opc_datE;           
          60: opc_inreg <= opc_datF;
          endcase
          bkd_opc_state <= `BKD_WR0;
          opc_fifo_wen <= 1'b0;
        end
        `BKD_DONE: begin
          opc_load_ack <= 1'b1;
          opc_fifo_wen <= 1'b0;
          opc_enable <= 1'b1;
          bkd_opc_state <= `BKD_IDLE;
        end
        endcase    
      end
    end
    else begin
      // If we have loaded opc & acknowledged mmc_tester
      // once mmc_tester clears opc_load_new we must clear
      // opc_load_ack (handshake)
      if(opc_load_ack == 1'b1)
        opc_load_ack <= 1'b0;    
    end 
  end


// ******************************************************************************
// *                                                                            *
// *  Send opcode response fifo to the mmc_tester instance                      *
// *  (Initially using mmc debug uart)                                          *
// *  Send the opcode processor response fifo using back-door UART              *
// *                                                                            *
// ******************************************************************************
reg  [4:0]    bkd_rsp_state;
reg  [5:0]    bkd_rsp_counter;
reg           bkd_rsp_run;
always @(posedge sys_clk) begin
  if(!sys_rst_n) begin
    opc_rsp_new <= 1'b0;
    bkd_rsp_run <= 1'b0;
    bkd_rsp_state <= `BKD_IDLE;
    bkd_rsp_counter <= 6'd0;
  end
  else if(opc_rspf_rdy == 1'b1 || bkd_rsp_run) begin
      case(bkd_rsp_state)
      `BKD_IDLE: begin
        opc_rsp_new <= 1'b0;
        bkd_rsp_counter <= 6'd0;
        bkd_rsp_run <= 1'b1;
        bkd_rsp_state <= `BKD_WR0;
      end
      `BKD_WR0: begin
        opc_outreg[7:0] <= opc_rspf_dat_o;
        opc_rspf_ren <= 1'b1;
        bkd_rsp_counter <= bkd_rsp_counter + 1;
        bkd_rsp_state <= `BKD_SPCR; // Takes extra clk to start reading
      end
      `BKD_SPCR: begin
        bkd_rsp_state <= `BKD_BUG;
      end
      `BKD_BUG: begin
        bkd_rsp_state <= `BKD_WR1;
      end
      `BKD_WR1: begin
        opc_outreg[15:8] <= opc_rspf_dat_o;
        bkd_rsp_counter <= bkd_rsp_counter + 1;
        bkd_rsp_state <= `BKD_WR2;
      end
      `BKD_WR2: begin
        opc_outreg[23:16] <= opc_rspf_dat_o;
        bkd_rsp_counter <= bkd_rsp_counter + 1;
        bkd_rsp_state <= `BKD_WR3;
      end
      `BKD_WR3: begin
        opc_outreg[31:24] <= opc_rspf_dat_o;
        bkd_rsp_counter <= bkd_rsp_counter + 1;
        if(bkd_rsp_counter == `BKD_COUNT)
          bkd_rsp_state <= `BKD_DONE;
        else
          bkd_rsp_state <= `BKD_WRREG;
          opc_rspf_ren <= 1'b1;
      end
      `BKD_WRREG: begin // Save value
        case(bkd_rsp_counter) 
        4:  opc_rsp0 <= opc_outreg;           
        8:  opc_rsp1 <= opc_outreg;           
        12: opc_rsp2 <= opc_outreg;           
        16: opc_rsp3 <= opc_outreg;           
        20: opc_rsp4 <= opc_outreg;           
        24: opc_rsp5 <= opc_outreg;           
        28: opc_rsp6 <= opc_outreg;           
        32: opc_rsp7 <= opc_outreg;           
        36: opc_rsp8 <= opc_outreg;           
        40: opc_rsp9 <= opc_outreg;           
        44: opc_rspA <= opc_outreg;           
        48: opc_rspB <= opc_outreg;           
        52: opc_rspC <= opc_outreg;           
        56: opc_rspD <= opc_outreg;           
        60: opc_rspE <= opc_outreg;           
        64: opc_rspF <= opc_outreg;           
        endcase
        bkd_rsp_state <= `BKD_WR0;
        opc_rspf_ren <= 1'b1;
      end
      `BKD_DONE: begin
        opc_rsp_new <= 1'b1;
        opc_rspf_ren <= 1'b0;
        bkd_rsp_run <= 1'b0;
        bkd_rsp_state <= `BKD_IDLE;
      end
      endcase
  end
  else begin
    // When rsp fifo length is not equal the response length
    // the opc_rspf_rdy flag clears. When mmc_tester acks
    // our response we must clear opc_rsp_new 
    if(opc_rsp_ack == 1'b1)
      opc_rsp_new <= 1'b0;    
  end 
end


  // Implement MMC card tri-state drivers at the top level
    // Drive the clock output when needed
  assign MMC_CLK = mmc_clk_oe?mmc_clk:1'bZ;
    // Create mmc command signals
  assign mmc_cmd_zzz    = mmc_cmd?1'bZ:1'b0;
  assign mmc_cmd_choice = mmc_od_mode?mmc_cmd_zzz:mmc_cmd;
  assign MMC_CMD = mmc_cmd_oe?mmc_cmd_choice:1'bZ;
    // Create "open drain" data vector
  genvar j;
  for(j=0;j<8;j=j+1) begin
    assign mmc_dat_zzz[j] = mmc_dat[j]?1'bZ:1'b0;
  end
    // Select which data vector to use
  assign mmc_dat_choice1 = mmc_od_mode?mmc_dat_zzz:mmc_dat;
  assign mmc_dat_choice2 = mmc_dat_oe?mmc_dat_choice1:8'bZ;
    // Use always block for readability
  always @(mmc_dat_siz, mmc_dat_choice2)
         if (mmc_dat_siz==0) mmc_dat_choice3 <= {7'bZ,mmc_dat_choice2[0]};
    else if (mmc_dat_siz==1) mmc_dat_choice3 <= {4'bZ,mmc_dat_choice2[3:0]};
    else                     mmc_dat_choice3 <= mmc_dat_choice2;

  // Map the MMC output proxies to actual FPGA I/O pins
  assign MMC_DAT7     = mmc_dat_choice3[7];
  assign MMC_DAT6     = mmc_dat_choice3[6];
  assign MMC_DAT5     = mmc_dat_choice3[5];
  assign MMC_DAT4     = mmc_dat_choice3[4];
  assign MMC_DAT3     = mmc_dat_choice3[3];
  assign MMC_DAT2     = mmc_dat_choice3[2];
  assign MMC_DAT1     = mmc_dat_choice3[1];
  assign MMC_DAT0     = mmc_dat_choice3[0];
  
   // Map the MMC input  proxies to actual FPGA I/O pins
  assign MMC_DAT_i    = {MMC_DAT7, MMC_DAT6, MMC_DAT5, MMC_DAT4, MMC_DAT3, MMC_DAT2, MMC_DAT1, MMC_DAT0};

  // MMC_IRQn connected to MCU SD_CD, must be low. Can remove later when MMC driver sw fixed
  assign MMC_IRQn     = 1'b0;    // MCU SDIO_SD pin; low=MMC_Card_Present.
      
  // 31-Mar-2017 Add SPI instances to debug on S4
  //////////////////////////////////////////////////////
  // SPI instance for debugging S4
  // We'll run at 12.5MHz (100MHz/8), CPOL=0, CPHA=0
  //////////////////////////////////////////////////////
  
  // top level SPI busy flag used by mmc_test_pack 
  // SPI debug command processsor
  // ******************************************************
  // ** 18-Jul-2017 note: 0x4000 is used to turn ON SPI  **
  // ** debug mode. Otherwise SPI outputs are driven by  **
  // ** various processor modules.                       **
  // ******************************************************     
  assign dbg_spi_busy = (spi_state == `SPI_IDLE) ? 1'b0 : 1'b1;  
  // Connect SPI to wires based on which device is selected.
  localparam SPI_VGA = 4'd1, SPI_SYN = 4'd2, SPI_DDS = 4'd3, SPI_ZMON = 4'd4;

  assign SYN_SSn = dbg_spi_device == SPI_SYN ? SPI_SSn : 1'b1;
  assign SYN_SCLK = dbg_spi_device == SPI_SYN ? SPI_SCLK : 1'b0;
  assign SYN_MOSI = dbg_spi_device == SPI_SYN ? SPI_MOSI : 1'b0;

  assign DDS_SSn = dbg_spi_device == SPI_DDS ? SPI_SSn : 1'b1;
  assign DDS_SCLK = dbg_spi_device == SPI_DDS ? SPI_SCLK : 1'b0;
  assign DDS_MOSI = dbg_spi_device == SPI_DDS ? SPI_MOSI : 1'b0;
  
  // S4 Enables/lines
  localparam BIT_RF_GATE          = 16'h0001;
  localparam BIT_RF_GATE2         = 16'h0002;
  localparam BIT_VGA_VSW          = 16'h0004;
  localparam BIT_DRV_BIAS_EN      = 16'h0008;
  localparam BIT_PA_BIAS_EN       = 16'h0010;
  localparam BIT_SYN_STAT         = 16'h0020;
  localparam BIT_SYN_MUTE         = 16'h0040;
  localparam BIT_DDS_IORST        = 16'h0080;
  localparam BIT_DDS_IOUP         = 16'h0100;
  localparam BIT_DDS_SYNC         = 16'h0200;
  localparam BIT_DDS_PS0          = 16'h0400;
  localparam BIT_DDS_PS1          = 16'h0800;
  localparam BIT_ZMON_EN          = 16'h1000;                           // <JLC_TEMP_ZMON_EN>
  
  localparam BIT_SPI_DBG_MODE     = 16'h4000;                           // Enable this SPI debugger
  localparam BIT_TEMP_SYS_RST     = 16'h8000;                           // <JLC_TEMP_RST>

  // Mux these debug controls
  assign dbg_spi_mode = 1'b0; //(dbg_enables & BIT_SPI_DBG_MODE) == 16'h4000 ? 1'b1 : 1'b0;   // Mux SPI outputs   

  wire dbg_rfgate;
  assign dbg_rfgate = dbg_enables & BIT_RF_GATE ? 1'b1 : 1'b0;  
  assign RF_GATE = dbg_spi_mode == 1'b1 ? dbg_rfgate : 1'b0;
  
  wire dbg_rfgate2;
  assign dbg_rfgate2 = dbg_enables & BIT_RF_GATE2 ? 1'b1 : 1'b0;  
  assign RF_GATE2 = dbg_spi_mode == 1'b1 ? dbg_rfgate2 : 1'b0;

  // VGA SPI mux
  // How can this friggin mux not be working???
  wire dbg_vgavsw;
  assign dbg_vgavsw = dbg_enables & BIT_VGA_VSW ? 1'b1 : 1'b0;  
  assign VGA_VSW = pwr_vsw; //dbg_spi_mode == 1'b1 ? dbg_vgavsw : pwr_vsw;
  wire dbg_vgassn;
  assign dbg_vgassn = dbg_spi_device == SPI_VGA ? SPI_SSn : 1'b1;  
  assign VGA_SSn = dbg_spi_mode == 1'b1 ? dbg_vgassn : pwr_ssn;
  wire dbg_vgasclk;
  assign dbg_vgasclk = dbg_spi_device == SPI_VGA ? SPI_SCLK : 1'b0;  
  assign VGA_SCLK = dbg_spi_mode == 1'b1 ? dbg_vgassn : pwr_sclk;
  wire dbg_vgamosi;
  assign dbg_vgamosi = dbg_spi_device == SPI_VGA ? SPI_MOSI : 1'b0;  
  assign VGA_MOSI = dbg_spi_mode == 1'b1 ? dbg_vgamosi : pwr_mosi;
  assign VGA_VSWn = !VGA_VSW;

  wire dbg_bias;
  assign dbg_bias = dbg_enables & BIT_PA_BIAS_EN ? 1'b1 : 1'b0;  
  assign DRV_BIAS_EN = dbg_spi_mode == 1'b1 ? dbg_bias : bias_en;
  assign PA_BIAS_EN = DRV_BIAS_EN;
  
  wire dbg_synmute;
  assign dbg_synmute = dbg_enables & BIT_SYN_MUTE ? 1'b0 : 1'b1;
  assign SYN_MUTE = dbg_spi_mode == 1'b1 ? dbg_synmute : 1'b0;
  
  wire dbg_ddsiorst;
  assign dbg_ddsiorst = dbg_enables & BIT_DDS_IORST ? 1'b1 : 1'b0; 
  assign DDS_IORST = dbg_spi_mode == 1'b1 ? dbg_ddsiorst : 1'b0;
  
  wire dbg_ddsioup;
  assign dbg_ddsioup = dbg_enables & BIT_DDS_IOUP ? 1'b1 : 1'b0;
  assign DDS_IOUP = dbg_spi_mode == 1'b1 ? dbg_ddsioup : 1'b0;
  
  wire dbg_ddssync;
  assign dbg_ddssync = dbg_enables & BIT_DDS_SYNC ? 1'b1 : 1'b0;
  assign DDS_SYNC = dbg_spi_mode == 1'b1 ? dbg_ddssync : 1'b0;
  
  wire dbg_ddsps0;
  assign dbg_ddsps0 = dbg_enables & BIT_DDS_PS0 ? 1'b1 : 1'b0;
  assign DDS_PS0 = dbg_spi_mode == 1'b1 ? dbg_ddsps0 : 1'b0;
   
  wire dbg_ddsps1;
  assign dbg_ddsps1 = dbg_enables & BIT_DDS_PS1 ? 1'b1 : 1'b0;
  assign DDS_PS1 = dbg_spi_mode == 1'b1 ? dbg_ddsps1 : 1'b0;
   
  wire dbg_zmonen;
  assign dbg_zmonen = dbg_enables & BIT_ZMON_EN ? 1'b1 : 1'b0;
  assign ZMON_EN = dbg_spi_mode == 1'b1 ? dbg_zmonen : 1'b0;
  
  assign dbg_sys_rst_i = dbg_enables & BIT_TEMP_SYS_RST ? 1'b1 : 1'b0;   // <JLC_TEMP_RST>

  // FPGA_RXD/TXD to/from MMC UART RXD/TXD
  assign syscon_rxd = FPGA_RXD;
  assign FPGA_TXD   = syscon_txd;


// ******************************************************************************
// *                                                                            *
// *  04/11/2017  JLC                                                           *
// *    - added HW DBG UART.                                                    *
// *                                                                            *
// ******************************************************************************

  uart #(
    .VRSN                       (`VERSION),
    .CLK_FREQ                   (`GLBL_CLK_FREQ_MCU),    // <JLC_TEMP_CLK
    .BAUD                       (115200)
  ) hwdbg_uart
  (                                                      // diag/debug control signal outputs
    // infrastructure, etc.
    .clk_i                      (sys_clk),               // 
    .rst_i                      (!sys_rst_n),            // 
    .rx_enbl                    (count2tc),
    .RxD_i                      (FPGA_RXD2),             // "RxD" from USB serial bridge to FPGA
    .TxD_o                      (FPGA_TXD2),             // "TxD" from FPGA to USB serial bridge
    .extd_fifo_wr_stb_o         (extd_fifo_wr_stb_w),
    .extd_fifo_wr_addr_o        (),
    .dbg0_o                     (),                      //  1-bit output: debug outpin #0.
    .dbg1_o                     (),                      //  1-bit output: debug outpin #1.
    .dbg2_o                     (),                      //  1-bit output: debug outpin #2.
    
    // diag/debug control signal outputs
    .hw_ctl_o                   (tdbgw),                 // 16-bit output: control functions.

    // diag/debug status  signal inputs
    .hw_stat_i                  (tdbgr),
    .gp_opc_cnt_i               (opc_count),          // count of opcodes processed from top level
    .ptn_opc_cnt_i              (32'hdeadbeef),          // 32-bit input:  count of pattern opcodes processed from top level
    .sys_stat_vec_i             (opc_sys_st_w)           // 16-bit input:  status to show, system_state for now
   );

   // Snapshot:  capture data for R & S commands.   ZZM changes are incl'd in always block below.
   always @(posedge sys_clk) begin
      if (!sys_rst_n) begin
         tdbgr                     <= 256'b0;
//         opc_fifo_wr_enr           <= 1'b0;
//         opc_fifo_wr_enrr          <= 1'b0;
//         opc_fifo_rd_enr           <= 1'b0;
//         opc_fifo_rd_enrr          <= 1'b0;
      end
      else begin
         tdbgr                     <= tdbgw; //{tdbgw[255:120], opc_fifo_dat_o, opcode_fifo_empty, 5'b0, opcode_fifo_count, tdbgw[95:0]};
//         opc_fifo_wr_enr           <= extd_fifo_wr_stb_w;  // ZZM stb_w is a 1-tick signal.
//         opc_fifo_wr_enrr          <= opc_fifo_wr_enr;
//         opc_fifo_rd_enr           <= tdbgw[254];
//         opc_fifo_rd_enrr          <= opc_fifo_rd_enr;
      end
   end  // end of always @ (posedge clk).
   
//   assign opc_fifo_dat_i = tdbgw[71:64];                            // ZZM
//   assign opc_fifo_wr_en = opc_fifo_wr_enrr;                        // ZZM
//   assign opc_fifo_rd_en = opc_fifo_rd_enr & ~opc_fifo_rd_enrr;     // ZZM
        
   assign ACTIVE_LEDn = tdbgr[255]?count2[24]:count2[25];
   
//   assign FPGA_MCU2 = opc_fifo_wr_enrr;    // ZZM
//   assign FPGA_MCU3 = opc_fifo_rd_en;      // ZZM
//   assign FPGA_MCU4 = opcode_fifo_empty;   // ZZM    
  // 22-Jun have to scope MMC signals
  assign FPGA_MCU4 = VGA_SCLK; //MMC_CLK; //count4[15];    //  50MHz div'd by 2^16.
  assign FPGA_MCU3 = VGA_MOSI; //MMC_CMD; //count3[15];    // 200MHz div'd by 2^16.

  endmodule
