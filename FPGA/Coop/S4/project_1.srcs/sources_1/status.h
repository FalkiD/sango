//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/06/2016 02:38:16 PM
// Design Name: 
// Module Name: status
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

`ifndef __status_v_
`define __status_v_

// Status definitions
`define SUCCESS                 8'h01
`define ERR_INVALID_OPCODE      8'h02
`define ERR_INVALID_STATE       8'h03
`define ERR_UNKNOWN_FRQ_STATE   8'h04
`define ERR_UNKNOWN_PWR_STATE   8'h05
`define ERR_UNKNOWN_PHS_STATE   8'h06
`define ERR_UNKNOWN_BIAS_STATE  8'h07
`define ERR_UNKNOWN_SPI_STATE   8'h08
`define ERR_SPI_NO_DATA         8'h09
`define ERR_FREQ_CONVERGE       8'h0a
`define ERR_COMMON3_BADDIV      8'h0b
`define ERR_LOWNOISE5_BADDIV    8'h0c
`define ERR_LOWNOISE6_BADDIV    8'h0d
`define ERR_LOWNOISE8_BADDIV    8'h0e
`define ERR_LOWNOISE11_BADDIV   8'h0f
`define ERR_LOWNOISE15_BADDIV   8'h10
`define ERR_LOWNOISE16_BADDIV   8'h11
`define ERR_LOWNOISE20_BADDIV   8'h12
`define ERR_LOWNOISE21_BADDIV   8'h13
`define ERR_LOWNOISE23_BADDIV   8'h14
`define ERR_HISPEED2_BADDIV     8'h15
`define ERR_HISPEED4_BADDIV     8'h16
`define ERR_HISPEED6_BADDIV     8'h17
`define ERR_HISPEED7_BADDIV     8'h18
`define ERR_HISPEED8_BADDIV     8'h19
`define ERR_COMMONFERR_BADDIV   8'h1a
`define ERR_COMMONFOUT_BADDIV   8'h1b
`define ERR_POWER_INVALID       8'h1c
`define ERR_UNKNOWN_PULSE_STATE 8'h1d
`define ERR_PATTERN_OVERRUN     8'h1e
`define ERR_PATTERN_RUNNING     8'h1f
`define ERR_RSP_FIFO_FULL       8'h20

// Overall state definitions
`define STATE_RESET             16'h0001    
`define STATE_INITIALIZING      16'h0002
`define STATE_INITIALIZED       16'h0004
`define STATE_MMC_BUSY          16'h0008
`define STATE_OPC_BUSY          16'h0010
`define STATE_FRQ_BUSY          16'h0020
`define STATE_PWR_BUSY          16'h0040
`define STATE_PHS_BUSY          16'h0080
`define STATE_PLS_BUSY          16'h0100
`define STATE_BIAS_BUSY         16'h0200
`define STATE_MODE_BUSY         16'h0400
`define STATE_PTN_BUSY          16'h0800
`define STATE_SPI_BUSY          16'h1000
`define STATE_RSP_READY         16'h2000

`endif