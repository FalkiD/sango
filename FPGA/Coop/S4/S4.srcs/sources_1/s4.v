//------------------------------------------------------------------------------
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
//        spi                            spi_master.v                 (s4 ...syn_spi)
//                                                                                  ^
//        opcodes                        opcodes.v                    (s4 ...opcode_processor)
//
//        hwdbg_uart                     uart.v                       (s4 ...hwdbg_uart)
//            xmt1                       xmtr.v                       (s4 ......xmt1)
//            rcv1                       rcvr.v                       (s4 ......rcv1)
//          
//        dds_spi                        dds.v                        (s4 ...hwdbg_dds_spi)  
//            snglClkFifoParmd           snglClkFifoParmd.v           (s4 ......ddsInFifo)
//          
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
// Revision 1.00.6  07/10/2017 JLC #1: uart.v got HWDBG ext'd fifo write updates.
// Revision 1.00.7  07/10/2017 JLC #2:
// See version.v    07/26/2017 RMR Merged Coop & Rick
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

// MMCM in case no clock available? Not normally used (unless non-100MHz clocks needed)
`define JLC_TEMP_NO_MMCM 1             // 1 -> Don't use MMCME2_BASE; Use 100MHz straight in.  0 -> Use MMCME2_BASE.

// Which clock, FPGA_MCU pin from MCU, or FPGA_CLK, CLKn differential clock from
// synthesizer clock. Synthesizer clock requires L12 in place (+5V)
// ********************************************************************************************
// ** Note ** To use Synthesizer clock its pins must be un-commented in the contraints file  **
// ********************************************************************************************
//`define USE_FPGA_MCLK    1             // Use MCU clock, 102MHz
`define GLBL_CLK_FREQ   100000000.0  //  "       "        "      "
// When using FPGA_MCLK: `define GLBL_CLK_FREQ 102000000.0
//`define CLKFB_FACTOR_BRD 10.000        //  "       "        "      "
//`define CLKFB_FACTOR_MCU 9.800         //  "       "        "      "
`define GLBL_MMC_FILL_LEVEL         2048
`define GLBL_MMC_FILL_LEVEL_BITS    11
`define GLBL_RSP_FILL_LEVEL_BITS    10
`define PWR_FIFO_FILL_BITS          4

`define PATTERN_DEPTH           32768
`define PATTERN_FILL_BITS       15
`define PATTERN_WORD            104      // bits wide

// -----------------------------------------------------------------------------

module s4  
(
`ifndef USE_FPGA_MCLK
  input              FPGA_CLK,           //  P10   I        + Diff FPGA CLK From S4 Board U34/Si53307
  input              FPGA_CLKn,          //  N10   I        - and A3/100MHx Oscillator can.
`endif

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
  output             FPGA_MCU1,          //  P10   I 
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
  output             SYN_MUTEn,          //  E2    O

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
// MMCM clocking instance can be uncommented if other clocks are needed
//wire         clkfbprebufg;
//wire         clk100prebufg;
//wire         clk200prebufg;
//wire         clk050prebufg;
//wire         clkfb;
//wire         clk100;
//wire         clk200;
//wire         clk050;

// The current system state:
wire [31:0]  frequency;                 // in Hertz
wire [11:0]  dbm_x10;
reg  [15:0]  sys_state = 0;             // s4 system state (e.g. running a pattern)
wire         pulse_busy;
wire [31:0]  sys_mode;                  // MODE opcode can set system-wide flags

// Use 0x4000 if dbg_enables to turn ON SPI debugger mode
// Otherwise SPI outputs are driven by various processor modules
wire         dbg_spi_mode;

wire         dbg_sys_rst_i;
reg  [9:0]   dbg_sys_rst_sr   = 0; //10'b0;
reg          dbg_sys_rst_n    = 1'b1;

reg  [26:0]  count2;

wire         sys_clk;
wire         sys_rst_n;
// initialize hw after a reset
reg          initialize = 1'b1;
reg          hw_init = 1'b1;

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

wire         syscon_rxd;
wire         syscon_txd;

// opcode processor wires:
wire         opc_enable;         // control needed...      
wire         opc_fifo_enable;    // enable opcode processor in & out fifo's
wire         opc_fifo_rst;       // reset for opcode processor fifo's

wire  [7:0]  opc_fif_dat;        // MMC read fifo into opcode processor 
wire         opc_fif_ren;        // MMC read enable, out of opcode processor into mmc_tester
wire         opc_fif_mt;         // MMC read fifo empty
wire  [`GLBL_MMC_FILL_LEVEL_BITS-1:0]  opc_fif_cnt;    // MMC read fifo count
wire         opc_inpf_rst;       // opcode processor can reset input fifo

wire  [7:0]  opc_rspf_dat;       // MMC write fifo, out of opcode processor into mmc_tester 
wire         opc_rspf_wen;       // MMC write enable 
wire         opc_rspf_mt;        // MMC write fifo empty 
wire         opc_rspf_fl;        // MMC write fifo full
wire  [`GLBL_MMC_FILL_LEVEL_BITS-1:0]  opc_rspf_cnt;   // MMC write fifo count
wire         opc_rsp_rdy;        // Response ready
wire  [`GLBL_MMC_FILL_LEVEL_BITS-1:0]  opc_rsp_len;    // Response length written by opcode processor

// opcode processor mux wires, MMC
wire  [7:0]  mmc_fif_dat;        // MMC read fifo into opcode processor 
wire         mmc_fif_ren;        // MMC read enable, out of opcode processor into mmc_tester
wire         mmc_fif_mt;         // MMC read fifo empty
wire  [`GLBL_MMC_FILL_LEVEL_BITS-1:0]  mmc_fif_cnt;    // MMC read fifo count
wire         mmc_inpf_rst;       // opcode processor can reset input fifo

wire  [7:0]  mmc_rspf_dat;       // MMC write fifo, out of opcode processor into mmc_tester 
wire         mmc_rspf_wen;       // MMC write enable 
wire         mmc_rspf_mt;        // MMC write fifo empty 
wire         mmc_rspf_fl;        // MMC write fifo full
wire  [`GLBL_MMC_FILL_LEVEL_BITS-1:0]  mmc_rspf_cnt;   // MMC write fifo count
wire         mmc_rsp_rdy;        // Response ready
wire  [`GLBL_MMC_FILL_LEVEL_BITS-1:0]  mmc_rsp_len;    // Response length written by opcode processor
// opcode processor mux wires, pattern processor
wire  [7:0]  ptn_fif_dat;        // MMC read fifo into opcode processor 
wire         ptn_fif_ren;        // MMC read enable, out of opcode processor into mmc_tester
wire         ptn_fif_mt;         // MMC read fifo empty
wire  [`GLBL_MMC_FILL_LEVEL_BITS-1:0]  ptn_fif_cnt;    // MMC read fifo count
wire         ptn_inpf_rst;       // opcode processor can reset input fifo

