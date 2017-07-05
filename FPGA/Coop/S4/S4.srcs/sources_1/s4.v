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
//        version.v                                                   (NOTE: included by every non-ip *.v)
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
//
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
// -----------------------------------------------------------------------------

`include "version.v"
`include "status.h"

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

// >>>>> `define's <<<<<
// 
`define JLC_TEMP_NO_MMCM 1             // 1 -> Don't use MMCME2_BASE; Use 100MHz straight in.  0 -> Use MMCME2_BASE.
`define JLC_TEMP_NO_L12 1              // Temp workaround depop'd L12. JLC 03/17/2017    JLC_TEMP_CLK
`define GLBL_CLK_FREQ_BRD 100000000.0  //  "       "        "      "                     JLC_TEMP_CLK
`define GLBL_CLK_FREQ_MCU 102000000.0  //  "       "        "      "                     JLC_TEMP_CLK
`define CLKFB_FACTOR_BRD 10.000        //  "       "        "      "                     JLC_TEMP_CLK
`define CLKFB_FACTOR_MCU 9.800         //  "       "        "      "                     JLC_TEMP_CLK
`define GLBL_MMC_FILL_LEVEL_BITS 16
`define GLBL_RSP_FILL_LEVEL_BITS 16

// -----------------------------------------------------------------------------

