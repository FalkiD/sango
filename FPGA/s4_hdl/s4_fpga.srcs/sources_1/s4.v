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
// Design Name:     s4 top-level instance (for actual hardware)
// File Name:       s4.v
// Module Name:     s4
// Project Name:    Sango
// Target Devices:  xc7a35ticsg324-1L (debug)
// Tool Versions:   Vivado 2015.4 (RMR) & 2016.2 (JLC)
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
//    BEGIN:  Hierarchy table being updated  (JLC 03/17/2017).
//
// Hierarchy:                                                         Scope:
// ----------------------------------------------------------------   -----------------------------------------------------------
//    S4.v                                                            (top)    
//        version.v                                                   (NOTE: included by every non-ip *.v)
// 
//        
//        mmc_test_pack.vhd              mmc_tester                   (top....mmc_tester_0)
//          auto_baud_pack.vhd           auto_baud_with_tracking      (top......auto_baud1)
//          async_syscon_pack            async_syscon                 (top......syscon1)
//            uart_sqclk_pack.vhd        uart_sqclk                   (top........uart1)
//            async_syscon_pack.vhd      async_syscon                 (top........syscon1)
//            flancter_pack.vhd
//            mmc_test_pack.vhd          flancter_rising_pulseout     (top......t_rx_gdcount_reset)  
//            mmc_test_pack.vhd          flancter_rising_pulseout     (top......t_rx_crc_bdcount_reset)
//            mmc_test_pack.vhd          flancter_rising_pulseout     (top......t_rx_stp_bdcount_reset)
//            mmc_test_pack.vhd          flancter_rising_pulseout     (top......t_rx_dat_count_reset)
//            mmc_test_pack.vhd          flancter_rising_pulseout     (top......reg_dbus_size_reset)
//            mmc_test_pack.vhd          test_cmd_receiver            (top......mmc_test_cmd_rx)
//              ucrc_pack.vhd            ucrc_ser                     (top........crc0)
//            mmc_test_pack.vhd          dds_constant_squarewave      (top......tlm_1us_unit)
//            mmc_test_pack.vhd          swiss_army_knife             (top......tlm_fifo_unit)
//            fifo_pack.vhd              swiss_army_ram               (top......fifo_ram)
//            mmc_test_pack.vhd          flancter_rising_pulseout     (top......tlm_start_pulser)
//            mmc_test_pack.vhd          swiss_army_ram               (top......host_0_bram_0)
//            mmc_test_pack.vhd          sd_controller_8bit_bram      (top......sd_host_0)
//              sd_host_pack.vhd         dds_squarewave               (top........sd_clk_dds)
//              sd_host_pack.vhd         sd_cmd_host                  (top........cmd_host_0)
//                ucrc_pack.vhd          ucrc_ser                     (top........crc0)
//              sd_host_pack.vhd         sd_data_8bit_host            (top........sd_data_host0)
//              sd_host_pack.vhd         edge_detector                (top........cmd_int_rst_edge_detect)
//              sd_host_pack.vhd         edge_detector                (top........data_int_rst_edge_detect)
//            mmc_test_pack.vhd          mmc_data_pipe                (top......mmc_slave)
//              sd_card_pack.vhd         sd_card_emulator             (top........mmc_1)
//              sd_card_pack.vhd         swiss_army_ram               (top..........ext_csd_ram)
//              sd_card_pack.vhd         sd_card_cmd_rx               (top..........cmd_receiver)
//                ucrc_pack.vhd          ucrc_ser                     (top............crc0)
//              sd_card_pack.vhd         sd_card_responder            (top..........R1_responder)
//              sd_card_pack.vhd         sd_card_responder            (top..........R2_CID_responder)
//              sd_card_pack.vhd         sd_card_responder            (top..........R2_CSD_responder)
//              sd_card_pack.vhd         sd_card_responder            (top..........R3_responder)
//              sd_card_pack.vhd         sd_card_responder            (top..........R4_responder)
//              sd_card_pack.vhd         sd_card_data_unit            (top..........sd_card_d_handler)
//            sd_card_pack.vhd           swiss_army_fifo_cdc          (top........fifo_from_mmc)
//              sd_card_pack.vhd         swiss_army_ram               (top..........fifo_ram)
//            sd_card_pack.vhd           swiss_army_fifo_cdc          (top........fifo_to_mmc)
//              sd_card_pack.vhd         swiss_army_ram               (top..........fifo_ram)
//            sd_card_pack.vhd           swiss_army_ram               (top........pipe_ram)
//            mmc_test_pack.vhd          swiss_army_fifo              (top......syn_spi_fifo)
//              sd_card_pack.vhd         swiss_army_ram               (top..........fifo_ram)
//            mmc_test_pack.vhd          spi                          (top......syn_spi)
//                                                                                  ^
//                                                                                  |
//               NOTE: "Syn_spi"          is instantiated in mmc_test_pack.vhd -----+
//                      and is defined in spi_master.v.
//          
//            mmc_test_pack.vhd          opcodes                      (top......opcode_processor)
//                                                                                  ^
//                                                                                  |
//               NOTE: "opcode_processor" is instantiated in mmc_test_pack.vhd -----+
//                      and is defined in opcodes.v.
//          
//          
//          
//          
//          
//          
//          
//            mmc_test_pack.vhd          xxxxxxxxxxxx                 (top......yyyyyyyyyyyy)
//        
//        
//
//    END:    Hierarchy table being updated  (JLC 03/17/2017).
//
//  ________          ________          ________          ________          ________          ________          ________          
// /        \________/        \________/        \________/        \________/        \________/        \________/        \________
//
// 
// 
// Revision 0.00.1  early/2016 RMR File Created
// Revision 0.00.1  08/24/2016 JLC Included in debug repository w/ visual changes.
// Revision 1.00.1  03/07/2017 -
//                  03/15/2017 JLC Converted from tb_arty.v/arty_main.v to initial S4 board (s4.v).
//
// Additional Comments: General structure/sequence:
//   Fifo's at top level for: opcodes and opcode processor output
//   such as frequency, power, bias, phase, pulse, etc.
//
//   Processor modules for each item, frequency, power, phase, etc
//   will process their respective fifo data and generate SPI data
//   to be sent to hardware.
//
//   Each SPI device also has a fifo at top level. SPI data is written
//   by each subsystem processor into the corresponding SPI fifo. When a
//   hardware processor has finished generating SPI bytes, a request 
//   to write SPI will be written to the SPI processor.
//
// -----------------------------------------------------------------------------