wire  [7:0]  ptn_rspf_dat;       // MMC write fifo, out of opcode processor into mmc_tester 
wire         ptn_rspf_wen;       // MMC write enable 
wire         ptn_rspf_mt;        // MMC write fifo empty 
wire         ptn_rspf_fl;        // MMC write fifo full
wire  [`GLBL_MMC_FILL_LEVEL_BITS-1:0]  ptn_rspf_cnt;   // MMC write fifo count
wire         ptn_rsp_rdy;        // Response ready
wire  [`GLBL_MMC_FILL_LEVEL_BITS-1:0]  ptn_rsp_len;    // Response length written by opcode processor

// Frequency processor wires
wire [31:0]  frq_fifo_dat_i;          // to fifo from opc, frequency output in MHz
wire         frq_fifo_wen;            // frequency fifo write enable
wire [31:0]  frq_fifo_dat_o;          // to frequency processor
wire         frq_fifo_ren;            // frequency fifo read enable
wire         frq_fifo_mt;             // frequency fifo empty flag
wire         frq_fifo_full;           // frequency fifo full flag
wire [5:0]   frq_fifo_count;
wire [7:0]   frq_status;              // frequency processor status
// DDS processor wires
wire [31:0]  ftw_fifo_dat_i; // = 32'h0000_0000;          // frequency tuning word fifo input(SPI data) from frequency processor.
wire         ftw_fifo_wen; // = 1'b0;            // frequency tuning word fifo we.
wire         ftw_fifo_full;           // ftw fifo full.
wire         ftw_fifo_mt;             // ftw fifo empty.
wire         hardware_init;           // pulse to do DDS/VGA init sequences
wire         dds_init_done;           // pulse to do SYN init sequence after DDS has finished init

// Power processor wires
wire [38:0]  pwr_fifo_dat_i;          // to fifo from opc, power or cal value. 
                                      // Upper 7 bits are opcode, cal or user power
wire         pwr_fifo_wen;            // power fifo write enable
wire [38:0]  pwr_fifo_dat_o;          // to power processor
wire         pwr_fifo_ren;            // power fifo read enable
wire         pwr_fifo_mt;             // power fifo empty flag
wire         pwr_fifo_full;           // power fifo full flag
wire [7:0]   pwr_status;              // power processor status
wire [`PWR_FIFO_FILL_BITS-1:0]   pwr_fifo_count;
// power processor outputs, mux'd to main outputs
wire         pwr_mosi;
wire         pwr_sclk;
wire         pwr_ssn;       
wire         pwr_vsw;       

// Pulse processor & fifo wires
wire [63:0]  pls_fifo_dat_i;          // to pulse fifo from opc
wire         pls_fifo_wen;            // pulse fifo write enable
wire [63:0]  pls_fifo_dat_o;          // from pulse fifo to pulse processor
wire         pls_fifo_ren;            // pulse fifo read enable
wire         pls_fifo_mt;             // pulse fifo empty flag
wire         pls_fifo_full;           // pulse fifo full flag
wire [7:0]   pls_status;              // pulse processor status
wire [`PWR_FIFO_FILL_BITS-1:0]   pls_fifo_count;
wire         pls_zmonen;              // from pulse processor to ZMON_EN
wire         pls_rfgate;              // from pulse processor to RF_GATE
wire         pls_rfgate2;             // from pulse processor to RF_GATE2

// Measurement fifo wires
wire [31:0]  meas_fifo_dat_i;          // to results fifo from measurement processing in pulse processor
wire         meas_fifo_wen;            // meas fifo write enable
wire [31:0]  meas_fifo_dat_o;          // from meas fifo to opc response fifo
wire         meas_fifo_ren;            // meas fifo read enable
wire         meas_fifo_mt;             // meas fifo empty flag
wire         meas_fifo_full;           // meas fifo full flag
wire [`GLBL_MMC_FILL_LEVEL_BITS-1:0]   meas_fifo_count;

// Bias enable wire
wire         bias_en;                 // bias control

// Pattern processor wires.
wire                            ptn_wen;         // opcode processor saves pattern opcodes to pattern RAM 
wire [`PATTERN_FILL_BITS-1:0]   ptn_addr;        // address
wire [23:0]                     ptn_clk;         // patclk, pattern tick, tick=100ns
wire [`PATTERN_WORD-1:0]        ptn_data;        // 12 bytes, 3 bytes patClk tick, 9 bytes for opcode, length, and data   
wire                            ptn_proc_en;     // Run pattern processor 
wire [`PATTERN_FILL_BITS-1:0]   ptn_start_addr;  // address
wire [7:0]                      ptn_status;      // status from pattern processor 
wire [3:0]                      ptn_cmd;         // Command/mode, i.e. writing pattern, run pattern, stop, etc

// Opcode processing statistics
wire [31:0]  opc_count;               // count opcodes for status info                     
wire [7:0]   opc_status;              // NULL opcode terminates, done=0, or error code
wire [6:0]   opc_state;               // For debugging
    
// Debugging
wire [15:0]  dbg_opcodes;
wire         dbg_opc_rfgate;          // Driven by RF_GATE bit of sys_mode, MODE opcode, for debugging

// SPI debugging connections for w 03000040 command
// Write up to 14 byte to SPI device
wire [7:0]   arr_spi_bytes [13:0];
wire [3:0]   dbg_spi_bytes;      // bytes to send
reg  [3:0]   dbg_spi_count;      // down counter
wire         dbg_spi_start;
wire         dbg_spi_busy;
reg          dbg_spi_done;
wire [2:0]   dbg_spi_device;       // 1=VGA, 2=SYN, 3=DDS, 4=ZMON
wire [15:0]  dbg_enables; // = 1'b0;          // toggle various enables/wires

// DDS/SYN lines
wire         rmr_DDS_SCLK;
wire         rmr_DDS_MOSI;
wire         rmr_DDS_MISO = 1'b0;
wire         rmr_DDS_SSn;
wire         rmr_DDS_IORST;
wire         rmr_DDS_IOUP;
wire         rmr_DDS_SYNC;
wire         rmr_DDS_PS0;
wire         rmr_DDS_PS1;
// LTC6946 SYN wires
wire         synth_ssn;
wire         synth_sclk;
wire         synth_mosi;
wire         synth_miso;
wire         syn_synth_mute_n;      // SYN processor muting SYN
wire         synth_doInit;          // asserted by dds_synth_doInit or dbg_synth_doInit
// SYN/DDS shared signals
wire         dds_synth_mute_n;      // DDS processor muting SYN
wire         dds_synth_doInit;      // Init SYN when DDS init has completed
wire         dds_synth_initing;     // SYN initializing

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

