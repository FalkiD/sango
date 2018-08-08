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
`define CONFIG			    7'h0C
`define RESET               7'h0D
`define CALPWR              7'h0E
`define CALPTBL             7'h0F
`define CALZMON             7'h10
`define CALVFY              7'h11
`define ALARMS              7'h12
`define OVRD                7'h13
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

//// Bit numbers for MEAS opcode, format of results
//`define M_CALIBRATE         d'0
//`define M_ADC               d'1
//`define M_VOLTS             d'2
//`define M_DBM               d'3

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

`define CFGBIT_0            0
`define CFGBIT_1            1
`define CFGBIT_2            2
`define CFGBIT_ZOFST_CAL    3

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
`define PTNCMD_CLEAR        4'd4

`define PATTERN_WR_WORD     96      // 8 bytes data, 1 byte opcode, 3 bytes patclk tick
`define PATTERN_RD_WORD     72      // 8 bytes data, 1 byte opcode

`define PTNDATA_NONE        72'd0

`define PTNOVRD_OFF         4'hf    // 0-9 are valid indexes, 0xf means override OFF, normal mode

`define SYSCLK_PER_PTN_CLK  6'd9    // 0-based

`define PWR_TBL_ENTRIES       12'd251

`define STATUS_RESPONSE_SIZE    16'd48  // 32 bytes used 01-Aug-2018, was 32, 28 used so far(02-Apr-2018)

`define CALZM_LEN           24          // CAL ZMON opcode data length

// Trigger bit definitions, shifted left 8 due to 1st
// byte of opcode being channel #
`define TRIG_EN             16'h0100
`define TRIG_EXT            16'h0200
`define TRIG_SRC            16'h0400
`define TRIG_RFGT           16'h0800
`define TRIG_CONT           16'h1000
`define TRIG_INVERT         16'h2000
`define TRIG_ARM            16'h8000
`define TRGBIT_EN           8
`define TRGBIT_EXT          9
`define TRGBIT_SRC          10
`define TRGBIT_RFGT         11
`define TRGBIT_CONT         12
`define TRGBIT_INVERT       13
`define TRGBIT_ARM          15

// Alarm condition bit numbers in the 32-bit word
// OPower, UPower, OFreq, UFreq, PllLock, Temp, PlsWid, DCycle
`define ENA_OVER_POWER		7
`define ENA_UNDER_POWER     6
`define ENA_OVER_FREQ       5
`define ENA_UNDER_FREQ      4
`define ENA_PLL_LOCK        3
`define ENA_TEMPERATURE     2
`define ENA_PULSE_WIDTH     1
`define ENA_DUTY_CYCLE		0        

`define RD_OVER_POWER		15
`define RD_UNDER_POWER		14
`define RD_OVER_FREQ		13
`define RD_UNDER_FREQ		12
`define RD_PLL_LOCK         11
`define RD_OPC_ERROR        10
`define RD_PULSE_WIDTH      9
`define RD_DUTY_CYCLE		8

`define LATCH_OVER_POWER	23
`define LATCH_UNDER_POWER	22
`define LATCH_OVER_FREQ		21
`define LATCH_UNDER_FREQ	20
`define LATCH_PLL_LOCK      19
`define LATCH_OPC_ERROR     18
`define LATCH_PULSE_WIDTH   17
`define LATCH_DUTY_CYCLE	16

`endif