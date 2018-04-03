//------------------------------------------------------------------------------
// (C) Copyright 2016-2018 Ampleon Inc.
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
// Revision 1.01.6             RMR -Disabled tweak power, causes cal tables not to load at startup?? 
//
//------------------------------------------------------------------------------

`define VERSION 16'h1_01_6     // V.vv.r FPGA development revision