`include "version.v"
`include "status.h"
//`include "queue_spi.h"
//`include "spi_arbiter.h"

// -----------------------------------------------------------------------------
// `define's
// -----------------------------------------------------------------------------

`define ENTRIES         16
`define MMC_SECTOR_SIZE 512

// For displaying output with LED's. 50MHz clock
//`define MS750      750000000/20     // 750e6 NS/Period = 750ms
//`define MS250      250000000/20     // 250 ms
//`define MS500      500000000/20     // 500 ms
//// Flash 16-bits using 4 led'S every 5 seconds
//`define MS2000     2000000000/20    // 2 seconds 
//`define MS2500     2500000000/20    // 2.5 seconds 
//`define MS3000     3000000000/20    // 3 seconds 
//`define MS3500     3500000000/20    // 3.5 seconds 

//`define MS5000     250000000        // 5 seconds

//`define US150      150000/20        // 150 us
//`define MS001      1500000/20       // 1.5ms 

// Coop's #define's
// 
//                 Temporary workaround for Si514 problem on etch rev A boards
`define ETCHREVA_ALTFPGACLK 1

// -----------------------------------------------------------------------------

module s4
(
`ifndef ETCHREVA_ALTFPGACLK
  input              FPGA_CLK,           //  P10   I        + Diff FPGA CLK From S4 Board U34/Si53307
  input              FPGA_CLKn,          //  N10   I        - and A3/VCC1−B3R−100M000 Oscillator can.
