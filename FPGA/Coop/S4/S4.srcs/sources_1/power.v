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
`include "version.v"
`include "status.h"
`include "opcodes.h"

module power #(parameter FILL_BITS = 4)
(
  input  wire           sys_clk,
  input  wire           sys_rst_n,
    
  input  wire           power_en,

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

  input  wire [15:0]    frequency_i,              // current frequency
  
  output reg  [7:0]     status_o       // 0=busy, SUCCESS when done, or an error code
);

  localparam DBM_OFFSET = 24'd102400;  // 40.0 dBm * 256 * 10
  localparam DBM_MAX_OFFSET = 24'd250; // 251 entries per table at 0.1dBm intervals
  localparam TEN = 16'd10;             // Multiply user power request by 10
  localparam FRQ1 = 16'd2410;          // frequency breakpoint 1
  localparam FRQ2 = 16'd2430;          // frequency breakpoint 1
  localparam FRQ3 = 16'd2450;          // frequency breakpoint 1
  localparam FRQ4 = 16'd2470;          // frequency breakpoint 1
  localparam FRQ5 = 16'd2490;          // frequency breakpoint 1
  localparam FRQ_DELTA = 16'd20;       // 20MHz between tables
  localparam INTERP1 = 16'd13;         // 1/20MHz * 256 = 12.8

  // Main Globals
  reg  [6:0]      state = 0;
  reg  [6:0]      next_state;          // saved while waiting for SPI writes

  reg  [31:0]     power = 0;          // 12 bits of dBm x10 (400 to 650) or Cal data
  reg  [38:0]     pwr_word;           // whole 39 bit word (32 bits cal data, 7 bits opcode)
  reg  [6:0]      pwr_opcode;         // which power opcode, user request or cal?
  wire [63:0]     q7dot8x10;          // Q7.8 user dBm request, 40.0 to 65.0 times 256.0, times 10
  //reg  [11:0]     dbmx10;             // user dBm request, dBm x 10, 400 to 650
  reg  [11:0]     dbm_idx;            // index into power table of user requested power, only using ~8 lsbs
  reg  [31:0]     ten;                // for dbm * 10
  reg             internal;           // flag, internal set power cmd
  
  // interpolation multiplier vars
  reg  [31:0]     dbmA;
  reg  [31:0]     interp1;
  wire [63:0]     prod1;
  reg             interp_mul;   // enable interpolation multiplier
  
  // interpolation vars
  reg  [15:0]     slope;
  reg  [15:0]     intercept;

  // enable dbm x10 multiplier
  reg             multiply;
  // Latency for math operations, Xilinx multiplier & divrem divider have no reliable "done" line???
  localparam MULTIPLIER_CLOCKS = 6;
  //localparam DIVIDER_CLOCKS = 42;
  reg [5:0]       latency_counter;    // wait for multiplier

  // power table of dac values required for dBm output.
  // 5 tables, 2410MHz, 2430MHz, 2450MHz, 2470MHz, 2490MHz
  // Entries in 0.1 dBm steps beginning at 40.0dBm
  // 251 total entries covering 400 to 650 (40.0 to 65.0 dBm)
  reg [11:0]      dbmx10_2410 [250:0] = { 
  12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800,
  12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800,
  12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800,
  12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800,
  12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800,
  12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800,
  12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800,
  12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800,
  12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800,
  12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800,
  12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800,
  12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800,
  12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800,
  12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800,
  12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800,
  12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800,
  12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800,
  12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800,
  12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800,
  12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800,
  12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800,
  12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800,
  12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800,
  12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800,
  12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800,
  12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800,
  12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800,
  12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800,
  12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800,
  12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800,
  12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800,
  12'h800, 12'h800, 12'h800 };

  reg [11:0]      dbmx10_2430 [250:0] = { 
  12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800,
  12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800,
  12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800,
  12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800,
  12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800,
  12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800,
  12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800,
  12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800,
  12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800,
  12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800,
  12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800,
  12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800,
  12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800,
  12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800,
  12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800,
  12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800,
  12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800,
  12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800,
  12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800,
  12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800,
  12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800,
  12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800,
  12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800,
  12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800,
  12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800,
  12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800,
  12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800,
  12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800,
  12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800,
  12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800,
  12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800,
  12'h800, 12'h800, 12'h800 };

  reg [11:0]      dbmx10_2450 [250:0] = { 
  12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800,
  12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800,
  12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800,
  12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800,
  12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800,
  12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800,
  12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800,
  12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800,
  12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800,
  12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800,
  12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800,
  12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800,
  12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800,
  12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800,
  12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800,
  12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800,
  12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800,
  12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800,
  12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800,
  12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800,
  12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800,
  12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800,
  12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800,
  12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800,
  12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800,
  12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800,
  12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800,
  12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800,
  12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800,
  12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800,
  12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800,
  12'h800, 12'h800, 12'h800 };

  reg [11:0]      dbmx10_2470 [250:0] = { 
  12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800,
  12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800,
  12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800,
  12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800,
  12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800,
  12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800,
  12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800,
  12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800,
  12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800,
  12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800,
  12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800,
  12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800,
  12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800,
  12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800,
  12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800,
  12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800,
  12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800,
  12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800,
  12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800,
  12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800,
  12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800,
  12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800,
  12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800,
  12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800,
  12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800,
  12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800,
  12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800,
  12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800,
  12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800,
  12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800,
  12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800,
  12'h800, 12'h800, 12'h800 };

  reg [11:0]      dbmx10_2490 [250:0] = { 
  12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800,
  12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800,
  12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800,
  12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800,
  12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800,
  12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800,
  12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800,
  12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800,
  12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800,
  12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800,
  12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800,
  12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800,
  12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800,
  12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800,
  12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800,
  12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800,
  12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800,
  12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800,
  12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800,
  12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800,
  12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800,
  12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800,
  12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800,
  12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800,
  12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800,
  12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800,
  12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800,
  12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800,
  12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800,
  12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800,
  12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800, 12'h800,
  12'h800, 12'h800, 12'h800 };

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
  
  ////////////////////////////////////////
  // End of power state definitions //
  ////////////////////////////////////////

// DAC7563 programming from M2
//static uint8_t InitializeDac() {

//	//	hidio 66 1 3 38 00 00
//	uint8_t dac_data[] = { 0x38, 0, 0 }; // Disable internal refs, Gain=1
//	uint8_t status = spiwrrd(SPI_DEV_ID_DAC, sizeof(dac_data), dac_data);

//	//	hidio 66 1 3 30 00 03
//	dac_data[0] = 0x30;	// LDAC pin inactive DAC A & B
//	dac_data[1] = 0;
//	dac_data[2] = 3;
//	status |= spiwrrd(SPI_DEV_ID_DAC, sizeof(dac_data), dac_data);

//	//	hidio 66 1 3 00 99 60
//	dac_data[0] = 0;		// DAC A input
//	dac_data[1] = 0x99;		// 0x996
//	dac_data[2] = 0x60;
//	status |= spiwrrd(SPI_DEV_ID_DAC, sizeof(dac_data), dac_data);

//	//	hidio 66 1 3 11 80 00
//	dac_data[0] = 0x11;		// Write DAC B input & update all DAC's
//	dac_data[1] = 0x80;		// 0x800
//	dac_data[2] = 0;
//	status |= spiwrrd(SPI_DEV_ID_DAC, sizeof(dac_data), dac_data);

//	return status;
//}


//// *** Set Power from M2:
//// Convert dB into dac value & send it
//// dB is relative to dac 0x80(128)
//static uint8_t SetSynthesizer(uint16_t db, uint16_t *pvmag) {
//	float value = (float)db/2000.0;
//	value = pow(10.0, value);
//	value = value * 128.0 + 0.5;
//	uint16_t vmag = (uint16_t)value + 0x800; //((pow(10.0, (db/20.0)) * (double)0x800) + 0.5);
//	*pvmag = vmag;
//	int16_t phase = 0x800; //GetPhase();
//#ifdef DEBUG
//	iprintf("dB:%04d, IDac:0x%03x, QDac:0x%03x\n", db, vmag, phase);
//#endif

//	// I(magnitude) is DAC A, Q(phase) is DAC B
//	uint8_t dac_data[3];
//	dac_data[0] = 0;		// DAC A input
//	dac_data[1] = (vmag>>4) & 0xff;
//	dac_data[2] = (vmag&0xf)<<4;
//	uint8_t status = spiwrrd(SPI_DEV_ID_DAC, sizeof(dac_data), dac_data);

//	dac_data[0] = 0x11;		// Write DAC B input & update all DAC's
//	dac_data[1] = (phase>>4) & 0xff;
//	dac_data[2] = (phase&0xf)<<4;
//	status |= spiwrrd(SPI_DEV_ID_DAC, sizeof(dac_data), dac_data);

//	return status;
//}

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
      interp1 <= {16'd0, INTERP1};
      interp_mul <= 1'b0;
      ten <= {16'd0, TEN};
      internal <= 1'b0;
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
            internal <= 1'b0;
          end
          else
            status_o <= `SUCCESS;
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
        PWR_VGA1: begin          // On internal writes, assert SSELn for 2nd write (both VGA dacs)
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
          if(internal == 1'b1) begin
            // host set power, we're writing 2 dacs
            power[23:16] <= 8'h11;  // change to write dac B input & update both dacs
            state <= PWR_VGA1;      // Write dac data again
            internal <= 1'b0;
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
          interp1 <= {16'd0, INTERP1};
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
          next_state <= PWR_DBM3;
          state <= PWR_WAIT;
        end
        PWR_DBM3: begin
          // Ready to send data to both DAC's. Just use this FSM to do it, 
          // except value is not in input fifo. Must use special internal
          // mode. Set next_state to PWR_DAC2 as a flag
          power <= {16'd0, prod1[15:0]}; 
          state <= PWR_VGA2;        // write 1st byte of 3
          internal <= 1'b1;         // Flag, user set power requires writes to both dacs
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