////  <JLC_TEMP_NO_MMCM>
//`ifndef JLC_TEMP_NO_MMCM
//MMCME2_BASE #(
//  .BANDWIDTH("OPTIMIZED"), // Jitter programming (OPTIMIZED, HIGH, LOW)
//  .CLKFBOUT_MULT_F(`CLKFB_FACTOR_MCU),  // Multiply value for all CLKOUT (2.000-64.000)   = Fpfd/Fclkin1  <JLC_TEMP_CLK>
//  .CLKFBOUT_PHASE(0.000),  // Phase offset in degrees of CLKFB (-360.000-360.000).
//  .CLKIN1_PERIOD(9.800),  // Input clock period in ns to ps resolution (i.e. 33.333 is 30 MHz).           <JLC_TEMP_CLK>
//  // CLKOUT0_DIVIDE - CLKOUT6_DIVIDE: Divide amount for each CLKOUT (1-128)
//  .CLKOUT0_DIVIDE_F(10),   // 1000MHz / 10.0 = 100MHz  Divide amount for CLKOUT0 (1.000-128.000).
//  .CLKOUT1_DIVIDE(5),      // 1000MHz /  5.0 = 200MHz
//  .CLKOUT2_DIVIDE(20),     // 1000MHz / 20.0 =  50MHz
//  .CLKOUT3_DIVIDE(1),
//  .CLKOUT4_DIVIDE(1),
//  .CLKOUT5_DIVIDE(1),
//  .CLKOUT6_DIVIDE(1),
//  // CLKOUT0_DUTY_CYCLE - CLKOUT6_DUTY_CYCLE: Duty cycle for each CLKOUT (0.01-0.99).
//  .CLKOUT0_DUTY_CYCLE(0.50),
//  .CLKOUT1_DUTY_CYCLE(0.50),
//  .CLKOUT2_DUTY_CYCLE(0.50),
//  .CLKOUT3_DUTY_CYCLE(0.50),
//  .CLKOUT4_DUTY_CYCLE(0.50),
//  .CLKOUT5_DUTY_CYCLE(0.50),
//  .CLKOUT6_DUTY_CYCLE(0.50),
//  // CLKOUT0_PHASE - CLKOUT6_PHASE: Phase offset for each CLKOUT (-360.000-360.000).
//  .CLKOUT0_PHASE(0.000),
//  .CLKOUT1_PHASE(0.000),
//  .CLKOUT2_PHASE(0.000),
//  .CLKOUT3_PHASE(0.000),
//  .CLKOUT4_PHASE(0.000),
//  .CLKOUT5_PHASE(0.000),
//  .CLKOUT6_PHASE(0.000),
//  .CLKOUT4_CASCADE("FALSE"), // Cascade CLKOUT4 counter with CLKOUT6 (FALSE, TRUE)
//  .DIVCLK_DIVIDE(1),         // Master division value (1-106):   Fpfd = CLKIN1/DIVCLK_DIVIDE.
//  .REF_JITTER1(0.010),       // Reference input jitter in UI (0.000-0.999).
//  .STARTUP_WAIT("FALSE")     // Delays DONE until MMCM is locked (FALSE, TRUE)
//)
//MMCME2_BASE_inst (
//  // Clock Outputs: 1-bit (each) output: User configurable clock outputs
//  .CLKOUT0(clk100prebufg), // 1-bit output: CLKOUT0
//  .CLKOUT0B(), // 1-bit output: Inverted CLKOUT0
//  .CLKOUT1(clk200prebufg), // 1-bit output: CLKOUT1
//  .CLKOUT1B(), // 1-bit output: Inverted CLKOUT1
//  .CLKOUT2(clk050prebufg), // 1-bit output: CLKOUT2
//  .CLKOUT2B(), // 1-bit output: Inverted CLKOUT2
//  .CLKOUT3(), // 1-bit output: CLKOUT3
//  .CLKOUT3B(), // 1-bit output: Inverted CLKOUT3
//  .CLKOUT4(), // 1-bit output: CLKOUT4
//  .CLKOUT5(), // 1-bit output: CLKOUT5
//  .CLKOUT6(), // 1-bit output: CLKOUT6
//  // Feedback Clocks: 1-bit (each) output: Clock feedback ports
//  .CLKFBOUT(clkfbprebufg), // 1-bit output: Feedback clock
//  .CLKFBOUTB(), // 1-bit output: Inverted CLKFBOUT
//  // Status Ports: 1-bit (each) output: MMCM status ports
//  .LOCKED(mmcm_locked_o), // 1-bit output: LOCK
//  // Clock Inputs: 1-bit (each) input: Clock input
//  .CLKIN1(clkin), // 1-bit input: Clock
//  // Control Ports: 1-bit (each) input: MMCM control ports
//  .PWRDWN(mmcm_pwrdn_i), // 1-bit input: Power-down
//  .RST(mmcm_rst_i), // 1-bit input: Reset
//  // Feedback Clocks: 1-bit (each) input: Clock feedback ports
//  .CLKFBIN(clkfb) // 1-bit input: Feedback clock
//);
//// End of MMCME2_BASE_inst instantiation

//  BUFG BUFG_clkfb  (.I(clkfbprebufg),  .O(clkfb));
//  BUFG BUFG_clk100 (.I(clk100prebufg), .O(clk100));
//  BUFG BUFG_clk200 (.I(clk200prebufg), .O(clk200));
//  BUFG BUFG_clk050 (.I(clk050prebufg), .O(clk050));
//  assign sys_clk   = clk100;
//`else
  assign sys_clk   = clkin;
//`endif

`ifndef USE_FPGA_MCLK
  IBUFGDS IBUFGDS_clkin  (.I(FPGA_CLK), .IB(FPGA_CLKn), .O(clk_diff_rcvd));
  BUFG BUFG_clkin  (.I(clk_diff_rcvd),    .O(clkin));
`else
  BUFG BUFG_clkin  (.I(FPGA_MCLK),   .O(clkin));
