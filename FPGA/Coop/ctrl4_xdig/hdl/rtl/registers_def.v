//------------------------------------------------------------------------------
// (C) Copyright 2013, NXP Semiconductors
//     All rights reserved.
//
// PROPRIETARY INFORMATION
//
// The information contained in this file is the property of NXP Semiconductors.
// Except as specifically authorized in writing by NXP, the holder of this
// file: (1) shall keep all information contained herein confidential and
// shall protect same in whole or in part from disclosure and dissemination to
// all third parties and (2) shall use same for operation and maintenance
// purposes only.
// -----------------------------------------------------------------------------
// File name:		registers_def.v
// Project:		Ctrl4 extended digital, timing generator image
// Author: 		Roger Williams <roger.williams@nxp.com> (RAW)
// -----------------------------------------------------------------------------
// 2013-11-07 (RAW) Switched from make_registers to manual editing
//------------------------------------------------------------------------------

// RW register definitions
`define TG_DAT_I_DLY_INDEX 15:0
`define TG_TCTRL_AD 5'h00
`define TG_TCTRL_INDEX 31:16
`define TG_TQUEUE_AD 5'h04
`define TG_TQUEUE_INDEX 63:32
`define TG_MCTRL_AD 5'h10
`define TG_MCTRL_INDEX 79:64
`define TG_MCONF_AD 5'h14
`define TG_MCONF_INDEX 95:80
`define TG_DEBUG_AD 5'h1e
`define TG_DEBUG_INDEX 111:96
`define TG_REG_BITS_W 111:0
`define TG_REG_W_NBITS 112

// R register definitions
`define TG_TQ_STAT_AD 5'h02
`define TG_TQ_STAT_INDEX 15:0
`define TG_MQ_STAT_AD 5'h12
`define TG_MQ_STAT_INDEX 31:16
`define TG_MQUEUE_AD 5'h18
`define TG_MQUEUE_INDEX 47:32
`define TG_REG_BITS_R 47:0
`define TG_REG_R_NBITS 48

// control signal definitions
`define TG_TQUEUE_LD_INDEX 0
`define TG_MQUEUE_RD_INDEX 1
`define TG_REG_BITS_CTL 1:0
`define TG_REG_CTL_NBITS 2

// RW register definitions
`define DAT_I_DLY_INDEX 15:0
`define CONF_AD 7'h00
`define CONF_INDEX 31:16
`define TRIG_SRC_AD 7'h02
`define TRIG_SRC_INDEX 47:32
`define CTRL_AD 7'h04
`define CTRL_INDEX 63:48
`define IRQ_MASK_AD 7'h0a
`define IRQ_MASK_INDEX 79:64
`define IRQ_CLR_AD 7'h0c
`define IRQ_CLR_INDEX 95:80
`define SYNC_AD 7'h0e
`define SYNC_INDEX 111:96
`define FILTER_AD 7'h12
`define FILTER_INDEX 127:112
`define MULTIBOOT_AD 7'h7c
`define MULTIBOOT_INDEX 143:128
`define REG_BITS_W 143:0
`define REG_W_NBITS 144

// R register definitions
`define STAT_AD 7'h06
`define STAT_INDEX 15:0
`define IRQ_AD 7'h08
`define IRQ_INDEX 31:16
`define EXTDIG_AD 7'h10
`define EXTDIG_INDEX 47:32
`define VERSION_AD 7'h7e
`define VERSION_INDEX 63:48
`define REG_BITS_R 63:0
`define REG_R_NBITS 64
