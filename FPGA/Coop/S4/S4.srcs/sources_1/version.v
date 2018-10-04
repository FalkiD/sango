//------------------------------------------------------------------------------
// (C) Copyright 3D RF Energy Corp.
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
// File name:  version.v
// Project:    s4
// Authors:    Roger Williams <roger.williams@ampleon.com> (RAW)
// Authors:    Rick  Rigby   <rick.rigby@ampleon.com>
// Purpose:    s4 board fpga.
// -----------------------------------------------------------------------------
// Revisions:
// Revision 0.00.1  early/2016 RMR File Created
// Revision 0.00.1  08/24/2016 JLC Included in debug repository w/ visual changes.
// Revision 1.00.1  03/07/2017 JLC Began converting from tb_arty.v/arty_main.v to initial S4 board (s4.v).
// Revision 1.00.1  04/11/2017 JLC Cont'd by adding HW debug UART.
// Revision 1.00.2  04/25/2017 JLC Updated mmc_tester w/ RMR's dbg_spi_* and DBG_enables interface.
// Revision 1.00.3  06/12/2017 JLC Updated mmc_tester w/ RMR's dbg_spi_* and DBG_enables interface.
// Revision 1.00.4  06/13/2017 JLC Updated HW debug UART (256 bit ctl r/w bus).
// Revision 1.00.5  06/28/2017 JLC Reinplemented `define JLC_TEMP_NO_MMCM.
// Revision 1.00.6  07/10/2017 JLC Working w/ RMR @ Ampleon #1.  Updated HWDBG extended fifo writes.
// Revision 1.00.7  07/10/2017 JLC Working w/ RMR @ Ampleon #2:  RSP_FILL_LEVEL_BITS fix
// Revision 1.00.8  07/10/2017 JLC Working w/ RMR @ Ampleon #3:  DDS SPI 
//                  07/17/2017 JLC Working w/ RMR @ Ampleon #3:  DDS SPI 
// Revision 1.00.9  07/19/2017 JLC Working w/ RMR @ Ampleon #4:  DDS SPI 
// Revision 1.00.A  07/26/2017 RMR Merged Coop & Rick
// Revision 1.00.B  08/01/2017 JLC DDS SPI Init & Re-Freq AD9954
// Revision 1.00.C  08/04/2017 JLC DDS SPI Init & Re-Freq AD9954 & dds.v (esp. sclk-data) cleanup.
// Revision 1.00.D  08/04/2017 JLC SYN SPI Init for LTC6946.
// Revision 1.00.E  08/04/2017 JLC SYN SPI Init for LTC6946 resequenced to wait for DDS init.
// Revision 1.00.F  11/01/2017 RMR STATUS returns VERSION, ZMON_EN, Dac gain/ctrl on CONFIG opcode.
// Revision 1.01.0  11/01/2017 RMR ActiveLed fixes. STATUS returns correct last opcode run.
// Revision 1.01.1  12/13/2017 RMR Refactor using TRGBIT_ definitions for clarity. 
//                                 Bugfix, STATE_LENGTH went to STATE_DATA when rd_line OFF under
//                                 certain 'input fifo length' related conditions. Added EXTRIG.
//				   Released 15-Feb-2018
// Revision 1.01.2  03/10/2018 RMR -Refactor SYN, triggers from falling edge of DDS IOUP. If initialized, only does re-lock.
//                                 -Freq processor waits for DDS & SYN SPI & SYN lock, else error code
//                                 -Freq interpolation works but requires power reset after (not automatic?) 
// Revision 1.01.3             RMR -Freq interpolation works
//                                 -Pattern branch working, loop ~70 pulses. Loop 100 pulses overruns opc?
//                                 -Pulse width fixed, no longer 10ns too wide
//                                 -Pattern branch timing fixed, T no longer 2 ticks too long
// Revision 1.01.4  04/06/2018 RMR -Disabled tweak power, causes cal tables not to load at startup??
//                                 -Fixed PTN_BRANCH loop counter
//                                 -Don't mute synthesizer except during initialization(SYN_MUTE pin & registers removed)
//                                 -Ferrari demo version 
// Revision 1.01.5             RMR -DDS SPI 12.5MHz now (was 6.25MHz)
//                                 -Added d3 config_word bit to enable tweak power after frequency.
//                                  After firmware startup loads cal tables, enable this bit. (If enabled during
//                                  entire startup sequence there's a problem loading the cal tables)
//                                 -Override mode works, frequency & power. Need way to back out(restore original ptn value)
//                                 -Bugfix, 3 bits missing from returned FREQ value in status command.
// Revision 1.01.6  4/30/2018   RMR -Restore overridden FREQ/POWER properly
// Revision 1.01.9  5/20/2018   RMR -Added INVERT TRIGGER support
//									 (Version 1.01.7 was an interim build)
// Revision 1.01.A  7/05/2018   RMR -Added MMC_TRIG line for MCU interrupt
//									 Bring out MMC signals to scope timing constraint before/after
// Revision 1.01.B  7/05/2018   RMR -Added MMC constraints in XDC file
// Revision 1.01.C  7/06/2018   RMR -Golden image created, MMC_TRIG wired but not implemented
//                                   Still using Vivado V2016.4, V2018.1 gives wrong # args error on constraints, need to fix.
// Revision 1.01.D  7/27/2018   RMR -Added ZM_OFST_CAL bit to config word to measure during pulse with RF_GATE off.
//                                   Needed to mease ZMON offsets for calibration
// Revision 1.01.E  7/31/2018   RMR -Added CONFIG register to STATUS opcode, STATUS 48 bytes now
//                                   Don't keep writing MEAS fifo's when they're full
//                                   ZMon ADC values have been shifted left 2, 16-bit 2's complement values
// Revision 1.01.F  8/01/2018   RMR -Fixup ZMon read voltages.
// Revision 1.02.0  8/06/2018   RMR -ZMon read voltages good in SIM? retest on hw
//                                   Added volts to dBm table                       
// Revision 1.02.2  8/08/2018   RMR -Fix # of measurements(1 more bit required)
//                                  -Connected MMC_TRIG to pulse generator, enable via d4 of CONFIG, works                       
// Revision 1.02.3  8/10/2018   RMR -Refactor global defines as top-level parameters.
//                                   Override PATTERN_DEPTH & PATTERN_BITS for S6 from S6 project
//                                   Default values are S4 values. (removed s6.h/s4.h from projects)
// Revision 1.02.4  8/16/2018   RMR -Added alarm interrupt processing. frq,pwr,ptn_status added to
//                                   STATUS opcode.
// Revision 1.02.5  8/28/2018   RMR -Lightweight(released) MMC works(Ovrd, Meas, etc)
//                                   opcode processor bugfix when mmc fifo count=0 in LENGTH state
//                                   (Yesterday:SIM does not work yet, opcode data all 0's?)
// Revision 1.02.6  8/29/2018   RMR -Finish ALARM opcode handling, reset alarms, etc.
//                                  -32k MMC fifo working
//                                  -(SIM working with lightweight MMC core)
// Revision 1.02.7  9/05/2018   RMR -ZMon voltage can be negative, used signed multiplier.
//                                  -Resurrect sign extension for adc values into multiplier(16 to 32-bit sign extend)
// Revision 1.02.8  9/06/2018   RMR -Implemented Zmon power values
//                                  -Simplified sign-extend for faster synthesis.
// Revision 1.02.9  9/07/2018   RMR -Debug dBm calculations in SIM. Calibrated voltage reads working.
// Revision 1.02.A  9/10/2018   RMR -Freq override missing bits was firmware bug. 
//                                  -Remove dBm Zmon code, not needed.
//                                  -Moved debug SPI out of top level module.
// Revision 1.02.B  9/12/2018   RMR -Added ZM_CTRL, ZM_SIZE opcode support for use by ZMonUi app
// Revision 1.02.C  9/12/2018   RMR -Added d1 'Enable' bit to ZM_CTRL opcode
// Revision 1.02.D  9/16/2018   RMR -Bugfix, defer MEAS processing until immediately after pattern run
// Revision 1.02.E  9/18/2018   RMR -More work on deferred MEAS processing. 1.02.D wasn't complete
// Revision 1.02.F  9/18/2018   RMR -1.02.E dramatically better but not perfect. Use better solution, no MMC while ptn running. Works well.
// Revision 1.03.0  9/24/2018   RMR -Fixed 'bytes_processed to be accurate. Bugfix in power override reset.
//
//------------------------------------------------------------------------------

`define VERSION 16'h1_03_0     // V.vv.r FPGA development revision