`endif
  output             ACTIVE_LEDn,        //  T14   O       

  inout              MMC_CLK,            //  N11   I        MCU<-->MMC-Slave I/F
  output             MMC_IRQn,           //  P8    O        MCU SDIO_SD pin, low==MMC card present       
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

                                         //     FPGA_MCLK is temporarily the 100MHz LVCMOS33 FPGA Clk Input.  zzm_etchreva
  input              FPGA_MCLK,          //  R13   I                       
                                         //     FPGA_M*   is HW DBG I/F
  input              FPGA_MCU1,          //  P10   I        MCU RSTn to FPGA.
  input              FPGA_MCU2,          //  P11   I
  input              FPGA_MCU3,          //  R12   I    
  input              FPGA_MCU4,          //  R13   I        
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

  output             FPGA_TXD2,          //  R10   O        HW DBG UART
  input              FPGA_RXD2           //  R11   I        HW DBG UART
);

//----------------------------------------------------------------------------------------------

// Local signals
wire        clk0;
wire        clkin;
wire        clkfbprebufg;
wire        clk100prebufg;
wire        clk200prebufg;
wire        clk050prebufg;
wire        clkfb;
wire        clk100;
wire        clk200;
wire        clk050;

reg  [39:0] count1;
reg  [25:0] count2;
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
wire  [7:0] switch;
wire        mmc_tlm;
wire        syscon_rsp;

// MMC card I/O proxy signals
// (During Arty dev they were mapped to jb and jc ports)
wire        MMC_CLK_io;
wire        MMC_CMD_io;
wire  [7:0] MMC_DAT_io;
wire        MMC_CLK_i;
wire        MMC_CMD_i;
wire  [7:0] MMC_DAT_i;

// SPI debugging connections for w 03000030 command
// Write up to 14 byte to SPI device
wire  [7:0] arr_spi_bytes [13:0];
wire  [3:0] dbg_spi_bytes;      // bytes to send
reg   [3:0] dbg_spi_count;      // down counter
wire        dbg_spi_start;
reg         dbg_spi_done;
wire  [2:0] dbg_spi_device;     // 1=VGA, 2=SYN, 3=DDS, 4=ZMON
wire  [15:0] dbg_enables;       // toggle various enables/wires

//------------------------------------------------------------------------
// Start of logic

assign  mmcm_rst_i    = 1'b0;
assign  mmcm_pwrdn_i  = 1'b0;

// +----------------------------------------------------------+
// |  SYSTEM CLOCKS:                                          |
// |  -------------                                           |
// |                                                          |
// |    External:                                             |
// |      FPGA_CLK / FPGA_CLKn = 100MHz from Si514            |
// |      FPGA_MCLK            = 100MHz from LP43S57 / MCU    |
// |                                                          |
// |    Internal:                                             |
// |      clkin      output of main    BUFG                   |
// |                                                          |
// |      sys_clk    100 Mhz FPGA-wide clock.                 |
// |      clk200     200 Mhz FPGA-wide clock.                 |
// |                                                          |
// |                                                          |
// +----------------------------------------------------------+
//

// Following MMCME2_BASE instantiation snarfed & modified from:
//   MMCME2_BASE: Base Mixed Mode Clock Manager
//   7 Series
//   Xilinx HDL Libraries Guide, version 14.7
//     7-Series 2016.4 ug768 (HDL Libs, etc.) pp. 302-307    &
//     7-Series 2016.4 ug472 (Clocking)       pp.  65- 94
//
// From Artix-7 DC/AC Characters DS181:
//   MMCM_Fvcomin =  600MHz
//   MMCM_Fvcomax = 1440MHz
//   Arithmetic Average = 1022MHz
//   Geometric  Average =  930MHz
//   So, use    Fpfd    = 1000MHz (= 1GHz)
//
//
/*
MMCME2_BASE #(
  .BANDWIDTH("OPTIMIZED"), // Jitter programming (OPTIMIZED, HIGH, LOW)
`ifndef ETCHREVA_ALTFPGACLK
  .CLKFBOUT_MULT_F(10.0),  // Multiply value for all CLKOUT (2.000-64.000)   = Fpfd/Fclkin1