`endif

// Create a "hwdbg dbg_sys_rst_n" synchronous self-timed pulse.
always @(posedge sys_clk)
begin
  dbg_sys_rst_sr <= {dbg_sys_rst_sr[8:0], dbg_sys_rst_i};
  dbg_sys_rst_n <= !(!dbg_sys_rst_sr[9] & |dbg_sys_rst_sr[8:0]);  // output 9 ticks of dbg_sys_rst_n == 1'b0.
end

assign sys_rst_n = MCU_TRIG ? 1'b0 : dbg_sys_rst_n;

/////////////////////////////////////////////////////////
// Important system globals & assignments              //
/////////////////////////////////////////////////////////
assign opc_fifo_enable = 1'b1;
assign opc_fifo_rst = 1'b0;
assign opc_enable = 1'b1;

// Create a "blink" counter.
//   2^28 @ 100MHz wraps at ~4.5 seconds. Use this to indicate FPGA running
//   2^26 @ 100MHz wraps at ~1.5 seconds.
//   2^20 ! 100MHz wraps at ~1 ms 
//   2^25 ! 100MHz wraps at ~32 ms 
//   2^40 @ 100MHz wraps at ~3.05 hours.
//
always @(posedge sys_clk)
  if (!sys_rst_n) begin
    count2     <= 0;
  end
  else begin
    count2     <= count2+1;
  end

// Initialize things after reset pulse
always @(posedge sys_clk) begin
  if (!sys_rst_n) begin
    initialize <= 1'b1;
  end
  else begin
    if(initialize == 1'b1)
      hw_init <= 1'b1;
    else
      hw_init <= 1'b0;
    initialize <= 1'b0;
  end
end


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

    /////////////////////////////////////////////////////////////////////////////////////
    // Pulse input FIFO                       
    // Instantiate fifo that the opcode processor is using to store pulse opcodes
    // Written by opcode processor, read by pulse processor module (or pattern processor?)
    /////////////////////////////////////////////////////////////////////////////////////
    swiss_army_fifo #(
      .USE_BRAM(1),
      .WIDTH(64),
      .DEPTH(16),
      .FILL_LEVEL_BITS(`PWR_FIFO_FILL_BITS),
      .PF_FULL_POINT(`PWR_FIFO_FILL_BITS-1),
      .PF_FLAG_POINT(`PWR_FIFO_FILL_BITS>>1),
      .PF_EMPTY_POINT(1)
    ) pulse_fifo(
        .sys_rst_n(sys_rst_n),
        .sys_clk(sys_clk),
        .sys_clk_en(opc_fifo_enable),
        
        .reset_i(opc_fifo_rst),
        
        .fifo_wr_i(pls_fifo_wen),
        .fifo_din(pls_fifo_dat_i),
        
        .fifo_rd_i(pls_fifo_ren),
        .fifo_dout(pls_fifo_dat_o),
        
        .fifo_fill_level(pls_fifo_count),
        .fifo_full(pls_fifo_full),
        .fifo_empty(pls_fifo_mt),
        .fifo_pf_full(),
        .fifo_pf_flag(),
        .fifo_pf_empty()           
    );

    /////////////////////////////////////////////////////////////////////////////////////
    // Pulse measurement FIFO                       
    // Instantiate fifo that the pulse processor is using to store measurements
    /////////////////////////////////////////////////////////////////////////////////////
    swiss_army_fifo #(
      .USE_BRAM(1),
      .WIDTH(32),
      .DEPTH(`GLBL_MMC_FILL_LEVEL),
      .FILL_LEVEL_BITS(`GLBL_MMC_FILL_LEVEL_BITS),
      .PF_FULL_POINT(`GLBL_MMC_FILL_LEVEL_BITS-1),
      .PF_FLAG_POINT(`GLBL_MMC_FILL_LEVEL_BITS>>1),
      .PF_EMPTY_POINT(1)
    ) results_fifo(
        .sys_rst_n(sys_rst_n),
        .sys_clk(sys_clk),
        .sys_clk_en(opc_fifo_enable),
        
        .reset_i(opc_fifo_rst),
        
        .fifo_wr_i(meas_fifo_wen),
        .fifo_din(meas_fifo_dat_i),
        
        .fifo_rd_i(meas_fifo_ren),
        .fifo_dout(meas_fifo_dat_o),
        
        .fifo_fill_level(meas_fifo_count),
        .fifo_full(meas_fifo_full),
        .fifo_empty(meas_fifo_mt),
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
    .SYS_CLK_RATE         (`GLBL_CLK_FREQ),
    .SYS_LEDS             (16),    // <TBD> Eventually these need to go away.
    .SYS_SWITCHES         (8),     // <TBD> Eventually these need to go away.
    .EXT_CSD_INIT_FILE    ("ext_csd_init.txt"), // Initial contents of EXT_CSD
    .HOST_RAM_ADR_BITS    (14), // Determines amount of BRAM in MMC host
    .MMC_FIFO_DEPTH       (`GLBL_MMC_FILL_LEVEL), // (2048),
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
    .switch_i          (8'b0),
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
    // signals for spi debug data written to MMC debug terminal (03000040 X Y Z...)
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
    
    // MMC is working! MMC fifo connections
    // Read from MMC fifo connections
    .opc_fif_dat_o      (mmc_fif_dat),          // MMC opcode fifo from mmc_tester into mux
    .opc_fif_ren_i      (mmc_fif_ren),          // mmc fifo read enable
    .opc_fif_mt_o       (mmc_fif_mt),           // mmc opcode fifo empty
    .opc_rd_cnt_o       (mmc_fif_cnt),          // mmc opcode fifo fill level 
    .opc_rd_reset_i     (mmc_inpf_rst),         // Synchronous mmc opcode fifo reset
    //    -- Write to MMC fifo connections
    .opc_rspf_dat_i     (mmc_rspf_dat),         // MMC response fifo
    .opc_rspf_we_i      (mmc_rspf_wen),         // response fifo write line             
    .opc_rspf_mt_o      (mmc_rspf_mt),          // response fifo empty
    .opc_rspf_fl_o      (mmc_rspf_fl),          // response fifo full
    .opc_rspf_reset_i   (opc_fifo_rst),         // Synchronous mmc response fifo reset
    .opc_rspf_cnt_o     (mmc_rspf_cnt),         // MMC response fifo fill level

    // Debugging, these go from 0300003F down
    .opc_oc_cnt_i      (opc_count),                             // first_opcode__last_opcode__opcodes_procesed
    .opc_status1_i     ({9'd0, opc_state, 8'd0, opc_status}),   // opc_state__opc_status
    .opc_status2_i     ({8'd0, opc_rspf_cnt[7:0], 8'd0, opc_fif_cnt[7:0]}), // rsp_fifo_count__opc_fifo_count
    .opc_status3_i     ({16'h0000, dbg_opcodes[15:0]}),         // first_opcode__last_opcode in lower 16 bits
    .sys_status4_i     (frequency),                             // system frequency setting in Hertz
    .sys_status5_i     ({15'h0, SYN_STAT, 4'd0, dbm_x10}) // MS 16 bits=SYN_STAT pin,1=PLL_LOCK, 0=not locked. 16 LSB's=power(dBm x10) setting
    );


  // Frequency processor instance. 
  // Input:requested frequency in MHz in fifo
  // Output:Programs DDS chip on DDS SPI
  freq_s4 freq_processor
  (
    .sys_clk            (sys_clk),
    .sys_rst_n          (sys_rst_n),
    
    .freq_en            (opc_enable),

    // Frequency(ies) are in Hz in input fifo
    .frq_fifo_i         (frq_fifo_dat_o),       // frequency fifo
    .frq_fifo_ren_o     (frq_fifo_ren),         // fifo read line
    .frq_fifo_empty_i   (frq_fifo_mt),          // fifo empty flag
    .frq_fifo_count_i   (frq_fifo_count),       // fifo count, for debug message only

    .ftw_o              (ftw_fifo_dat_i),       // frequency tuning word fifo input(SPI data) to DDS SPI          
    .ftw_wen_o          (ftw_fifo_wen),         // frequency tuning word fifo we.

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

    .doInit_i           (hardware_init),         // Initialize DAC's

    .pwr_fifo_i         (pwr_fifo_dat_o),       // power processor fifo input
    .pwr_fifo_ren_o     (pwr_fifo_ren),         // power processor fifo read line
    .pwr_fifo_mt_i      (pwr_fifo_mt),          // power fifo empty flag
    .pwr_fifo_count_i   (pwr_fifo_count),       // power fifo count

    .VGA_MOSI_o         (pwr_mosi),
    .VGA_SCLK_o         (pwr_sclk),
    .VGA_SSn_o          (pwr_ssn),       
    .VGA_VSW_o          (pwr_vsw),              // Gain mode control

    .frequency_i        (frequency),            // current system frequency
    
    .dbmx10_o           (dbm_x10),              // present power setting for all top-level modules to access

    .status_o           (pwr_status)            // 0=busy, SUCCESS when done, or an error code
  );

  // Pulse processor instance. 
  // Input:pulse data in fifo
  // Output:Programs RFGATE and does ZMON measurements
  pulse #(
    .FILL_BITS(`PWR_FIFO_FILL_BITS)
  )
  pls_processor 
  (
    .sys_clk            (sys_clk),
    .sys_rst_n          (sys_rst_n),
    
    .pulse_en           (opc_enable),

    .pls_fifo_dat_i     (pls_fifo_dat_o),       // pulse processor fifo input
    .pls_fifo_ren_o     (pls_fifo_ren),         // pulse processor fifo read line
    .pls_fifo_mt_i      (pls_fifo_mt),          // pulse fifo empty flag
    .pls_fifo_count_i   (pls_fifo_count),       // pulse fifo count

    .rf_enable_i        (1'b1),                 // RF enabled by MCU, Interlock, etc.
    .rf_gate_o          (pls_rfgate),           // RF_GATE line
    .rf_gate2_o         (pls_rfgate2),          // RF_GATE2 line
    .dbg_rf_gate_i      (dbg_opc_rfgate),       // Debug mode assert RF_GATE lines

    .zmon_en_o          (pls_zmonen),           // Enable ZMON
    .conv_o             (CONV),                 // CONV pulse
    .adc_sclk_o         (ADC_SCLK),             // ZMON SCK
    .adcf_sdo_i         (ADCF_SDO),             // FWD SDO
    .adcr_sdo_i         (ADCR_SDO),             // REFL SDO
    .adctrig_i          (ADCTRIG),              // Host read request

    // output ZMON ADC data fifo
    .adc_fifo_dat_o     (meas_fifo_dat_i),      // 32 bits of FWD REFL ADC data written to output fifo
    .adc_fifo_wen_o     (meas_fifo_wen),        // ADC results fifo write enable

    .status_o           (pls_status)            // 0=busy, SUCCESS when done, or an error code
  );


  patterns #(
        .PTN_DEPTH(`PATTERN_DEPTH),
        .PTN_BITS(`PATTERN_FILL_BITS),
        .WIDTH(`PATTERN_WORD)
  )
  ptn_processor 
  (
    .sys_clk            (sys_clk),
    .sys_rst_n          (sys_rst_n),
  
    .ptn_en             (1'b1), //ptn_proc_en),
    
    .ptn_data_io        (ptn_data),             // Write pattern data word from opcode processor during pattern load
                                                // Read word from pattern RAM when running pattern
    .ptn_addr_i         (ptn_addr),             // Write to or run from this pattern address
    .ptn_wen_i          (ptn_wen),              // Pattern RAM write enable
    .ptn_cmd_i          (ptn_cmd),              // Command/mode, i.e. writing pattern, run pattern, stop, etc

//    // Read from pattern processor fifo connections
//    .ptn_fif_dat_o      (ptn_fif_dat),          // pattern opcode fifo to mux
//    .ptn_fif_ren_i      (ptn_fif_ren),          // pattern opcode fifo read enable
//    .ptn_fif_mt_o       (ptn_fif_mt),           // pattern opcode fifo empty
//    .ptn_rd_cnt_o       (ptn_fif_cnt),          // pattern opcode fifo fill level 
//    .ptn_rd_reset_i     (ptn_inpf_rst),         // Synchronous pattern opcode fifo reset
//    // Write to pattern processor response fifo connections
//    .ptn_rspf_dat_i     (ptn_rspf_dat),         // pattern response fifo
//    .ptn_rspf_we_i      (ptn_rspf_wen),         // response fifo write line             
//    .ptn_rspf_mt_o      (ptn_rspf_mt),          // response fifo empty
//    .ptn_rspf_fl_o      (ptn_rspf_fl),          // response fifo full
//    .ptn_rspf_reset_i   (opc_fifo_rst),         // Synchronous mmc response fifo reset
//    .ptn_rspf_cnt_o     (ptn_rspf_cnt),         // pattern response fifo fill level

    .status_o           (ptn_status)            // pattern processor status
  );

// ******************************************************************************
// *                                                                            *
// *  03/28/2017  JLC                                                           *
// *    - refactored opcode processor instantiation now at top-level.           *
// *                                                                            *
// ******************************************************************************

  opcodes #(
     .MMC_FILL_LEVEL_BITS(`GLBL_MMC_FILL_LEVEL_BITS),
     .RSP_FILL_LEVEL_BITS(`GLBL_RSP_FILL_LEVEL_BITS),
     .PTN_FILL_BITS(`PATTERN_FILL_BITS)
  ) opcode_processor (
    .sys_rst_n                  (sys_rst_n),
    .sys_clk                    (sys_clk),

    .enable                     (opc_enable),

    .fifo_dat_i                 (opc_fif_dat),      // fifo read data bus
    .fifo_rd_en_o               (opc_fif_ren),      // fifo read line
    .fifo_rd_empty_i            (opc_fif_mt),       // fifo empty flag
    .fifo_rd_count_i            (opc_fif_cnt),      // fifo fill level
    .fifo_rst_o                 (opc_inpf_rst),     // opcode processor resets input fifo at first null opcode 

    .system_state_i             (sys_state),        // s4 system state (e.g. running a pattern)
    .mode_o                     (sys_mode),         // MODE opcode can set system-wide flags
    .pulse_busy_i               (pulse_busy),       // Pulse processor is busy

    .response_o                 (opc_rspf_dat),     // to mmc fifo, response bytes(status, measurements, echo, etc)
    .response_wr_en_o           (opc_rspf_wen),     // response fifo write enable
    .response_fifo_empty_i      (opc_rspf_mt),      // response fifo empty flag
    .response_fifo_full_i       (opc_rspf_fl),      // response fifo full  flag
    // response_ready when fifo_length==response_length
    .response_ready_o           (opc_rsp_rdy),      // response fifo is waiting
    .response_length_o          (opc_rsp_len),      // update response length when response is ready
    .response_fifo_count_i      (opc_rspf_cnt),     // response fifo count

    .frequency_o                (frq_fifo_dat_i),   // to fifo, frequency output in MHz
    .frq_wr_en_o                (frq_fifo_wen),     // frequency fifo write enable
    .frq_fifo_empty_i           (frq_fifo_mt),      // frequency fifo empty flag
    .frq_fifo_full_i            (frq_fifo_full),    // frequency fifo full flag
                                                    
    .power_o                    (pwr_fifo_dat_i),   // to fifo, power & opcode in upper 7 bits
    .pwr_wr_en_o                (pwr_fifo_wen),     // power fifo write enable
                                                    
    .pulse_o                    (pls_fifo_dat_i),   // to fifo, pulse opcode
    .pulse_wr_en_o              (pls_fifo_wen),     // pulse fifo write enable

    .meas_fifo_dat_i            (meas_fifo_dat_o),  // measurement fifo from pulse opcode
    .meas_fifo_ren_o            (meas_fifo_ren),    // measurement fifo read enable
    .meas_fifo_cnt_i            (meas_fifo_count),  // measurements in fifo after pulse/pattern
                                                    
    .bias_enable_o              (bias_en),          // bias control

    // pattern opcodes are saved in pattern RAM.
    .ptn_wen_o                  (ptn_wen),          // opcode processor saves pattern opcodes to pattern RAM 
    .ptn_addr_o                 (ptn_addr),         // address 
    .ptn_data                   (ptn_data),         // 12 bytes, 3 bytes patClk tick, 9 bytes for opcode, length, and data   
    .ptn_proc_en_o              (ptn_proc_en),      // Run pattern processor 
    .ptn_start_addr_o           (ptn_start_addr),   // address 
                                                    
    .opcode_counter_o           (opc_count),        // count opcodes for status info   
                                                        
    // Debugging
    .status_o                   (opc_status),         // NULL opcode terminates, done=0, or error code
    .state_o                    (opc_state),          // For debugger display
    .dbg_opcodes_o              (dbg_opcodes)         // first ocode__last_opcode
    // .last_length_o              ()                   //    
  );

// ******************************************************************************
// * JLC Debug SPI (for AD9954)                                                 *
// *                                                                            *
// *  07/17/2017  JLC                                                           *
// *    - instantiating AD9954 dds spi module.                                  *
// *                                                                            *
// ******************************************************************************  
    dds_spi #(
      .VRSN                       (`VERSION),
      .CLK_FREQ                   (`GLBL_CLK_FREQ),
      .SPI_CLK_FREQ               (25000000)
    ) dds_spi_io
    (                                                      // 
      // infrastructure, etc.
      .clk_i                      (sys_clk),               // 
      .rst_i                      (!sys_rst_n),            // 
  
      .doInit_i                   (hardware_init),         // do an init sequence. 
      .hwdbg_dat_i                (36'd0),                 // hwdbg data input.
      .hwdbg_we_i                 (1'b0),                  // hwdbg we.
      .freqproc_dat_i             (ftw_fifo_dat_i),        // frequency tuning word fifo input(SPI data).
      .freqproc_we_i              (ftw_fifo_wen),          // frequency tuning word fifo we.
      .dds_fifo_full_o            (ftw_fifo_full),         // ftw fifo full.
      .dds_fifo_empty_o           (ftw_fifo_mt),           // ftw fifo empty.
      .dds_spi_sclk_o             (rmr_DDS_SCLK),          // 
      .dds_spi_mosi_o             (rmr_DDS_MOSI),          //
      .dds_spi_miso_i             (rmr_DDS_MISO),          // 
      .dds_spi_ss_n_o             (rmr_DDS_SSn),           // 
      .dds_spi_iorst_o            (rmr_DDS_IORST),         // 
      .dds_spi_ioup_o             (rmr_DDS_IOUP),          // 
      .dds_spi_sync_o             (rmr_DDS_SYNC),          // 
      .dds_spi_ps0_o              (rmr_DDS_PS0),           // 
      .dds_spi_ps1_o              (rmr_DDS_PS1),           // 
      
      // DDS will drive SYN_MUTEn, 1=>RF; 0=>MUTE.
      .dds_synth_mute_n_o         (dds_synth_mute_n),     // mute SYN whilst changing frequency
      .dds_synth_stat_i           (syn_synth_mute_n),  // SYN Lock not working yet   SYN_STAT),             // ON=SYN PLL is locked
      .dds_synth_doInit_o         (dds_synth_doInit),     // Init SYN when DDS init has completed
      .dds_synth_initing_o        (dds_synth_initing),    // Init SYN when DDS init has completed
  
      .dbg0_o                     (),             //
      .dbg1_o                     (),             //
      .dbg2_o                     (),             // DDS_IORST
      .dbg3_o                     ()              // DDS_IOUP
     );


// ******************************************************************************
// * JLC SPI (for LTC6946)                                                 *
// *                                                                            *
// *  08/06/2017  JLC                                                           *
// *    - instantiating LTC6946 SYN spi module.                                  *
// *                                                                            *
// ******************************************************************************  
    ltc_spi #(
      .VRSN                       (`VERSION),
      .CLK_FREQ                   (`GLBL_CLK_FREQ),
      .SPI_CLK_FREQ               (20000000)
    ) syn_spi_io
    (
      .clk_i                        (sys_clk),               // 
      .rst_i                        (!sys_rst_n),            // 
      .doInit_i                     (synth_doInit),          // do an init sequence after DDS init has finished or on debug command h0020 
      .hwdbg_dat_i                  (12'd0),                 // hwdbg data input.
      .hwdbg_we_i                   (1'b0),                  // hwdbg we.
      .syn_fifo_full_o              (),                      // opcproc fifo full.
      .syn_fifo_empty_o             (),                      // opcproc fifo empty.
      .syn_spi_sclk_o               (synth_sclk),            // 
      .syn_spi_mosi_o               (synth_mosi),            //
      .syn_spi_miso_i               (SYN_MISO),              // 
      .syn_spi_ss_n_o               (synth_ssn),             // 
      .syn_stat_i                   (SYN_STAT),              // Features set by LTC6946.reg1[5:0] (addr == 4'h1)
      .syn_mute_n_o                 (syn_synth_mute_n),      // 1=>RF; 0=>MUTE.
      .dbg0_o                       (),                      // SYN_SSn.
      .dbg1_o                       (),                      // syn_ops_shftr[15]
      .dbg2_o                       (),                      // SYN_SCLK
      .dbg3_o                       ()                       // syn_initing
    );



// ******************************************************************************
// * Opcode mux between MMC fifos and pattern processor fifos                   *
// ******************************************************************************
opc_mux #(
  .MMC_FILL_LEVEL_BITS(`GLBL_MMC_FILL_LEVEL_BITS),
  .RSP_FILL_LEVEL_BITS(`GLBL_RSP_FILL_LEVEL_BITS)
)
opcode_io
(
  .sys_clk                    (sys_clk),
  .sys_rst_n                  (sys_rst_n),
  .enable_i                   (opc_fifo_enable),

  .select_i                   (1'b0),             // 1'b0=>MMC, 1'b1=>pattern processor fifos

    // opcode processor connections. opc_fifo_full local var not used
  .opc_fif_dat_o              (opc_fif_dat),      // output of mux, input to opcode processor
  .opc_fif_ren_i              (opc_fif_ren),      // fifo read line, from opcode processor to MMC fifo
  .opc_fif_mt_o               (opc_fif_mt),       // MMC opcode fifo empty flag to opcode processor
  .opc_fif_cnt_o              (opc_fif_cnt),      // MMC fifo fill level to opcode processor
  .opc_inpf_rst_i             (opc_inpf_rst),     // opcode processor resets input fifo at first null opcode, opc to MMC/BKD fifo

  .opc_rspf_dat_i             (opc_rspf_dat),     // from opcode processor to MMC response fifo
  .opc_rspf_wen_i             (opc_rspf_wen),     // MMC response fifo write enable
  .opc_rspf_mt_o              (opc_rspf_mt),      // MMC response fifo empty
  .opc_rspf_fl_o              (opc_rspf_fl),      // MMC response fifo full
  .opc_rspf_cnt_o             (opc_rspf_cnt),     // MMC response fifo count
  .opc_rsp_rdy_i              (opc_rspf_rdy),     // response fifo is waiting
  .opc_rsp_len_i              (opc_rsp_len),      // response length written by opcode processor

    // mux'd connections
    // mux 0, default, is MMC fifo's
  .mmc_fif_dat_i              (mmc_fif_dat),      // mux 0 is MMC
  .mmc_fif_ren_o              (mmc_fif_ren),      //
  .mmc_fif_mt_i               (mmc_fif_mt),       //
  .mmc_fif_cnt_i              (mmc_fif_cnt),      //
  .mmc_inpf_rst_o             (mmc_inpf_rst),     //

  .mmc_rspf_dat_o             (mmc_rspf_dat),     //
  .mmc_rspf_wen_o             (mmc_rspf_wen),     //
  .mmc_rspf_mt_i              (mmc_rspf_mt),      //
  .mmc_rspf_fl_i              (mmc_rspf_fl),      //
  .mmc_rspf_cnt_i             (mmc_rspf_cnt),     //
  .mmc_rsp_rdy_o              (mmc_rsp_rdy),      //
  .mmc_rsp_len_o              (mmc_rsp_len),      // response length written by opcode processor

    // mux 1, pattern processor fifo's
  .ptn_fif_dat_i              (ptn_fif_dat),     // mux 1 is pattern processor
  .ptn_fif_ren_o              (ptn_fif_ren),     //
  .ptn_fif_mt_i               (ptn_fif_mt),      //
  .ptn_fif_cnt_i              (ptn_fif_cnt),     //
  .ptn_inpf_rst_o             (ptn_inpf_rst),    // Reset opcode processor input fifo, to pattern processor fifo

  .ptn_rspf_dat_o             (ptn_rspf_dat),    //
  .ptn_rspf_wen_o             (ptn_rspf_wen),    //
  .ptn_rspf_mt_i              (ptn_rspf_mt),     //
  .ptn_rspf_fl_i              (ptn_rspf_fl),     //
  .ptn_rspf_cnt_i             (ptn_rspf_cnt),    //
  .ptn_rsp_rdy_o              (ptn_rsp_rdy),     //
  .ptn_rsp_len_o              (ptn_rsp_len)      // response length written by opcode processor
);


// ******************************************************************************
// * RMR Debug SPI                                                              *
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
  spi #(.CLK_DIV(3)) debug_spi 
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

  /////////////////////////////////
  // Concurrent assignments
  /////////////////////////////////

  // Flag when pulse processor is busy. Opcode processor has to wait for done to return measurements
  assign pulse_busy = (pls_status == 8'd1) ? 1'b0 : 1'b1;

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
  
  // SPI debug command processsor
  // ******************************************************
  // ** 18-Jul-2017 note: 0x4000 is used to turn ON SPI  **
  // ** debug mode. Otherwise SPI outputs are driven by  **
  // ** various processor modules.                       **
  // ******************************************************     
  assign dbg_spi_busy = (spi_state == `SPI_IDLE) ? 1'b0 : 1'b1;  
  // Connect SPI to wires based on which device is selected.
  localparam SPI_VGA = 4'd1, SPI_SYN = 4'd2, SPI_DDS = 4'd3, SPI_ZMON = 4'd4;

  // S4 Enables/lines
  localparam BIT_RF_GATE          = 16'h0001;
  localparam BIT_RF_GATE2         = 16'h0002;
  localparam BIT_VGA_VSW          = 16'h0004;
  localparam BIT_DRV_BIAS_EN      = 16'h0008;
  localparam BIT_PA_BIAS_EN       = 16'h0010;
  localparam BIT_SYN_INIT         = 16'h0020;       // 15-Aug use to cause SYN init
  localparam BIT_SYN_MUTE         = 16'h0040;
  localparam BIT_DDS_IORST        = 16'h0080;
  localparam BIT_DDS_IOUP         = 16'h0100;
  localparam BIT_DDS_SYNC         = 16'h0200;
  localparam BIT_DDS_PS0          = 16'h0400;
  localparam BIT_DDS_PS1          = 16'h0800;
  localparam BIT_ZMON_EN          = 16'h1000;
  localparam BIT_DDS_INIT         = 16'h2000;                           // Do DDS init sequence
  localparam BIT_SPI_DBG_MODE     = 16'h4000;                           // Enable this SPI debugger
  localparam BIT_TEMP_SYS_RST     = 16'h8000;

  // Mux these debug controls
  assign dbg_spi_mode = ((dbg_enables & BIT_SPI_DBG_MODE) == 16'h4000); // Mux SPI outputs   
  assign hardware_init = ((dbg_enables & BIT_DDS_INIT) == BIT_DDS_INIT) || hw_init;

  assign SYN_SSn  = (dbg_spi_mode && dbg_spi_device == SPI_SYN) ? SPI_SSn  : synth_ssn;
  assign SYN_SCLK = (dbg_spi_mode && dbg_spi_device == SPI_SYN) ? SPI_SCLK : synth_sclk;
  assign SYN_MOSI = (dbg_spi_mode && dbg_spi_device == SPI_SYN) ? SPI_MOSI : synth_mosi;

  assign DDS_SSn  = (dbg_spi_mode && dbg_spi_device == SPI_DDS) ? SPI_SSn  : rmr_DDS_SSn;
  assign DDS_SCLK = (dbg_spi_mode && dbg_spi_device == SPI_DDS) ? SPI_SCLK : rmr_DDS_SCLK;
  assign DDS_MOSI = (dbg_spi_mode && dbg_spi_device == SPI_DDS) ? SPI_MOSI : rmr_DDS_MOSI;

  // VGA SPI mux, connect to debug SPI or power processor
  wire dbg_vgavsw;
  assign dbg_vgavsw = ((dbg_enables & BIT_VGA_VSW) == BIT_VGA_VSW);  
  assign VGA_VSW = dbg_spi_mode ? dbg_vgavsw : pwr_vsw;
  assign VGA_SSn  = (dbg_spi_mode && dbg_spi_device == SPI_VGA) ? SPI_SSn  : pwr_ssn;
  assign VGA_SCLK = (dbg_spi_mode && dbg_spi_device == SPI_VGA) ? SPI_SCLK : pwr_sclk;
  assign VGA_MOSI = (dbg_spi_mode && dbg_spi_device == SPI_VGA) ? SPI_MOSI : pwr_mosi;
  assign VGA_VSWn = !VGA_VSW;

  // RF_GATE outputs, from dbg_enables or pulse processor
  wire dbg_rfgate;
  assign dbg_rfgate = ((dbg_enables & BIT_RF_GATE) == BIT_RF_GATE);  
  assign RF_GATE = dbg_spi_mode ? dbg_rfgate : pls_rfgate;
  wire dbg_rfgate2;
  assign dbg_rfgate2 = ((dbg_enables & BIT_RF_GATE2) == BIT_RF_GATE2);  
  assign RF_GATE2 = dbg_spi_mode ? dbg_rfgate2 : pls_rfgate2;

  wire dbg_bias;
  assign dbg_bias = ((dbg_enables & BIT_PA_BIAS_EN) == BIT_PA_BIAS_EN);  
  assign DRV_BIAS_EN = dbg_spi_mode ? dbg_bias : bias_en;
  assign PA_BIAS_EN = DRV_BIAS_EN;
  
  wire dbg_synth_mute_n;
  assign dbg_synth_mute_n = ((dbg_enables & BIT_SYN_MUTE) == BIT_SYN_MUTE);
  wire synth_mute_n;
  assign synth_mute_n = (dds_synth_mute_n & syn_synth_mute_n);
  assign SYN_MUTEn = dbg_spi_mode ? dbg_synth_mute_n : synth_mute_n;

  // Cause SYN Init on BIT_SYN_INIT assert
  assign dbg_syn_doInit = ((dbg_enables & BIT_SYN_INIT) == BIT_SYN_INIT);
  assign synth_doInit = (dbg_syn_doInit || dds_synth_doInit) ? 1'b1 : 1'b0;
  
  wire dbg_ddsiorst;
  assign dbg_ddsiorst = ((dbg_enables & BIT_DDS_IORST) == BIT_DDS_IORST); 
  assign DDS_IORST = dbg_spi_mode ? dbg_ddsiorst : rmr_DDS_IORST;
  
  wire dbg_ddsioup;
  assign dbg_ddsioup = ((dbg_enables & BIT_DDS_IOUP) == BIT_DDS_IOUP);
  assign DDS_IOUP = dbg_spi_mode ? dbg_ddsioup : rmr_DDS_IOUP;
  
  wire dbg_ddssync;
  assign dbg_ddssync = ((dbg_enables & BIT_DDS_SYNC) == BIT_DDS_SYNC);
  assign DDS_SYNC = dbg_spi_mode ? dbg_ddssync : rmr_DDS_SYNC;
  
  wire dbg_ddsps0;
  assign dbg_ddsps0 = ((dbg_enables & BIT_DDS_PS0) == BIT_DDS_PS0);
  assign DDS_PS0 = dbg_spi_mode ? dbg_ddsps0 : rmr_DDS_PS0;
   
  wire dbg_ddsps1;
  assign dbg_ddsps1 = ((dbg_enables & BIT_DDS_PS1) == BIT_DDS_PS1);
  assign DDS_PS1 = dbg_spi_mode ? dbg_ddsps1 : rmr_DDS_PS1;
   
  wire dbg_zmonen;
  assign dbg_zmonen = ((dbg_enables & BIT_ZMON_EN) == BIT_ZMON_EN);
  assign ZMON_EN = dbg_spi_mode ? dbg_zmonen : pls_zmonen;
  
  assign dbg_sys_rst_i = dbg_enables & BIT_TEMP_SYS_RST ? 1'b1 : 1'b0;

  // FPGA_RXD/TXD to/from MMC UART RXD/TXD
  assign syscon_rxd = FPGA_RXD;
  assign FPGA_TXD   = syscon_txd;

  // Debugging, assert RF_GATE lines based on MODE opcode & RF_GATE bit
  assign dbg_opc_rfgate = ((sys_mode[15:0] & BIT_RF_GATE) == BIT_RF_GATE);
 
  assign ACTIVE_LEDn = RF_GATE ? count2[24]: count2[26];
 
  // 22-Jun have to scope MMC signals
  assign FPGA_MCU4 = DDS_MOSI; //DDS_MOSI; //CONV; //MMC_CLK; //count4[15];    //  50MHz div'd by 2^16.
  assign FPGA_MCU3 = DDS_SCLK; //DDS_SCLK; // ADC_SCLK; //MMC_CMD; //count3[15];    // 200MHz div'd by 2^16.
  assign FPGA_MCU2 = SYN_MOSI;  //ZMON_EN;
  assign FPGA_MCU1 = SYN_SCLK;  //MMC_CMD;

  endmodule
