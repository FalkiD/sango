`ifndef __OPCODES_H_
`define __OPCODES_H_

// Opcodes, 7 bits
// General & config opcodes, 0x00 based
`define TERMINATOR          7'h00
`define STATUS				7'h01
`define FREQ			    7'h02
`define POWER			    7'h03
`define PHASE			    7'h04
`define PULSE			    7'h05
`define BIAS                7'h06
`define MODE                7'h07
`define LENGTH              7'h08
`define TRIGCONF		    7'h09
`define SYNCCONF		    7'h0A
`define PAINTFCFG		    7'h0B
`define ECHO			    7'h0C
`define RESET               7'h0D
`define CALPWR              7'h0E
// Change bad_opcode() task in opcodes.v when adding/changing opcode list

// Patterns, 0x20 based
`define PTN_PATCLK			7'h20
`define PTN_PATADR			7'h21
`define PTN_PATCTL			7'h22
`define PTN_BRANCH          7'h23
// Change bad_opcode() task in opcodes.v when adding/changing opcode list

// Pattern control bits
`define PTN_RUN             8'h01
`define PTN_STEP            8'h02
`define PTN_RST             8'h04
`define PTN_ABORT           8'h08
`define PTN_END             8'h10
// Change bad_opcode() task in opcodes.v when adding/changing opcode list

// static measurements, 0x30 based
`define MEAS_ZMSIZE			7'h30
`define MEAS_ZMCTL			7'h31
`define MEAS                7'h32
// Change bad_opcode() task in opcodes.v when adding/changing opcode list

//// Debug, 0x40 based
//`define DBG_ATTENSPI		7'h40
//`define DBG_LEVELSPI		7'h41
//`define DBG_OPCTRL			7'h42
//`define DBG_IQCTRL			7'h43
//`define DBG_IQSPI			7'h44
//`define DBG_IQDATA			7'h45
//`define DBG_FLASHSPI		7'h46
//`define DBG_DDSSPI			7'h47
//`define DBG_RSYNSPI			7'h48
//`define DBG_MSYNSPI			7'h49
//`define DBG_MBWSPI			7'h4A
//`define DBG_READREG			7'h4B

// Opcodes/Responses are written in 1-sector minimum chunks
`define SECTOR_SIZE         512

// 25-Jul important bug: if feeder writes into input fifo but doesn't exceed
// this threshhold then one extra byte will get read the next time we're
// above this threshhold. Need to detect and clear this condition
`define MIN_OPCODE_SIZE     2       // Min bytes in read FIFO to process opcodes

// Opcode processor mode/pattern commands
`define OPCODE_NORMAL       4'd0
`define PTNCMD_LOAD         4'd1
`define PTNCMD_RUN          4'd2
`define PTNCMD_STOP         4'd3

`define PATTERN_WR_WORD     96      // 8 bytes data, 1 byte opcode, 3 bytes patclk tick
`define PATTERN_RD_WORD     72      // 8 bytes data, 1 byte opcode

`define PTNDATA_NONE        72'd0

`define SYSCLK_PER_PTN_CLK  6'd10

`define STATUS_RESPONSE_SIZE    16'd26  // 26 bytes defined initially

`endif