`else
  .CLKFBOUT_MULT_F(9.80),  // Multiply value for all CLKOUT (2.000-64.000)   = Fpfd/Fclkin1
`endif
  .CLKFBOUT_PHASE(0.0),    // Phase offset in degrees of CLKFB (-360.000-360.000).
  .CLKIN1_PERIOD(10.0),    // Input clock period in ns to ps resolution (i.e. 33.333 is 30 MHz).
  // CLKOUT0_DIVIDE - CLKOUT6_DIVIDE: Divide amount for each CLKOUT (1-128)
  .CLKOUT0_DIVIDE_F(10.0), // 1000MHz / 10.0 = 100MHz  Divide amount for CLKOUT0 (1.000-128.000).
  .CLKOUT1_DIVIDE(5),      // 1000MHz /  5.0 = 200MHz
  .CLKOUT2_DIVIDE(20),     // 1000MHz / 20.0 =  50MHz
  .CLKOUT3_DIVIDE(1),
  .CLKOUT4_DIVIDE(1),
  .CLKOUT5_DIVIDE(1),
  .CLKOUT6_DIVIDE(1),
  // CLKOUT0_DUTY_CYCLE - CLKOUT6_DUTY_CYCLE: Duty cycle for each CLKOUT (0.01-0.99).
  .CLKOUT0_DUTY_CYCLE(0.5),
  .CLKOUT1_DUTY_CYCLE(0.5),
  .CLKOUT2_DUTY_CYCLE(0.5),
  .CLKOUT3_DUTY_CYCLE(0.5),
  .CLKOUT4_DUTY_CYCLE(0.5),
  .CLKOUT5_DUTY_CYCLE(0.5),
  .CLKOUT6_DUTY_CYCLE(0.5),
  // CLKOUT0_PHASE - CLKOUT6_PHASE: Phase offset for each CLKOUT (-360.000-360.000).
  .CLKOUT0_PHASE(0.0),
  .CLKOUT1_PHASE(0.0),
  .CLKOUT2_PHASE(0.0),
  .CLKOUT3_PHASE(0.0),
  .CLKOUT4_PHASE(0.0),
  .CLKOUT5_PHASE(0.0),
  .CLKOUT6_PHASE(0.0),
  .CLKOUT4_CASCADE("FALSE"), // Cascade CLKOUT4 counter with CLKOUT6 (FALSE, TRUE)
  .DIVCLK_DIVIDE(1), // Master division value (1-106):   Fpfd = CLKIN1/DIVCLK_DIVIDE.
  .REF_JITTER1(0.0), // Reference input jitter in UI (0.000-0.999).
  .STARTUP_WAIT("TRUE") // Delays DONE until MMCM is locked (FALSE, TRUE)
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
*/


`ifndef ETCHREVA_ALTFPGACLK
  BUFG BUFG_clkin  (.I(FPGA_CLK),    .O(clkin));
`else
  BUFG BUFG_clkin  (.I(FPGA_MCLK),   .O(clkin));
