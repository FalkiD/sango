//------------------------------------------------------------------------------
// (C) Copyright 2016, 2017 Ampleon Inc.
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
// Authors:    Rick  Ricgby   <rick.rigby@ampleon.com>
// Purpose:    s4 board fpga.
// -----------------------------------------------------------------------------
// Revisions:
// 0.00.1  early/2016 RMR File Created
// 0.00.1  08/24/2016 JLC Included in debug repository w/ visual changes.
// 1.00.1  03/07/2017 JLC Began converting from tb_arty.v/arty_main.v to initial S4 board (s4.v).
// 1.00.1  04/11/2017 JLC Cont'd by adding HW debug UART.
// 1.00.2  04/25/2017 JLC Updated mmc_tester w/ RMR's dbg_spi_* and DBG_enables interface.
// 1.00.3  05/23/2017 JLC Updated mmc_tester w/ RMR's dbg_spi_* and DBG_enables interface.
//
//------------------------------------------------------------------------------

`define VERSION 16'h1_00_3     // V.vv.r FPGA development revision