module s4  
(
  // commented out as per <JLC_TEMP_NO_L12>
  //input              FPGA_CLK,           //  P10   I        + Diff FPGA CLK From S4 Board U34/Si53307
  //input              FPGA_CLKn,          //  N10   I        - and A3/100MHx Oscillator can.
  output             ACTIVE_LEDn,        //  T14   O       

  inout              MMC_CLK,            //  N11   IO        MCU<-->MMC-Slave I/F
  output             MMC_IRQn,           //  P8    O        MCU SDIO_SD pin, low==MMC card present       
  inout              MMC_CMD,            //  R7    IO       

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
wire        clk_diff_rcvd;
wire        clkin;
wire        clkfbprebufg;
wire        clk100prebufg;
wire        clk200prebufg;
wire        clk050prebufg;
wire        clkfb;
wire        clk100;
wire        clk200;
wire        clk050;

// <JLC_TEMP_RST>
wire        dbg_sys_rst_i;

reg  [ 9:0] dbg_sys_rst_sr = 0;
//reg         dbg_sys_rst;
reg         dbg_sys_rst_n = 1'b1;

// <JLC_TEMP_DBG>
reg  [39:0] count1;
reg  [25:0] count2;
reg  [15:0] count3;
reg  [15:0] count4;

wire        sys_clk;
wire        sys_rst_n;
wire [15:0] led_l;
wire        mmcm_rst_i;
wire        mmcm_pwrdn_i;
wire        mmcm_locked_o;

// MMC tester
wire        mmc_clk;
wire        mmc_clk_oe;
wire        mmc_cmd;
wire        mmc_cmd_oe;
wire        mmc_cmd_zzz;
wire        mmc_cmd_choice;
wire  [7:0] mmc_dat;
wire  [7:0] mmc_dat_zzz;
wire  [7:0] mmc_dat_choice1;
wire  [7:0] mmc_dat_choice2;
reg   [7:0] mmc_dat_choice3;
wire        mmc_od_mode;
wire        mmc_dat_oe;
wire  [1:0] mmc_dat_siz;
wire        mmc_tlm;

// MMC card I/O proxy signals
wire  [7:0] MMC_DAT_i;

// Backside HW signals  
reg  [15:0] tdbg_reg;
wire [15:0] tdbg_w;

wire        syscon_rxd;
wire        syscon_txd;

// opcode processor wires:
wire        opc_enable_w;
wire [7:0]  opc_fifo_dat_w;

wire        opc_fifo_ren_w;          // fifo read line
wire        opc_fifo_rmt_w;          // fifo empty flag
wire [`GLBL_RSP_FILL_LEVEL_BITS-1:0] opc_fifo_rfl_w;   // fifo fill level

wire [15:0] opc_sys_st_w;            // s4 system state (e.g. running a pattern)
wire [31:0] opc_mode_w;              // MODE opcode can set system-wide flags

wire [7:0]  opc_rspf_w;              // to fifo, response bytes(status, measurements, echo, etc)
wire        opc_rspf_we_w;           // response fifo write enable
wire        opc_rspf_mt_w;           // response fifo empty flag
wire        opc_rspf_fl_w;           // response fifo full  flag
wire        opc_rspf_rdy_w;          // response fifo is waiting
wire [`GLBL_RSP_FILL_LEVEL_BITS-1:0] opc_rsp_lng_w;    // update response length when response is ready
wire [`GLBL_MMC_FILL_LEVEL_BITS-1:0] opc_rsp_cnt_w;    // response fifo count, opcode processor asserts 

wire [31:0] frequency_w;             // to fifo, frequency output in MHz
wire        frq_wr_en_w;             // frequency fifo write enable
wire        frq_fifo_empty_w;        // frequency fifo empty flag
wire        frq_fifo_full_w;         // frequency fifo full flag

wire [31:0] power_w;                 // to fifo, power output in dBm
wire        pwr_wr_en_w;             // power fifo write enable
wire        pwr_fifo_empty_w;        // power fifo empty flag
wire        pwr_fifo_full_w;         // power fifo full flag

      // phase is X7 only, do later
wire [31:0] phase_w;                 // to fifo, phase output in degrees
wire        phs_wr_en_w;             // phase fifo write enable
wire        phs_fifo_empty_w;        // phase fifo empty flag
wire        phs_fifo_full_w;         // phase fifo full flag

wire [63:0] pulse_w;                 // to fifo, pulse opcode
wire        pulse_wr_en_w;           // pulse fifo write enable
wire        pulse_fifo_empty_w;      // pulse fifo empty flag
wire        pulse_fifo_full_w;       // pulse fifo full flag

wire [15:0] bias_w;                  // to fifo, bias opcode
wire        bias_wr_en_w;            // bias fifo write enable
wire        bias_fifo_empty_w;       // bias fifo empty flag
wire        bias_fifo_full_w;        // bias fifo full flag

      // pattern opcodes are saved in pattern RAM.
wire        ptn_wr_en_w;             // opcode processor saves pattern opcodes to pattern RAM 
wire [15:0] ptn_addr_w;              // address 
wire [95:0] ptn_data_w;              // 12 bytes, 3 bytes patClk tick, 9 bytes for opcode, length, and data   

wire        ptn_processor_en_w;      // Run pattern processor 
wire [15:0] ptn_start_addr_w;        // address 

wire [31:0] opcode_counter_w;        // count opcodes for status info                     
wire [7:0]  status_w;                // NULL opcode terminates, done=0, or error code
wire [6:0]  state_w;                 // For debugger display
    
//    // Debugging
wire [7:0]  last_opcode_w;
wire [15:0] last_length_w;

wire [31:0] opc_oc_cnt_w; 

// SPI debugging connections for w 03000030 command
// Write up to 14 byte to SPI device
wire [7:0]  arr_spi_bytes [13:0];
wire [3:0]  dbg_spi_bytes;      // bytes to send
reg  [3:0]  dbg_spi_count;      // down counter
wire        dbg_spi_start;
wire        dbg_spi_busy;
reg         dbg_spi_done;
wire [2:0]  dbg_spi_device;     // 1=VGA, 2=SYN, 3=DDS, 4=ZMON
wire [15:0] dbg_enables;       // toggle various enables/wires


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
  .CLKFBOUT_MULT_F(`CLKFB_FACTOR_MCU),  // Multiply value for all CLKOUT (2.000-64.000)   = Fpfd/Fclkin1
  .CLKFBOUT_PHASE(0.000),  // Phase offset in degrees of CLKFB (-360.000-360.000).
  .CLKIN1_PERIOD(9.800),  // Input clock period in ns to ps resolution (i.e. 33.333 is 30 MHz).
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

//  BUFG BUFG_clkfb  (.I(clkfbprebufg),  .O(clkfb));
//  BUFG BUFG_clk100 (.I(clk100prebufg), .O(clk100));
//  BUFG BUFG_clk200 (.I(clk200prebufg), .O(clk200));
//  BUFG BUFG_clk050 (.I(clk050prebufg), .O(clk050)); 
//  assign sys_clk   = clk100;

// Create a "hwdbg dbg_sys_rst_n" synchronous self-timed pulse. <JLC_TEMP_RST>
always @(posedge sys_clk)
begin
  dbg_sys_rst_sr <= {dbg_sys_rst_sr[8:0], dbg_sys_rst_i};
  dbg_sys_rst_n <= !(&{!dbg_sys_rst_sr[9], | dbg_sys_rst_sr[8:0]});  // output 9 ticks of dbg_sys_rst_n == 1'b0.
end

assign sys_rst_n = MCU_TRIG ? 1'b0 : dbg_sys_rst_n;

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
    count2 <= 0;
  end
  else begin
    count2 <= count2+1;
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
    .MMC_RAM_ADR_BITS     (9)      // 512 bytes, 1st sector (17)
  ) mmc_tester_0 (

    // Asynchronous reset
    .sys_rst_n         (sys_rst_n),
    .sys_clk           (sys_clk),

    // Asynchronous serial interface
    .cmd_i             (syscon_rxd),
    .resp_o            (syscon_txd),

    // Board related
    .led_o             (led_l),

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
    
    // opcode_processor (instantiation of opcodes module) refactored to top level (arty_main.v or s4.v).
    .opc_enable_o      (opc_enable_w),

    .opc_fif_dat_o     (opc_fifo_dat_w),
    .opc_fif_ren_i     (opc_fifo_ren_w),
    .opc_fif_rmt_o     (opc_fifo_rmt_w),
    .opc_rd_cnt_o      (),
    
    .opc_sys_st_o      (opc_sys_st_w),
    .opc_mode_i        (opc_mode_w),
    .opc_rspf_i        (opc_rspf_w),
    .opc_rspf_we_i     (opc_rspf_we_w),
    .opc_rspf_mt_o     (opc_rspf_mt_w),
    .opc_rspf_fl_o     (opc_rspf_fl_w),
    .opc_rspf_rdy_i    (opc_rspf_rdy_w),
//    .opc_rsp_len_i  : in  std_logic(MMC_FILL_LEVEL_BITS-1 downto 0);   
    .opc_rsp_cnt_o     (opc_rsp_cnt_w),
    .opc_oc_cnt_i      (opc_oc_cnt_w),
    
    // Debugging
    .opc_status_i      (status_w),
    .opc_state_i       (state_w),

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
    .dbg_enables_o      (dbg_enables)
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
    .rst_n                      (sys_rst_n),
    .clk                        (sys_clk),

    .enable                     (opc_enable_w),     // 

    .fifo_dat_i                 (opc_fifo_dat_w),   // fifo read data bus
    .fifo_rd_en_o               (opc_fifo_ren_w),   // fifo read line
    .fifo_rd_empty_i            (opc_fifo_rmt_w),   // fifo empty flag
    .fifo_rd_count_i            (opc_fifo_rfl_w),   // fifo fill level

    .system_state_i             (opc_sys_st_w),     // s4 system state (e.g. running a pattern)
    .mode_o                     (opc_mode_w),       // MODE opcode can set system-wide flags

    .response_o                 (opc_rspf_w),       // to fifo, response bytes(status, measurements, echo, etc)
    .response_wr_en_o           (opc_rspf_we_w),    // response fifo write enable
    .response_fifo_empty_i      (opc_rspf_mt_w),    // response fifo empty flag
    .response_fifo_full_i       (opc_rspf_fl_w),    // response fifo full  flag
    .response_ready_o           (opc_rspf_rdy_w),   // response fifo is waiting
    .response_length_o          (opc_rsp_lng_w),    // update response length when response is ready
    .response_fifo_count_i      (opc_rsp_cnt_w),    // response fifo count, opcode processor asserts 
// response_ready when fifo_length==response_length

//    .frequency_o,  // to fifo, frequency output in MHz

//    .frequency_o,  // to fifo, frequency output in MHz
//    .frq_wr_en_o,         // frequency fifo write enable
//    .frq_fifo_empty_i,         // frequency fifo empty flag
//    .frq_fifo_full_i,          // frequency fifo full flag
                                                    
//    .power_o,      // to fifo, power output in dBm
//    .reg pwr_wr_en_o,         // power fifo write enable
//    .pwr_fifo_empty_i,         // power fifo empty flag
//    .pwr_fifo_full_i,          // power fifo full flag
                                                    
// phase is X7 only, do later (not included here)
                                                    
//    .pulse_o,          // to fifo, pulse opcode
//    .pulse_wr_en_o,           // pulse fifo write enable
//    .pulse_fifo_empty_i,           // pulse fifo empty flag
//    .pulse_fifo_full_i,            // pulse fifo full flag
                                                    
//    .bias_o,           // to fifo, bias opcode
//    .bias_wr_en_o,            // bias fifo write enable
//    .bias_fifo_empty_i,            // bias fifo empty flag
//    .bias_fifo_full_i,             // bias fifo full flag
                                                    
    // pattern opcodes are saved in pattern RAM.
//    .ptn_wr_en_o,             // opcode processor saves pattern opcodes to pattern RAM 
//    .ptn_addr_o,       // address 
//    .ptn_data_o,       // 12 bytes, 3 bytes patClk tick, 9 bytes for opcode, length, and data   
//    .ptn_data_i,           // 12 bytes, 3 bytes patClk tick, 9 bytes for opcode, length, and data   
                                                    
//    .ptn_processor_en_o,      // Run pattern processor 
//    .[15:0] ptn_start_addr_o, // address 
                                                    
    .opcode_counter_o           (opc_oc_cnt_w),     // count opcodes for status info   
                                                        
    // Debugging
    .status_o                   (status_w),         // NULL opcode terminates, done=0, or error code
    .state_o                    (state_w)           // For debugger display
    // .last_opcode_o              (),                 //
    // .last_length_o              ()                  //    
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
  assign MMC_IRQn = 1'b0;   //  P8    O      Assert Card Present always
    
  // 31-Mar-2017 Add SPI instances to debug on S4
  //////////////////////////////////////////////////////
  // SPI instance for debugging S4
  // We'll run at 12.5MHz (100MHz/8), CPOL=0, CPHA=0
  //////////////////////////////////////////////////////
  
  // top level SPI busy flag used by mmc_test_pack 
  // SPI debug command processsor
  assign dbg_spi_busy = (spi_state == `SPI_IDLE) ? 1'b0 : 1'b1;  
  // Connect SPI to wires based on which device is selected.
  localparam SPI_VGA = 4'd1, SPI_SYN = 4'd2, SPI_DDS = 4'd3, SPI_ZMON = 4'd4;
  assign VGA_SSn = dbg_spi_device == SPI_VGA ? SPI_SSn : 1'b1;
  assign VGA_SCLK = dbg_spi_device == SPI_VGA ? SPI_SCLK : 1'b0;
  assign VGA_MOSI = dbg_spi_device == SPI_VGA ? SPI_MOSI : 1'b0;

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
  localparam BIT_ZMON_EN          = 16'h1000;
  
  localparam BIT_TEMP_SYS_RST     = 16'h8000;  // <JLC_TEMP_RST>
  
  assign dbg_enables = 16'h0000;

  assign RF_GATE = dbg_enables & BIT_RF_GATE ? 1'b1 : 1'b0;
  assign RF_GATE2 = dbg_enables & BIT_RF_GATE2 ? 1'b1 : 1'b0;
  assign VGA_VSW = dbg_enables & BIT_VGA_VSW ? 1'b1 : 1'b0;
  assign VGA_VSWn = !VGA_VSW;       
  assign DRV_BIAS_EN = dbg_enables & BIT_DRV_BIAS_EN ? 1'b1 : 1'b0;
  assign PA_BIAS_EN = dbg_enables & BIT_PA_BIAS_EN ? 1'b1 : 1'b0;
  assign SYN_MUTE = dbg_enables & BIT_SYN_MUTE ? 1'b0 : 1'b1;
  assign DDS_IORST = dbg_enables & BIT_DDS_IORST ? 1'b1 : 1'b0;
  assign DDS_IOUP = dbg_enables & BIT_DDS_IOUP ? 1'b1 : 1'b0;
  assign DDS_SYNC = dbg_enables & BIT_DDS_SYNC ? 1'b1 : 1'b0;
  assign DDS_PS0 = dbg_enables & BIT_DDS_PS0 ? 1'b1 : 1'b0;
  assign DDS_PS1 = dbg_enables & BIT_DDS_PS1 ? 1'b1 : 1'b0;
  assign ZMON_EN = dbg_enables & BIT_ZMON_EN ? 1'b1 : 1'b0;              // <JLC_TEMP_ZMON_EN>
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
    .VRSN                       (`VERSION)
  ) hwdbg_uart
  (                                                      // diag/debug control signal outputs
    // infrastructure, etc.
    .clk_i                      (sys_clk),               // 
    .rst_i                      (!sys_rst_n),             // 
    .refclk_o                   (),                      // temporary test output
    .RxD_i                      (FPGA_RXD2),             // "RxD" from USB serial bridge to FPGA
    .TxD_o                      (FPGA_TXD2),             // "TxD" from FPGA to USB serial bridge
    
    // diag/debug status  signal inputs
    .hw_stat_i                  (tdbg_reg),
    .gp_opc_cnt_i               (opc_oc_cnt_w),          // count of opcodes processed from top level
    .ptn_opc_cnt_i              (32'hdeadbeef),          // 32-bit input:  count of pattern opcodes processed from top level
    .sys_stat_vec_i             (opc_sys_st_w),          // 16-bit input:  status to show, system_state for now
    .hw_ctl_o                   (tdbg_w),                // 16-bit output: control functions.
    .dbg_o                      (FPGA_MCU2)              //  1-bit output: debug outpin..

   );

   // Snapshot:  capture data for R & S commands.   
   always @(posedge sys_clk) begin
      if (!sys_rst_n) begin
         tdbg_reg                  <= 16'h0000;
      end
      else begin
         tdbg_reg                  <= tdbg_w;
      end
   end  // end of always @ (posedge clk).
   
   
   assign ACTIVE_LEDn = tdbg_reg[15]?count2[24]:count2[25];
   
   // 22-Jun have to scope MMC signals
   //assign FPGA_MCU4 = MMC_CLK; //count4[15];    //  50MHz div'd by 2^16.
   //assign FPGA_MCU3 = MMC_CMD; //count3[15];    // 200MHz div'd by 2^16.

  endmodule