`endif
/*
  BUFG BUFG_clkfb  (.I(clkfbunbuf),  .O(clkfb));
  BUFG BUFG_clk100 (.I(clk100unbuf), .O(clk100));
  BUFG BUFG_clk200 (.I(clk200unbuf), .O(clk200));
  BUFG BUFG_clk050 (.I(clk050unbuf), .O(clk050));
*/
  assign clkfb  = 1'b0;
  assign clk200 = 1'b0;
  assign clk050 = 1'b0;

  //assign sys_clk   = clk100;        zzm_etchreva_dbg
  assign sys_clk   = clkin;       //  zzm_etchreva_dbg
  assign sys_rst_n = FPGA_MCU1;     // FPGA_MCU1 is RESETn
  //assign sys_rst_n = 1'b1;        //  zzm_etchreva_dbg

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

// +----------------------------------------------------------+
// |  mmc_tester                                              |
// |  ----------                                              |
// |     initially contains:                                  |
// |       opcode_processor   *                               |
// |       syn_spi_fifo       *                               |
// |       syn_spi            *                               |
// |                                                          |
// |     *  These will be moved to top s4.v level soon.       |
// |                                                          |
// +----------------------------------------------------------+
  mmc_tester #(
    .SYS_CLK_RATE         (100000000.0),    // Fast I/O read/write (app specific)
    .SYS_LEDS             (16),
    .SYS_SWITCHES         (8),
    .EXT_CSD_INIT_FILE    ("ext_csd_init.txt"), // Initial contents of EXT_CSD
    .HOST_RAM_ADR_BITS    (14), // Determines amount of BRAM in MMC host
    .MMC_FIFO_DEPTH       (65536), // (2048),
    .MMC_FILL_LEVEL_BITS  (16),    // (14),
    .MMC_RAM_ADR_BITS     (9)      // 512 bytes, 1st sector (17)
  ) mmc_tester_0 (

    // Asynchronous reset
    .sys_rst_n     (sys_rst_n),
    .sys_clk       (sys_clk),

    // Asynchronous serial interface
    .cmd_i         (FPGA_RXD),
    .resp_o        (syscon_rsp),

    // Board related
    .switch_i      (8'b0000100),
    .led_o         (led_l[0]),

    // Interface for SD/MMC traffic logging
    // via asynchronous serial transmission
    .tlm_send_i    (1'b0),
    .tlm_o         (mmc_tlm),

    // Tester Function Enables
    .slave_en_i    (1'b1),
    .host_en_i     (1'b0),

    // SD/MMC card signals
    .mmc_clk_i     (MMC_CLK_i),
    .mmc_clk_o     (mmc_clk),
    .mmc_clk_oe_o  (mmc_clk_oe),
    .mmc_cmd_i     (MMC_CMD_i),
    .mmc_cmd_o     (mmc_cmd),
    .mmc_cmd_oe_o  (mmc_cmd_oe),
    .mmc_dat_i     (MMC_DAT_i),
    .mmc_dat_o     (mmc_dat),
    .mmc_dat_oe_o  (mmc_dat_oe),
    .mmc_od_mode_o (mmc_od_mode),  // open drain mode, applies to sd_cmd_o and sd_dat_o
    .mmc_dat_siz_o (mmc_dat_siz),
    
    // 31-Mar added a crapload of debug signals
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
  
  // 31-Mar-2017 Add SPI instances to debug on S4
  //////////////////////////////////////////////////////
  // SPI instance for debugging S4
  // We'll run at 12.5MHz (100MHz/8), CPOL=0, CPHA=0
  //////////////////////////////////////////////////////
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
  localparam BIT_RF_GATE     = 12'h001;
  localparam BIT_RF_GATE2    = 12'h002;
  localparam BIT_VGA_VSW     = 12'h004;
  localparam BIT_DRV_BIAS_EN = 12'h008;
  localparam BIT_PA_BIAS_EN  = 12'h010;
  localparam BIT_SYN_STAT    = 12'h020;
  localparam BIT_SYN_MUTE    = 12'h040;
  localparam BIT_DDS_IORST   = 12'h080;
  localparam BIT_DDS_IOUP    = 12'h100;
  localparam BIT_DDS_SYNC    = 12'h200;
  localparam BIT_DDS_PS0     = 12'h400;
  localparam BIT_DDS_PS1     = 12'h800;
  assign RF_GATE = dbg_enables & BIT_RF_GATE ? 1'b1 : 1'b0;
  assign RF_GATE2 = dbg_enables & BIT_RF_GATE2 ? 1'b1 : 1'b0;
  assign VGA_VSW = dbg_enables & BIT_VGA_VSW ? 1'b1 : 1'b0;
  assign VGA_VSWn = !VGA_VSW;       
  assign DRV_BIAS_EN = dbg_enables & BIT_DRV_BIAS_EN ? 1'b1 : 1'b0;
  assign PA_BIAS_EN = dbg_enables & BIT_PA_BIAS_EN ? 1'b1 : 1'b0;
  assign SYN_MUTE = dbg_enables & BIT_SYN_MUTE ? 1'b1 : 1'b0;
  assign DDS_IORST = dbg_enables & BIT_DDS_IORST ? 1'b1 : 1'b0;
  assign DDS_IOUP = dbg_enables & BIT_DDS_IOUP ? 1'b1 : 1'b0;
  assign DDS_SYNC = dbg_enables & BIT_DDS_SYNC ? 1'b1 : 1'b0;
  assign DDS_PS0 = dbg_enables & BIT_DDS_PS0 ? 1'b1 : 1'b0;
  assign DDS_PS1 = dbg_enables & BIT_DDS_PS1 ? 1'b1 : 1'b0;

  // FPGA_TXD to MMC UART output
  assign FPGA_TXD = syscon_rsp;

  // Implement MMC card tri-state drivers at the top level
    // Drive the clock output when needed
  assign MMC_CLK_io = mmc_clk_oe?mmc_clk:1'bZ;
    // Select which data vector to use
  assign mmc_dat_choice1 = mmc_od_mode?mmc_dat_zzz:mmc_dat;
  assign mmc_dat_choice2 = mmc_dat_oe?mmc_dat_choice1:8'bZ;
    // Create mmc command signals
  assign mmc_cmd_zzz    = mmc_cmd?1'bZ:1'b0;
  assign mmc_cmd_choice = mmc_od_mode?mmc_cmd_zzz:mmc_cmd;
  assign MMC_CMD_io = mmc_cmd_oe?mmc_cmd_choice:1'bZ;
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

  assign MMC_DAT_io = mmc_dat_choice3;

  // Map the MMC output proxies to actual FPGA I/O pins
  assign MMC_CLK      = MMC_CLK_io;
  assign MMC_CMD      = MMC_CMD_io;
  assign MMC_DAT7     = MMC_DAT_io[7];
  assign MMC_DAT6     = MMC_DAT_io[6];
  assign MMC_DAT5     = MMC_DAT_io[5];
  assign MMC_DAT4     = MMC_DAT_io[4];
  assign MMC_DAT3     = MMC_DAT_io[3];
  assign MMC_DAT2     = MMC_DAT_io[2];
  assign MMC_DAT1     = MMC_DAT_io[1];
  assign MMC_DAT0     = MMC_DAT_io[0];

  // Map the MMC input  proxies to actual FPGA I/O pins
  assign MMC_CLK_i    = MMC_CLK;
  assign MMC_CMD_i    = MMC_CMD;
  assign MMC_DAT_i    = {MMC_DAT7, MMC_DAT6, MMC_DAT5, MMC_DAT4, MMC_DAT3, MMC_DAT2, MMC_DAT1, MMC_DAT0};
  
//  assign    ACTIVE_LEDn = led_l[0];    //  T14   O       
  assign    ACTIVE_LEDn = count2[24];  //  T14   O       zzm_etchreva_dbg
  assign    MMC_IRQn = 1'b0;           //  P8    O      Assert Card Present always       
  assign    TRIG_OUT = 1'bZ;           //  M16   O       
//  assign    ZMON_EN = 1'bZ;            //  T2    O        ZMon SPI Cnvrt & Read I/F
//  assign    CONV = 1'bZ;               //  M1    O
//  assign    ADC_SCLK = 1'bZ;           //  R1    O
  assign    FPGA_TXD2 = 1'bZ;          //  R10   O        HW DBG UART
  
/////////////////////////////////////////////////////////////////////////////////////////////////////////
    
 /*
    // Debugging UART variables
    wire [15:0]         ctlinw;
    wire [15:0]         statoutw;
    wire [3:0]          ledsw;
    wire [3:0]          ledsgw;
    wire                refclkw;
    wire                TxD_From_Termw;
    wire                RxD_To_Termw;
    wire [6:0]          dbgw;
    // UART Command Processor (includes rcvr.v and xmtr.v).
    uart uart1
    (// diag/debug control signal outputs
     .UART1_CTL(ctlinw),
     .LED(ledsw),
     .LEDG(ledsgw),
 
     // diag/debug status  signal inputs
     .UART1_STAT(statoutw),
     .SW(SW),
     .BTN(btn[2:0]),

     .OPCODES(opcodes_processed),
     .PTN_OPCODES(ptn_opcodes_processed),
     .ARG16(system_state),
     
     // infrastructure, etc.
     .CLK(clk50),                             // Arty 100MHz clock input on E3.
     .RST(RST),                               // Using SW3 as a reset button for now.
     .REFCLK_O(refclkw),                      // temporary test output
     .DBG_UART_TXO(TxD_From_Termw),           // "TX" from USB-SerialBridge to FPGA
     .DBG_UART_RXI(RxD_To_Termw),             // "RX" from FPGA             to USB-SerialBridge
     .DBG_STATE(dbgw) 
     );
 
    assign  JD_GPIO7         = refclkw;
    assign  RGB_GRN[3:0]     = ledsw;
    //assign  {RGB3_Green, RGB2_Green, RGB1_Green, RGB0_Green} = ledsgw & {4{refclkw}};
    assign  TxD_From_Termw   = UART_TXD;
    assign  UART_RXD         = RxD_To_Termw;
    assign  statoutw         = ~ctlinw;
    assign  {JD_GPIO6, JD_GPIO5, JD_GPIO4, JD_GPIO3, JD_GPIO2, JD_GPIO1, JD_GPIO0} = dbgw;
*/

endmodule

