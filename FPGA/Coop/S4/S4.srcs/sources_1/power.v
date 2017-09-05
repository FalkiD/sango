//////////////////////////////////////////////////////////////////////////////////
// Company: Ampleon
// Engineer: Rick Rigby
// 
// Create Date: 07/17/2017
// Design Name: S4 power control module
// Module Name: power
// Project Name: 
// Target Devices: Artix-7, DAC7563
// Tool Versions: 
// Description: S4 power is controlled by writing the 2 DAC's of U39,
// DAC7563, at the same time. Values come from the table for the VGA
// chip, U36, ADL5246. DAC values of 0 give full scale output.
//
// ADL5426 VSW and VSWn bypass switches define 
// high gain or low gain mode:
//      VSWn        VSW     Mode
//      0           0       Undefined
//      0           1       High Gain Mode
//      1           0       Low Gain Mode
//      1           1       Undefined
//
//  We'll use high-gain mode, datasheet figure 12 gives gain data
//  at 2.6GHz while varying both VGAIN1 & VGAIN2
//  Looks like 3.3v ~ -12dB, 0v ~ +2dB
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments: Implement power calculations.
// 
//////////////////////////////////////////////////////////////////////////////////

`include "timescale.v"
`include "status.h"
`include "opcodes.h"

module power #(parameter FILL_BITS = 4)
(
  input  wire           sys_clk,
  input  wire           sys_rst_n,
    
  input  wire           power_en,
  
  input  wire           doInit_i,   // Initialize DAC's after reset

  // Power opcode(s) are in input fifo
  // Power opcode byte 0 is channel#, (only 1 channel for S4)
  // byte 1 unused, byte 2 is 8 lsb's,
  // byte 3 is 8 msb's of Q7.8 format power
  // in dBm. (Positive values only)
  // Upper 7 bits are opcode, user power or cal
  input  wire [38:0]    pwr_fifo_i,               // fifo data in
  output reg            pwr_fifo_ren_o,           // fifo read line
  input  wire           pwr_fifo_mt_i,            // fifo empty flag
  input  wire [FILL_BITS-1:0] pwr_fifo_count_i,   // fifo count

  // outputs, VGA SPI to DAC7563
  output wire           VGA_MOSI_o,
  output wire           VGA_SCLK_o,
  output reg            VGA_SSn_o,       
  output wire           VGA_VSW_o,                // VSW controls gain mode, 1=high, 0=low

  input  wire [31:0]    frequency_i,              // current frequency in Hertz
  
  output reg  [11:0]    dbmx10_o,                 // present power setting for all top-level modules to access
  
  output reg  [7:0]     status_o       // 0=busy, SUCCESS when done, or an error code
);

  localparam DBM_OFFSET = 24'd102400;  // 40.0 dBm * 256 * 10
  localparam DBM_MAX_OFFSET = 24'd250; // 251 entries per table at 0.1dBm intervals
  localparam TEN = 16'd10;             // Multiply user power request by 10
  localparam FRQ1 = 32'd2410000000;    // frequency breakpoint 1
  localparam FRQ2 = 32'd2430000000;    // frequency breakpoint 2
  localparam FRQ3 = 32'd2450000000;    // frequency breakpoint 3
  localparam FRQ4 = 32'd2470000000;    // frequency breakpoint 4
  localparam FRQ5 = 32'd2490000000;    // frequency breakpoint 5
  localparam FRQ_DELTA = 16'd20;       // 20MHz between tables
  localparam K = 16'd215;              // K=1/20MHz * 2**32 = 214.74836

  // state modifiers for host set power opcode and initialization mode
  localparam NORMAL_MODE        = 2'd0;
  localparam INIT_DACS          = 2'd1;

  // Main Globals
  reg  [6:0]      state = 0;
  reg  [6:0]      next_state;          // saved while waiting for SPI writes

  reg  [31:0]     power = 0;          // 12 bits of dBm x10 (400 to 650) or Cal data
  reg  [38:0]     pwr_word;           // whole 39 bit word (32 bits cal data, 7 bits opcode)
  reg  [6:0]      pwr_opcode;         // which power opcode, user request or cal?
  wire [63:0]     q7dot8x10;          // Q7.8 user dBm request, 40.0 to 65.0 times 256.0, times 10
  reg  [11:0]     dbm_idx;            // index into power table of user requested power, only using ~8 lsbs
  reg  [31:0]     ten;                // for dbm * 10
  reg  [1:0]      modifier;           // state modifer for host set power opcode and initialize DAC's
  reg  [2:0]      init_wordnum;       // count of initialization words sent. Initially 4 words to setup
  
  // interpolation multiplier vars
  reg  [31:0]     dbmA;
  reg  [31:0]     interp1;
  wire [63:0]     prod1;
  reg             interp_mul;   // enable interpolation multiplier
  
  // interpolation vars
  reg  [31:0]     slope;        // slope * 2**32
  reg             slope_is_neg; // flag if slope is negative
  reg  [15:0]     intercept;

  // enable dbm x10 multiplier
  reg             multiply;
  // Latency for math operations, Xilinx multiplier & divrem divider have no reliable "done" line???
  localparam MULTIPLIER_CLOCKS = 6;
  reg [5:0]       latency_counter;    // wait for multiplier

  // power table of dac values required for dBm output.
  // 5 tables, 2410MHz, 2430MHz, 2450MHz, 2470MHz, 2490MHz
  // Entries in 0.1 dBm steps beginning at 40.0dBm
  // 251 total entries covering 400 to 650 (40.0 to 65.0 dBm)
  reg [11:0]      dbmx10_2410 [250:0] = { 
  12'hf90, 12'hf80, 12'hf70, 12'hf60, 12'hf50, 12'hf40, 12'hf30, 12'hf20,
  12'h800, 12'hf10, 12'hf00, 12'hef0, 12'hee0, 12'hed0, 12'hec0, 12'heb0,
  12'hea0, 12'he90, 12'he80, 12'he70, 12'he60, 12'he50, 12'he40, 12'he30,
  12'he20, 12'he10, 12'he00, 12'hdf0, 12'hde0, 12'hdd0, 12'hdc0, 12'hdb0,
  12'hda0, 12'hd90, 12'hd80, 12'hd70, 12'hd60, 12'hd50, 12'hd40, 12'hd30,
  12'hd20, 12'hd10, 12'hd00, 12'hcf0, 12'hce0, 12'hcd0, 12'hcc0, 12'hcb0,
  12'hca0, 12'hc90, 12'hc80, 12'hc70, 12'hc60, 12'hc50, 12'hc40, 12'hc30,
  12'hc20, 12'hc10, 12'hc00, 12'hbf0, 12'hbe0, 12'hbd0, 12'hbc0, 12'hbb0,
  12'hba0, 12'hb90, 12'hb80, 12'hb70, 12'hb60, 12'hb50, 12'hb40, 12'hb30,
  12'hb20, 12'hb10, 12'hb00, 12'haf0, 12'hae0, 12'had0, 12'hac0, 12'hab0,
  12'haa0, 12'ha90, 12'ha80, 12'ha70, 12'ha60, 12'ha50, 12'ha40, 12'ha30,
  12'ha20, 12'ha10, 12'ha00, 12'h9f0, 12'h9e0, 12'h9d0, 12'h9c0, 12'h9b0,
  12'h9a0, 12'h990, 12'h980, 12'h970, 12'h960, 12'h950, 12'h940, 12'h930,
  12'h920, 12'h910, 12'h900, 12'h8f0, 12'h8e0, 12'h8d0, 12'h8c0, 12'h8b0,
  12'h8a0, 12'h890, 12'h880, 12'h870, 12'h860, 12'h850, 12'h840, 12'h830,
  12'h820, 12'h810, 12'h800, 12'h7f0, 12'h7e0, 12'h7d0, 12'h7c0, 12'h7b0,
  12'h7a0, 12'h790, 12'h780, 12'h770, 12'h760, 12'h750, 12'h740, 12'h730,
  12'h720, 12'h710, 12'h700, 12'h6f0, 12'h6e0, 12'h6d0, 12'h6c0, 12'h6b0,
  12'h6a0, 12'h690, 12'h680, 12'h670, 12'h660, 12'h650, 12'h640, 12'h630,
  12'h620, 12'h610, 12'h600, 12'h5f0, 12'h5e0, 12'h5d0, 12'h5c0, 12'h5b0,
  12'h5a0, 12'h590, 12'h580, 12'h570, 12'h560, 12'h550, 12'h540, 12'h530,
  12'h520, 12'h510, 12'h500, 12'h4f0, 12'h4e0, 12'h4d0, 12'h4c0, 12'h4b0,
  12'h4a0, 12'h490, 12'h480, 12'h470, 12'h460, 12'h450, 12'h440, 12'h430,
  12'h420, 12'h410, 12'h400, 12'h3f0, 12'h3e0, 12'h3d0, 12'h3c0, 12'h3b0,
  12'h3a0, 12'h390, 12'h380, 12'h370, 12'h360, 12'h350, 12'h340, 12'h330,
  12'h320, 12'h310, 12'h300, 12'h2f0, 12'h2e0, 12'h2d0, 12'h2c0, 12'h2b0,
  12'h2a0, 12'h290, 12'h280, 12'h270, 12'h260, 12'h250, 12'h240, 12'h230,
  12'h220, 12'h210, 12'h200, 12'h1f0, 12'h1e0, 12'h1d0, 12'h1c0, 12'h1b0,
  12'h1a0, 12'h190, 12'h180, 12'h170, 12'h160, 12'h150, 12'h140, 12'h130,
  12'h120, 12'h110, 12'h100, 12'h0f0, 12'h0e0, 12'h0d0, 12'h0c0, 12'h0b0,
  12'h0a0, 12'h090, 12'h080, 12'h070, 12'h060, 12'h050, 12'h040, 12'h030,
  12'h020, 12'h010, 12'h000 };

  reg [11:0]      dbmx10_2430 [250:0] = { 
  12'hf90, 12'hf80, 12'hf70, 12'hf60, 12'hf50, 12'hf40, 12'hf30, 12'hf20,
  12'h800, 12'hf10, 12'hf00, 12'hef0, 12'hee0, 12'hed0, 12'hec0, 12'heb0,
  12'hea0, 12'he90, 12'he80, 12'he70, 12'he60, 12'he50, 12'he40, 12'he30,
  12'he20, 12'he10, 12'he00, 12'hdf0, 12'hde0, 12'hdd0, 12'hdc0, 12'hdb0,
  12'hda0, 12'hd90, 12'hd80, 12'hd70, 12'hd60, 12'hd50, 12'hd40, 12'hd30,
  12'hd20, 12'hd10, 12'hd00, 12'hcf0, 12'hce0, 12'hcd0, 12'hcc0, 12'hcb0,
  12'hca0, 12'hc90, 12'hc80, 12'hc70, 12'hc60, 12'hc50, 12'hc40, 12'hc30,
  12'hc20, 12'hc10, 12'hc00, 12'hbf0, 12'hbe0, 12'hbd0, 12'hbc0, 12'hbb0,
  12'hba0, 12'hb90, 12'hb80, 12'hb70, 12'hb60, 12'hb50, 12'hb40, 12'hb30,
  12'hb20, 12'hb10, 12'hb00, 12'haf0, 12'hae0, 12'had0, 12'hac0, 12'hab0,
  12'haa0, 12'ha90, 12'ha80, 12'ha70, 12'ha60, 12'ha50, 12'ha40, 12'ha30,
  12'ha20, 12'ha10, 12'ha00, 12'h9f0, 12'h9e0, 12'h9d0, 12'h9c0, 12'h9b0,
  12'h9a0, 12'h990, 12'h980, 12'h970, 12'h960, 12'h950, 12'h940, 12'h930,
  12'h920, 12'h910, 12'h900, 12'h8f0, 12'h8e0, 12'h8d0, 12'h8c0, 12'h8b0,
  12'h8a0, 12'h890, 12'h880, 12'h870, 12'h860, 12'h850, 12'h840, 12'h830,
  12'h820, 12'h810, 12'h800, 12'h7f0, 12'h7e0, 12'h7d0, 12'h7c0, 12'h7b0,
  12'h7a0, 12'h790, 12'h780, 12'h770, 12'h760, 12'h750, 12'h740, 12'h730,
  12'h720, 12'h710, 12'h700, 12'h6f0, 12'h6e0, 12'h6d0, 12'h6c0, 12'h6b0,
  12'h6a0, 12'h690, 12'h680, 12'h670, 12'h660, 12'h650, 12'h640, 12'h630,
  12'h620, 12'h610, 12'h600, 12'h5f0, 12'h5e0, 12'h5d0, 12'h5c0, 12'h5b0,
  12'h5a0, 12'h590, 12'h580, 12'h570, 12'h560, 12'h550, 12'h540, 12'h530,
  12'h520, 12'h510, 12'h500, 12'h4f0, 12'h4e0, 12'h4d0, 12'h4c0, 12'h4b0,
  12'h4a0, 12'h490, 12'h480, 12'h470, 12'h460, 12'h450, 12'h440, 12'h430,
  12'h420, 12'h410, 12'h400, 12'h3f0, 12'h3e0, 12'h3d0, 12'h3c0, 12'h3b0,
  12'h3a0, 12'h390, 12'h380, 12'h370, 12'h360, 12'h350, 12'h340, 12'h330,
  12'h320, 12'h310, 12'h300, 12'h2f0, 12'h2e0, 12'h2d0, 12'h2c0, 12'h2b0,
  12'h2a0, 12'h290, 12'h280, 12'h270, 12'h260, 12'h250, 12'h240, 12'h230,
  12'h220, 12'h210, 12'h200, 12'h1f0, 12'h1e0, 12'h1d0, 12'h1c0, 12'h1b0,
  12'h1a0, 12'h190, 12'h180, 12'h170, 12'h160, 12'h150, 12'h140, 12'h130,
  12'h120, 12'h110, 12'h100, 12'h0f0, 12'h0e0, 12'h0d0, 12'h0c0, 12'h0b0,
  12'h0a0, 12'h090, 12'h080, 12'h070, 12'h060, 12'h050, 12'h040, 12'h030,
  12'h020, 12'h010, 12'h000 };

  reg [11:0]      dbmx10_2450 [250:0] = { 
  12'hf90, 12'hf80, 12'hf70, 12'hf60, 12'hf50, 12'hf40, 12'hf30, 12'hf20,
  12'h800, 12'hf10, 12'hf00, 12'hef0, 12'hee0, 12'hed0, 12'hec0, 12'heb0,
  12'hea0, 12'he90, 12'he80, 12'he70, 12'he60, 12'he50, 12'he40, 12'he30,
  12'he20, 12'he10, 12'he00, 12'hdf0, 12'hde0, 12'hdd0, 12'hdc0, 12'hdb0,
  12'hda0, 12'hd90, 12'hd80, 12'hd70, 12'hd60, 12'hd50, 12'hd40, 12'hd30,
  12'hd20, 12'hd10, 12'hd00, 12'hcf0, 12'hce0, 12'hcd0, 12'hcc0, 12'hcb0,
  12'hca0, 12'hc90, 12'hc80, 12'hc70, 12'hc60, 12'hc50, 12'hc40, 12'hc30,
  12'hc20, 12'hc10, 12'hc00, 12'hbf0, 12'hbe0, 12'hbd0, 12'hbc0, 12'hbb0,
  12'hba0, 12'hb90, 12'hb80, 12'hb70, 12'hb60, 12'hb50, 12'hb40, 12'hb30,
  12'hb20, 12'hb10, 12'hb00, 12'haf0, 12'hae0, 12'had0, 12'hac0, 12'hab0,
  12'haa0, 12'ha90, 12'ha80, 12'ha70, 12'ha60, 12'ha50, 12'ha40, 12'ha30,
  12'ha20, 12'ha10, 12'ha00, 12'h9f0, 12'h9e0, 12'h9d0, 12'h9c0, 12'h9b0,
  12'h9a0, 12'h990, 12'h980, 12'h970, 12'h960, 12'h950, 12'h940, 12'h930,
  12'h920, 12'h910, 12'h900, 12'h8f0, 12'h8e0, 12'h8d0, 12'h8c0, 12'h8b0,
  12'h8a0, 12'h890, 12'h880, 12'h870, 12'h860, 12'h850, 12'h840, 12'h830,
  12'h820, 12'h810, 12'h800, 12'h7f0, 12'h7e0, 12'h7d0, 12'h7c0, 12'h7b0,
  12'h7a0, 12'h790, 12'h780, 12'h770, 12'h760, 12'h750, 12'h740, 12'h730,
  12'h720, 12'h710, 12'h700, 12'h6f0, 12'h6e0, 12'h6d0, 12'h6c0, 12'h6b0,
  12'h6a0, 12'h690, 12'h680, 12'h670, 12'h660, 12'h650, 12'h640, 12'h630,
  12'h620, 12'h610, 12'h600, 12'h5f0, 12'h5e0, 12'h5d0, 12'h5c0, 12'h5b0,
  12'h5a0, 12'h590, 12'h580, 12'h570, 12'h560, 12'h550, 12'h540, 12'h530,
  12'h520, 12'h510, 12'h500, 12'h4f0, 12'h4e0, 12'h4d0, 12'h4c0, 12'h4b0,
  12'h4a0, 12'h490, 12'h480, 12'h470, 12'h460, 12'h450, 12'h440, 12'h430,
  12'h420, 12'h410, 12'h400, 12'h3f0, 12'h3e0, 12'h3d0, 12'h3c0, 12'h3b0,
  12'h3a0, 12'h390, 12'h380, 12'h370, 12'h360, 12'h350, 12'h340, 12'h330,
  12'h320, 12'h310, 12'h300, 12'h2f0, 12'h2e0, 12'h2d0, 12'h2c0, 12'h2b0,
  12'h2a0, 12'h290, 12'h280, 12'h270, 12'h260, 12'h250, 12'h240, 12'h230,
  12'h220, 12'h210, 12'h200, 12'h1f0, 12'h1e0, 12'h1d0, 12'h1c0, 12'h1b0,
  12'h1a0, 12'h190, 12'h180, 12'h170, 12'h160, 12'h150, 12'h140, 12'h130,
  12'h120, 12'h110, 12'h100, 12'h0f0, 12'h0e0, 12'h0d0, 12'h0c0, 12'h0b0,
  12'h0a0, 12'h090, 12'h080, 12'h070, 12'h060, 12'h050, 12'h040, 12'h030,
  12'h020, 12'h010, 12'h000 };

  reg [11:0]      dbmx10_2470 [250:0] = { 
  12'hf90, 12'hf80, 12'hf70, 12'hf60, 12'hf50, 12'hf40, 12'hf30, 12'hf20,
  12'h800, 12'hf10, 12'hf00, 12'hef0, 12'hee0, 12'hed0, 12'hec0, 12'heb0,
  12'hea0, 12'he90, 12'he80, 12'he70, 12'he60, 12'he50, 12'he40, 12'he30,
  12'he20, 12'he10, 12'he00, 12'hdf0, 12'hde0, 12'hdd0, 12'hdc0, 12'hdb0,
  12'hda0, 12'hd90, 12'hd80, 12'hd70, 12'hd60, 12'hd50, 12'hd40, 12'hd30,
  12'hd20, 12'hd10, 12'hd00, 12'hcf0, 12'hce0, 12'hcd0, 12'hcc0, 12'hcb0,
  12'hca0, 12'hc90, 12'hc80, 12'hc70, 12'hc60, 12'hc50, 12'hc40, 12'hc30,
  12'hc20, 12'hc10, 12'hc00, 12'hbf0, 12'hbe0, 12'hbd0, 12'hbc0, 12'hbb0,
  12'hba0, 12'hb90, 12'hb80, 12'hb70, 12'hb60, 12'hb50, 12'hb40, 12'hb30,
  12'hb20, 12'hb10, 12'hb00, 12'haf0, 12'hae0, 12'had0, 12'hac0, 12'hab0,
  12'haa0, 12'ha90, 12'ha80, 12'ha70, 12'ha60, 12'ha50, 12'ha40, 12'ha30,
  12'ha20, 12'ha10, 12'ha00, 12'h9f0, 12'h9e0, 12'h9d0, 12'h9c0, 12'h9b0,
  12'h9a0, 12'h990, 12'h980, 12'h970, 12'h960, 12'h950, 12'h940, 12'h930,
  12'h920, 12'h910, 12'h900, 12'h8f0, 12'h8e0, 12'h8d0, 12'h8c0, 12'h8b0,
  12'h8a0, 12'h890, 12'h880, 12'h870, 12'h860, 12'h850, 12'h840, 12'h830,
  12'h820, 12'h810, 12'h800, 12'h7f0, 12'h7e0, 12'h7d0, 12'h7c0, 12'h7b0,
  12'h7a0, 12'h790, 12'h780, 12'h770, 12'h760, 12'h750, 12'h740, 12'h730,
  12'h720, 12'h710, 12'h700, 12'h6f0, 12'h6e0, 12'h6d0, 12'h6c0, 12'h6b0,
  12'h6a0, 12'h690, 12'h680, 12'h670, 12'h660, 12'h650, 12'h640, 12'h630,
  12'h620, 12'h610, 12'h600, 12'h5f0, 12'h5e0, 12'h5d0, 12'h5c0, 12'h5b0,
  12'h5a0, 12'h590, 12'h580, 12'h570, 12'h560, 12'h550, 12'h540, 12'h530,
  12'h520, 12'h510, 12'h500, 12'h4f0, 12'h4e0, 12'h4d0, 12'h4c0, 12'h4b0,
  12'h4a0, 12'h490, 12'h480, 12'h470, 12'h460, 12'h450, 12'h440, 12'h430,
  12'h420, 12'h410, 12'h400, 12'h3f0, 12'h3e0, 12'h3d0, 12'h3c0, 12'h3b0,
  12'h3a0, 12'h390, 12'h380, 12'h370, 12'h360, 12'h350, 12'h340, 12'h330,
  12'h320, 12'h310, 12'h300, 12'h2f0, 12'h2e0, 12'h2d0, 12'h2c0, 12'h2b0,
  12'h2a0, 12'h290, 12'h280, 12'h270, 12'h260, 12'h250, 12'h240, 12'h230,
  12'h220, 12'h210, 12'h200, 12'h1f0, 12'h1e0, 12'h1d0, 12'h1c0, 12'h1b0,
  12'h1a0, 12'h190, 12'h180, 12'h170, 12'h160, 12'h150, 12'h140, 12'h130,
  12'h120, 12'h110, 12'h100, 12'h0f0, 12'h0e0, 12'h0d0, 12'h0c0, 12'h0b0,
  12'h0a0, 12'h090, 12'h080, 12'h070, 12'h060, 12'h050, 12'h040, 12'h030,
  12'h020, 12'h010, 12'h000 };

  reg [11:0]      dbmx10_2490 [250:0] = { 
  12'hf90, 12'hf80, 12'hf70, 12'hf60, 12'hf50, 12'hf40, 12'hf30, 12'hf20,
  12'h800, 12'hf10, 12'hf00, 12'hef0, 12'hee0, 12'hed0, 12'hec0, 12'heb0,
  12'hea0, 12'he90, 12'he80, 12'he70, 12'he60, 12'he50, 12'he40, 12'he30,
  12'he20, 12'he10, 12'he00, 12'hdf0, 12'hde0, 12'hdd0, 12'hdc0, 12'hdb0,
  12'hda0, 12'hd90, 12'hd80, 12'hd70, 12'hd60, 12'hd50, 12'hd40, 12'hd30,
  12'hd20, 12'hd10, 12'hd00, 12'hcf0, 12'hce0, 12'hcd0, 12'hcc0, 12'hcb0,
  12'hca0, 12'hc90, 12'hc80, 12'hc70, 12'hc60, 12'hc50, 12'hc40, 12'hc30,
  12'hc20, 12'hc10, 12'hc00, 12'hbf0, 12'hbe0, 12'hbd0, 12'hbc0, 12'hbb0,
  12'hba0, 12'hb90, 12'hb80, 12'hb70, 12'hb60, 12'hb50, 12'hb40, 12'hb30,
  12'hb20, 12'hb10, 12'hb00, 12'haf0, 12'hae0, 12'had0, 12'hac0, 12'hab0,
  12'haa0, 12'ha90, 12'ha80, 12'ha70, 12'ha60, 12'ha50, 12'ha40, 12'ha30,
  12'ha20, 12'ha10, 12'ha00, 12'h9f0, 12'h9e0, 12'h9d0, 12'h9c0, 12'h9b0,
  12'h9a0, 12'h990, 12'h980, 12'h970, 12'h960, 12'h950, 12'h940, 12'h930,
  12'h920, 12'h910, 12'h900, 12'h8f0, 12'h8e0, 12'h8d0, 12'h8c0, 12'h8b0,
  12'h8a0, 12'h890, 12'h880, 12'h870, 12'h860, 12'h850, 12'h840, 12'h830,
  12'h820, 12'h810, 12'h800, 12'h7f0, 12'h7e0, 12'h7d0, 12'h7c0, 12'h7b0,
  12'h7a0, 12'h790, 12'h780, 12'h770, 12'h760, 12'h750, 12'h740, 12'h730,
  12'h720, 12'h710, 12'h700, 12'h6f0, 12'h6e0, 12'h6d0, 12'h6c0, 12'h6b0,
  12'h6a0, 12'h690, 12'h680, 12'h670, 12'h660, 12'h650, 12'h640, 12'h630,
  12'h620, 12'h610, 12'h600, 12'h5f0, 12'h5e0, 12'h5d0, 12'h5c0, 12'h5b0,
  12'h5a0, 12'h590, 12'h580, 12'h570, 12'h560, 12'h550, 12'h540, 12'h530,
  12'h520, 12'h510, 12'h500, 12'h4f0, 12'h4e0, 12'h4d0, 12'h4c0, 12'h4b0,
  12'h4a0, 12'h490, 12'h480, 12'h470, 12'h460, 12'h450, 12'h440, 12'h430,
  12'h420, 12'h410, 12'h400, 12'h3f0, 12'h3e0, 12'h3d0, 12'h3c0, 12'h3b0,
  12'h3a0, 12'h390, 12'h380, 12'h370, 12'h360, 12'h350, 12'h340, 12'h330,
  12'h320, 12'h310, 12'h300, 12'h2f0, 12'h2e0, 12'h2d0, 12'h2c0, 12'h2b0,
  12'h2a0, 12'h290, 12'h280, 12'h270, 12'h260, 12'h250, 12'h240, 12'h230,
  12'h220, 12'h210, 12'h200, 12'h1f0, 12'h1e0, 12'h1d0, 12'h1c0, 12'h1b0,
  12'h1a0, 12'h190, 12'h180, 12'h170, 12'h160, 12'h150, 12'h140, 12'h130,
  12'h120, 12'h110, 12'h100, 12'h0f0, 12'h0e0, 12'h0d0, 12'h0c0, 12'h0b0,
  12'h0a0, 12'h090, 12'h080, 12'h070, 12'h060, 12'h050, 12'h040, 12'h030,
  12'h020, 12'h010, 12'h000 };

  // Xilinx multiplier to perform 16 bit multiplication, output is 32 bits
  ftw_mult dbm_multiplier (
     .CLK(sys_clk),
     .A(power),
     .B(ten),
     .CE(multiply),
     .P(q7dot8x10)
  );      

  // Xilinx multiplier to perform 16 bit multiplication, output is 32 bits
  // this one for interpolation between power tables
  ftw_mult interp_mult (
     .CLK(sys_clk),
     .A(dbmA),
     .B(interp1),
     .CE(interp_mul),
     .P(prod1)
  );      


  ////////////////////////////////////////
  // VGA SPI instance, SPI to DAC7563   //
  // SPI mode 1                         //
  ////////////////////////////////////////
  reg         spi_run = 0;
  reg  [7:0]  spi_write;
  wire [7:0]  spi_read;
  wire        spi_busy;         // 'each byte' busy
  wire        spi_done_byte;    // 1=done with a byte, data is valid
  spi #(
    .CLK_DIV(3),
    .CPHA(1)
  ) 
  vga_spi 
  (
    .clk(sys_clk),
    .rst(!sys_rst_n),
    .miso(),
    .mosi(VGA_MOSI_o),
    .sck(VGA_SCLK_o),
    .start(spi_run),
    .data_in(spi_write),
    .data_out(spi_read),
    .busy(spi_busy),
    .new_data(spi_done_byte)     // 1=signal, data_out is valid
  );

  // Startup power level
  localparam INIT_DBMx10    = 12'd400;  // *10 dBm
 
  /////////////////////////////////
  // Set Power state definitions //
  /////////////////////////////////
  localparam PWR_IDLE           = 0;
  localparam PWR_SPCR           = 1;
  localparam PWR_READ           = 2;
  localparam PWR_DATA           = 3;
  localparam PWR_DBM            = 4;   // ((user dBm - Q7.8 requested dBm output)
  localparam PWR_DBM1           = 5;
  localparam PWR_DBM2           = 6;
  localparam PWR_DBM3           = 7;
  localparam PWR_DBM4           = 8;
  localparam PWR_VGA1           = 9;
  localparam PWR_VGA2           = 10;
  localparam PWR_VGA3           = 11;
  localparam PWR_VGA4           = 12;
  localparam PWR_VGA5           = 13;
  localparam PWR_WAIT           = 14;
  localparam WAIT_SPI           = 15;
  localparam PWR_SLOPE1         = 16;
  localparam PWR_SLOPE2         = 17;
  localparam PWR_SLOPE3         = 18;
  localparam PWR_INTCPT1        = 19;
  localparam PWR_INTCPT2        = 20;
  localparam PWR_DAC2           = 21;
  localparam PWR_INIT1          = 22;
  localparam PWR_INIT2          = 23;
  
  localparam    DAC_WORD0       = 32'h00380000;     // Disable internal refs, Gain=1
  localparam    DAC_WORD1       = 32'h00300003;     // LDAC pin inactive DAC A & B
  localparam    DACAB_FS        = 32'h0017FFF0;     // DAC AB input, write both. full scale is minimum power

  ////////////////////////////////////////
  // End of power state definitions //
  ////////////////////////////////////////

  assign VGA_VSW_o = 1'b1;          // We'll use high-gain mode

  // DAC7563 uses SPI mode 1. As long as SSEL(SYNC) is low for 24 bits
  // to be clocked in, the DAC will be updated on the 24th falling 
  // edge of SCLK
  always @( posedge sys_clk) begin
    if( !sys_rst_n ) begin
      state <= PWR_IDLE;
      next_state <= PWR_IDLE;
      pwr_fifo_ren_o <= 1'b0;
      power <= 32'h00000000;
      latency_counter <= 6'b000000; 
      VGA_SSn_o <= 1'b1;
      multiply <= 1'b0;      
      interp1 <= {16'd0, K};
      interp_mul <= 1'b0;
      ten <= {16'd0, TEN};
      modifier <= NORMAL_MODE;
      dbmx10_o <= INIT_DBMx10;  // present power setting for all top-level modules to access, dBm x10
      init_wordnum <= 3'd0;
      slope_is_neg <= 1'b0;
    end
    else if(power_en == 1) begin
      case(state)
        PWR_WAIT: begin
          if(latency_counter == 0)
            state <= next_state;
          else
            latency_counter <= latency_counter - 1;
        end
        PWR_IDLE: begin
          if(!pwr_fifo_mt_i) begin
            pwr_fifo_ren_o <= 1;
            state <= PWR_READ;
            status_o <= 1'b0;
            multiply <= 1'b0;
            modifier <= NORMAL_MODE;
          end
          else if(doInit_i) begin
            // doInit_i will go away asynchronously...    
            state <= PWR_INIT1;
            init_wordnum <= 3'd0;
            modifier <= INIT_DACS;
          end
          else
            status_o <= `SUCCESS;
        end
        PWR_INIT1: begin
          if(init_wordnum < 3'd3) begin
            pwr_opcode <= `CALPWR;
            case(init_wordnum)
            3'd0: begin
              power <= DAC_WORD0;
            end
            3'd1: begin
              power <= DAC_WORD1;
            end
            3'd2: begin
              power <= DACAB_FS;
            end
            endcase
            modifier <= INIT_DACS;
            init_wordnum <= init_wordnum + 1;
            state <= PWR_VGA1;        // Begin SPI write to VGA DAC
          end
          else begin
            state <= PWR_IDLE;
            init_wordnum <= 3'd0;
          end  
        end
        PWR_SPCR: begin
          state <= PWR_READ;
        end             
        PWR_READ: begin
          // read power from fifo
          pwr_word <= pwr_fifo_i;
          pwr_fifo_ren_o <= 1'b0;
          state <= PWR_DATA;
        end
        PWR_DATA: begin
          pwr_opcode <= pwr_word[38:32];
          if(pwr_fifo_i[38:32] == `POWER) begin
            power <= {16'd0, pwr_word[31:16]};
            state <= PWR_DBM;
          end
          else begin
            power <= pwr_word[31:0];
            state <= PWR_VGA1;   // write 1st byte of 3  
          end
        end
        // initialize processor starts here after setting data in 'power' register
        PWR_VGA1: begin
          VGA_SSn_o <= 1'b0;
          state <= PWR_VGA2;
        end
        PWR_VGA2: begin    // 32 bit word has 24 bits of DAC data in 3 LS bytes
          // write 1st byte
          spi_write <= power[23:16];
          spi_run <= 1'b1;
          next_state <= PWR_VGA3;
          state <= WAIT_SPI;
        end
        PWR_VGA3: begin
          // 2nd byte
          spi_write <= power[15:8];
          spi_run <= 1'b1;
          next_state <= PWR_VGA4;
          state <= WAIT_SPI;
        end
        PWR_VGA4: begin
          // 3rd byte
          spi_write <= power[7:0];
          spi_run <= 1'b1;
          next_state <= PWR_VGA5;
          state <= WAIT_SPI;
        end
        PWR_VGA5: begin
          VGA_SSn_o <= 1'b1;
          spi_run <= 1'b0;
          if(modifier == INIT_DACS) begin
            state <= PWR_INIT1;     // Write next dac init word, PWR_INIT1 processing resets to IDLE when done
          end
          else begin
            state <= PWR_IDLE;
            status_o <= `SUCCESS;
          end
        end
        WAIT_SPI: begin
          if(spi_done_byte == 1'b1) begin
            state <= next_state;
            spi_run <= 1'b0;
          end
        end
        PWR_DBM: begin
          // Initial user request, dbm * 256.0 
          multiply <= 1'b1;         // multiply dBm request by 10, 65dBm*256*10=166,400 = 0x28a00
          latency_counter <= MULTIPLIER_CLOCKS;
          next_state <= PWR_DBM1;                           
          state <= PWR_WAIT;
        end
        PWR_DBM1: begin
          // product is max  65dBm*256*10=166,400 => 0x28a00. Use 12 bits beginning at d8
          if(q7dot8x10[19:8] - DBM_OFFSET[19:8] < 0)
            dbm_idx <= 12'd0;
          else if(q7dot8x10[19:8] - DBM_OFFSET[19:8] > DBM_MAX_OFFSET)
            dbm_idx <= DBM_MAX_OFFSET;
          else
            dbm_idx <= q7dot8x10[19:8] - DBM_OFFSET[19:8]; // (/256.0) - 400, the array index for requested power
          dbmx10_o <= q7dot8x10[19:8];  // present power setting for all top-level modules to access, dBm x10
          state <= PWR_SLOPE1;
        end
        PWR_SLOPE1: begin
          // interpolate between power tables
          if(frequency_i < FRQ2) begin
          // slope = ((dbmx10_2410[dbm_idx] - dbmx10_2430[dbm_idx]))/(FRQ_DELTA);
          //   OR (Y2-Y1) * ((1/FRQ_DELTA)*256) / 256
            dbmA <= {24'd0, dbmx10_2410[dbm_idx] - dbmx10_2430[dbm_idx]};            
          end
          else if(frequency_i < FRQ3) begin
            dbmA <= {24'd0, dbmx10_2430[dbm_idx] - dbmx10_2450[dbm_idx]};    
          end
          else if(frequency_i < FRQ4) begin
            dbmA <= {24'd0, dbmx10_2450[dbm_idx] - dbmx10_2470[dbm_idx]};           
          end
          else begin
            dbmA <= {24'd0, dbmx10_2470[dbm_idx] - dbmx10_2490[dbm_idx]};           
          end
          interp1 <= {16'd0, K};
          state <= PWR_SLOPE2;
        end
        PWR_SLOPE2: begin
          interp_mul <= 1'b1;
          latency_counter <= MULTIPLIER_CLOCKS;
          next_state <= PWR_SLOPE3;
          state <= PWR_WAIT;
        end
        PWR_SLOPE3: begin
          // prod1 is now slope*256 (Q7.8)
          interp_mul <= 1'b0;
          slope <= prod1[23:8]; // save product / 256
          dbmA <= {16'd0, prod1[23:8]};  // slope into dbmA, product / 256
          // F2 into multiplicand
          if(frequency_i < FRQ2) begin
            interp1 <= FRQ2;
          end
          else if(frequency_i < FRQ3) begin
            interp1 <= FRQ3;            
          end
          else if(frequency_i < FRQ4) begin
            interp1 <= FRQ4;           
          end
          else begin
            interp1 <= FRQ5;           
          end
          state <= PWR_INTCPT1;        
        end
        PWR_INTCPT1: begin
          interp_mul <= 1'b1;
          latency_counter <= MULTIPLIER_CLOCKS;          
          next_state <= PWR_INTCPT2;
          state <= PWR_WAIT;
        end
        PWR_INTCPT2: begin
          // prod1 is slope*FRQ2
          interp_mul <= 1'b0;
          if(frequency_i < FRQ2) begin
            intercept <= {4'd0, dbmx10_2430[dbm_idx]} - prod1[15:0];
          end
          else if(frequency_i < FRQ3) begin
            intercept <= {4'd0, dbmx10_2450[dbm_idx]} - prod1[15:0];
          end
          else if(frequency_i < FRQ4) begin
            intercept <= {4'd0, dbmx10_2470[dbm_idx]} - prod1[15:0];
          end
          else begin
            intercept <= {4'd0, dbmx10_2490[dbm_idx]} - prod1[15:0];
          end
          
          // we have slope & intercept, calculate our dac value
          // dac <= slope*frequency + intercept;          
          // Load up for next multiply
          dbmA <= {16'd0, slope};
          interp1 <= frequency_i;
          
          state <= PWR_DBM2;
        end
        PWR_DBM2: begin
          interp_mul <= 1'b1;
          latency_counter <= MULTIPLIER_CLOCKS;          
          next_state <= PWR_DBM3;
          state <= PWR_WAIT;
        end
        PWR_DBM3: begin
          // Ready to send data to both DAC's. Just use this FSM to do it, 
          // except value is not in input fifo. Set next_state to PWR_VGA2
          // and let it run.
          power <= {8'd0, 8'h17, prod1[15:0]}; 
          state <= PWR_VGA2;        // write 1st byte of 3
          VGA_SSn_o <= 1'b0;
        end
        default: begin
          status_o = `ERR_UNKNOWN_PWR_STATE;
          state <= PWR_IDLE;
        end
        endcase
    end
  end

endmodule
