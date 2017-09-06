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
  // **entries are opposite from C, highest index first**
  reg [11:0]      dbmx10_2410 [250:0] = { 
  12'h000, 12'h000, 12'h000, 12'h000, 12'h000, 12'h000, 12'h000, 12'h000,
  12'h000, 12'h000, 12'h000, 12'h000, 12'h000, 12'h000, 12'h000, 12'h000,
  12'h000, 12'h000, 12'h000, 12'h000, 12'h000, 12'h000, 12'h000, 12'h000,
  12'h000, 12'h000, 12'h000, 12'h000, 12'h000, 12'h000, 12'h000, 12'h000,  // 61.9dBm rhs
  12'h000, 12'h000, 12'h000, 12'h000, 12'h000, 12'h000, 12'h000, 12'h000,
  12'h000, 12'h000, 12'h000, 12'h000, 12'h000, 12'h000, 12'h000, 12'h000,
  12'h000, 12'h000, 12'h000, 12'h013, 12'h026, 12'h039, 12'h04c, 12'h05f,  // 60.0dBm third from left
  12'h072, 12'h085, 12'h098, 12'h0ab, 12'h0be, 12'h0d1, 12'h0e4, 12'h0f7,
  12'h10a, 12'h11d, 12'h130, 12'h143, 12'h156, 12'h169, 12'h17c, 12'h18f,
  12'h1a2, 12'h1b5, 12'h1c8, 12'h1db, 12'h1ee, 12'h201, 12'h214, 12'h227,
  12'h23a, 12'h24d, 12'h260, 12'h273, 12'h286, 12'h299, 12'h2ac, 12'h2bf,
  12'h2d2, 12'h2e5, 12'h2f8, 12'h30b, 12'h31e, 12'h331, 12'h344, 12'h357,
  12'h36a, 12'h37d, 12'h390, 12'h3a3, 12'h3b6, 12'h3c9, 12'h3dc, 12'h3ef,
  12'h402, 12'h415, 12'h428, 12'h43b, 12'h44e, 12'h461, 12'h474, 12'h487,
  12'h49a, 12'h4ad, 12'h4c0, 12'h4d3, 12'h4e6, 12'h4f9, 12'h50c, 12'h51f,
  12'h532, 12'h545, 12'h558, 12'h56b, 12'h57e, 12'h591, 12'h5a4, 12'h5b7,
  12'h5ca, 12'h5dd, 12'h5f0, 12'h603, 12'h616, 12'h629, 12'h63c, 12'h64f,
  12'h662, 12'h675, 12'h688, 12'h69b, 12'h6ae, 12'h6c1, 12'h6d4, 12'h6e7,
  12'h6fa, 12'h70d, 12'h720, 12'h733, 12'h746, 12'h759, 12'h76c, 12'h77f,
  12'h792, 12'h7a5, 12'h7b8, 12'h7cb, 12'h7de, 12'h7f1, 12'h804, 12'h817,
  12'h82a, 12'h83d, 12'h850, 12'h863, 12'h876, 12'h889, 12'h89c, 12'h8af,
  12'h8c2, 12'h8d5, 12'h8e8, 12'h8fb, 12'h90e, 12'h921, 12'h934, 12'h947,
  12'h95a, 12'h96d, 12'h980, 12'h993, 12'h9a6, 12'h9b9, 12'h9cc, 12'h9df,
  12'h9f2, 12'ha05, 12'ha18, 12'ha2b, 12'ha3e, 12'ha51, 12'ha64, 12'ha77,
  12'ha8a, 12'ha9d, 12'hab0, 12'hac3, 12'had6, 12'hae9, 12'hafc, 12'hb0f,
  12'hb22, 12'hb35, 12'hb48, 12'h5b5, 12'hb6e, 12'hb81, 12'hb94, 12'hba7,
  12'hbba, 12'hbcd, 12'hbe0, 12'hbf3, 12'hc06, 12'hc19, 12'hc2c, 12'hc3f,
  12'hc52, 12'hc65, 12'hc78, 12'hc8b, 12'hc9e, 12'hcb1, 12'hcc4, 12'hcd7,
  12'hcea, 12'hcfd, 12'hd10, 12'hd23, 12'h160, 12'hd36, 12'hd49, 12'hd5c,
  12'hd6f, 12'hd82, 12'hd95, 12'hda8, 12'hdbb, 12'hdce, 12'hde1, 12'hdf4,
  12'he07, 12'he1a, 12'he2d, 12'he40, 12'he53, 12'he66, 12'he79, 12'he8c,
  12'he9f, 12'heb2, 12'hfff };

  reg [11:0]      dbmx10_2430 [250:0] = { 
  12'h000, 12'h000, 12'h000, 12'h000, 12'h000, 12'h000, 12'h000, 12'h000,
  12'h000, 12'h000, 12'h000, 12'h000, 12'h000, 12'h000, 12'h000, 12'h000,
  12'h000, 12'h000, 12'h000, 12'h000, 12'h000, 12'h000, 12'h000, 12'h000,
  12'h000, 12'h000, 12'h000, 12'h000, 12'h000, 12'h000, 12'h000, 12'h000,  // 61.9dBm rhs
  12'h000, 12'h000, 12'h000, 12'h000, 12'h000, 12'h000, 12'h000, 12'h000,
  12'h000, 12'h000, 12'h000, 12'h000, 12'h000, 12'h000, 12'h000, 12'h000,
  12'h000, 12'h000, 12'h000, 12'h013, 12'h026, 12'h039, 12'h04c, 12'h05f,  // 60.0dBm third from left
  12'h072, 12'h085, 12'h098, 12'h0ab, 12'h0be, 12'h0d1, 12'h0e4, 12'h0f7,
  12'h10a, 12'h11d, 12'h130, 12'h143, 12'h156, 12'h169, 12'h17c, 12'h18f,
  12'h1a2, 12'h1b5, 12'h1c8, 12'h1db, 12'h1ee, 12'h201, 12'h214, 12'h227,
  12'h23a, 12'h24d, 12'h260, 12'h273, 12'h286, 12'h299, 12'h2ac, 12'h2bf,
  12'h2d2, 12'h2e5, 12'h2f8, 12'h30b, 12'h31e, 12'h331, 12'h344, 12'h357,
  12'h36a, 12'h37d, 12'h390, 12'h3a3, 12'h3b6, 12'h3c9, 12'h3dc, 12'h3ef,
  12'h402, 12'h415, 12'h428, 12'h43b, 12'h44e, 12'h461, 12'h474, 12'h487,
  12'h49a, 12'h4ad, 12'h4c0, 12'h4d3, 12'h4e6, 12'h4f9, 12'h50c, 12'h51f,
  12'h532, 12'h545, 12'h558, 12'h56b, 12'h57e, 12'h591, 12'h5a4, 12'h5b7,
  12'h5ca, 12'h5dd, 12'h5f0, 12'h603, 12'h616, 12'h629, 12'h63c, 12'h64f,
  12'h662, 12'h675, 12'h688, 12'h69b, 12'h6ae, 12'h6c1, 12'h6d4, 12'h6e7,
  12'h6fa, 12'h70d, 12'h720, 12'h733, 12'h746, 12'h759, 12'h76c, 12'h77f,
  12'h792, 12'h7a5, 12'h7b8, 12'h7cb, 12'h7de, 12'h7f1, 12'h804, 12'h817,
  12'h82a, 12'h83d, 12'h850, 12'h863, 12'h876, 12'h889, 12'h89c, 12'h8af,
  12'h8c2, 12'h8d5, 12'h8e8, 12'h8fb, 12'h90e, 12'h921, 12'h934, 12'h947,
  12'h95a, 12'h96d, 12'h980, 12'h993, 12'h9a6, 12'h9b9, 12'h9cc, 12'h9df,
  12'h9f2, 12'ha05, 12'ha18, 12'ha2b, 12'ha3e, 12'ha51, 12'ha64, 12'ha77,
  12'ha8a, 12'ha9d, 12'hab0, 12'hac3, 12'had6, 12'hae9, 12'hafc, 12'hb0f,
  12'hb22, 12'hb35, 12'hb48, 12'h5b5, 12'hb6e, 12'hb81, 12'hb94, 12'hba7,
  12'hbba, 12'hbcd, 12'hbe0, 12'hbf3, 12'hc06, 12'hc19, 12'hc2c, 12'hc3f,
  12'hc52, 12'hc65, 12'hc78, 12'hc8b, 12'hc9e, 12'hcb1, 12'hcc4, 12'hcd7,
  12'hcea, 12'hcfd, 12'hd10, 12'hd23, 12'h160, 12'hd36, 12'hd49, 12'hd5c,
  12'hd6f, 12'hd82, 12'hd95, 12'hda8, 12'hdbb, 12'hdce, 12'hde1, 12'hdf4,
  12'he07, 12'he1a, 12'he2d, 12'he40, 12'he53, 12'he66, 12'he79, 12'he8c,
  12'he9f, 12'heb2, 12'hfff };

  reg [11:0]      dbmx10_2450 [250:0] = { 
  12'h000, 12'h000, 12'h000, 12'h000, 12'h000, 12'h000, 12'h000, 12'h000,
  12'h000, 12'h000, 12'h000, 12'h000, 12'h000, 12'h000, 12'h000, 12'h000,
  12'h000, 12'h000, 12'h000, 12'h000, 12'h000, 12'h000, 12'h000, 12'h000,
  12'h000, 12'h000, 12'h000, 12'h000, 12'h000, 12'h000, 12'h000, 12'h000,  // 61.9dBm rhs
  12'h000, 12'h000, 12'h000, 12'h000, 12'h000, 12'h000, 12'h000, 12'h000,
  12'h000, 12'h000, 12'h000, 12'h000, 12'h000, 12'h000, 12'h000, 12'h000,
  12'h000, 12'h000, 12'h000, 12'h013, 12'h026, 12'h039, 12'h04c, 12'h05f,  // 60.0dBm third from left
  12'h072, 12'h085, 12'h098, 12'h0ab, 12'h0be, 12'h0d1, 12'h0e4, 12'h0f7,
  12'h10a, 12'h11d, 12'h130, 12'h143, 12'h156, 12'h169, 12'h17c, 12'h18f,
  12'h1a2, 12'h1b5, 12'h1c8, 12'h1db, 12'h1ee, 12'h201, 12'h214, 12'h227,
  12'h23a, 12'h24d, 12'h260, 12'h273, 12'h286, 12'h299, 12'h2ac, 12'h2bf,
  12'h2d2, 12'h2e5, 12'h2f8, 12'h30b, 12'h31e, 12'h331, 12'h344, 12'h357,
  12'h36a, 12'h37d, 12'h390, 12'h3a3, 12'h3b6, 12'h3c9, 12'h3dc, 12'h3ef,
  12'h402, 12'h415, 12'h428, 12'h43b, 12'h44e, 12'h461, 12'h474, 12'h487,
  12'h49a, 12'h4ad, 12'h4c0, 12'h4d3, 12'h4e6, 12'h4f9, 12'h50c, 12'h51f,
  12'h532, 12'h545, 12'h558, 12'h56b, 12'h57e, 12'h591, 12'h5a4, 12'h5b7,
  12'h5ca, 12'h5dd, 12'h5f0, 12'h603, 12'h616, 12'h629, 12'h63c, 12'h64f,
  12'h662, 12'h675, 12'h688, 12'h69b, 12'h6ae, 12'h6c1, 12'h6d4, 12'h6e7,
  12'h6fa, 12'h70d, 12'h720, 12'h733, 12'h746, 12'h759, 12'h76c, 12'h77f,
  12'h792, 12'h7a5, 12'h7b8, 12'h7cb, 12'h7de, 12'h7f1, 12'h804, 12'h817,
  12'h82a, 12'h83d, 12'h850, 12'h863, 12'h876, 12'h889, 12'h89c, 12'h8af,
  12'h8c2, 12'h8d5, 12'h8e8, 12'h8fb, 12'h90e, 12'h921, 12'h934, 12'h947,
  12'h95a, 12'h96d, 12'h980, 12'h993, 12'h9a6, 12'h9b9, 12'h9cc, 12'h9df,
  12'h9f2, 12'ha05, 12'ha18, 12'ha2b, 12'ha3e, 12'ha51, 12'ha64, 12'ha77,
  12'ha8a, 12'ha9d, 12'hab0, 12'hac3, 12'had6, 12'hae9, 12'hafc, 12'hb0f,
  12'hb22, 12'hb35, 12'hb48, 12'h5b5, 12'hb6e, 12'hb81, 12'hb94, 12'hba7,
  12'hbba, 12'hbcd, 12'hbe0, 12'hbf3, 12'hc06, 12'hc19, 12'hc2c, 12'hc3f,
  12'hc52, 12'hc65, 12'hc78, 12'hc8b, 12'hc9e, 12'hcb1, 12'hcc4, 12'hcd7,
  12'hcea, 12'hcfd, 12'hd10, 12'hd23, 12'h160, 12'hd36, 12'hd49, 12'hd5c,
  12'hd6f, 12'hd82, 12'hd95, 12'hda8, 12'hdbb, 12'hdce, 12'hde1, 12'hdf4,
  12'he07, 12'he1a, 12'he2d, 12'he40, 12'he53, 12'he66, 12'he79, 12'he8c,
  12'he9f, 12'heb2, 12'hfff };

  reg [11:0]      dbmx10_2470 [250:0] = { 
  12'h000, 12'h000, 12'h000, 12'h000, 12'h000, 12'h000, 12'h000, 12'h000,
  12'h000, 12'h000, 12'h000, 12'h000, 12'h000, 12'h000, 12'h000, 12'h000,
  12'h000, 12'h000, 12'h000, 12'h000, 12'h000, 12'h000, 12'h000, 12'h000,
  12'h000, 12'h000, 12'h000, 12'h000, 12'h000, 12'h000, 12'h000, 12'h000,  // 61.9dBm rhs
  12'h000, 12'h000, 12'h000, 12'h000, 12'h000, 12'h000, 12'h000, 12'h000,
  12'h000, 12'h000, 12'h000, 12'h000, 12'h000, 12'h000, 12'h000, 12'h000,
  12'h000, 12'h000, 12'h000, 12'h013, 12'h026, 12'h039, 12'h04c, 12'h05f,  // 60.0dBm third from left
  12'h072, 12'h085, 12'h098, 12'h0ab, 12'h0be, 12'h0d1, 12'h0e4, 12'h0f7,
  12'h10a, 12'h11d, 12'h130, 12'h143, 12'h156, 12'h169, 12'h17c, 12'h18f,
  12'h1a2, 12'h1b5, 12'h1c8, 12'h1db, 12'h1ee, 12'h201, 12'h214, 12'h227,
  12'h23a, 12'h24d, 12'h260, 12'h273, 12'h286, 12'h299, 12'h2ac, 12'h2bf,
  12'h2d2, 12'h2e5, 12'h2f8, 12'h30b, 12'h31e, 12'h331, 12'h344, 12'h357,
  12'h36a, 12'h37d, 12'h390, 12'h3a3, 12'h3b6, 12'h3c9, 12'h3dc, 12'h3ef,
  12'h402, 12'h415, 12'h428, 12'h43b, 12'h44e, 12'h461, 12'h474, 12'h487,
  12'h49a, 12'h4ad, 12'h4c0, 12'h4d3, 12'h4e6, 12'h4f9, 12'h50c, 12'h51f,
  12'h532, 12'h545, 12'h558, 12'h56b, 12'h57e, 12'h591, 12'h5a4, 12'h5b7,
  12'h5ca, 12'h5dd, 12'h5f0, 12'h603, 12'h616, 12'h629, 12'h63c, 12'h64f,
  12'h662, 12'h675, 12'h688, 12'h69b, 12'h6ae, 12'h6c1, 12'h6d4, 12'h6e7,
  12'h6fa, 12'h70d, 12'h720, 12'h733, 12'h746, 12'h759, 12'h76c, 12'h77f,
  12'h792, 12'h7a5, 12'h7b8, 12'h7cb, 12'h7de, 12'h7f1, 12'h804, 12'h817,
  12'h82a, 12'h83d, 12'h850, 12'h863, 12'h876, 12'h889, 12'h89c, 12'h8af,
  12'h8c2, 12'h8d5, 12'h8e8, 12'h8fb, 12'h90e, 12'h921, 12'h934, 12'h947,
  12'h95a, 12'h96d, 12'h980, 12'h993, 12'h9a6, 12'h9b9, 12'h9cc, 12'h9df,
  12'h9f2, 12'ha05, 12'ha18, 12'ha2b, 12'ha3e, 12'ha51, 12'ha64, 12'ha77,
  12'ha8a, 12'ha9d, 12'hab0, 12'hac3, 12'had6, 12'hae9, 12'hafc, 12'hb0f,
  12'hb22, 12'hb35, 12'hb48, 12'h5b5, 12'hb6e, 12'hb81, 12'hb94, 12'hba7,
  12'hbba, 12'hbcd, 12'hbe0, 12'hbf3, 12'hc06, 12'hc19, 12'hc2c, 12'hc3f,
  12'hc52, 12'hc65, 12'hc78, 12'hc8b, 12'hc9e, 12'hcb1, 12'hcc4, 12'hcd7,
  12'hcea, 12'hcfd, 12'hd10, 12'hd23, 12'h160, 12'hd36, 12'hd49, 12'hd5c,
  12'hd6f, 12'hd82, 12'hd95, 12'hda8, 12'hdbb, 12'hdce, 12'hde1, 12'hdf4,
  12'he07, 12'he1a, 12'he2d, 12'he40, 12'he53, 12'he66, 12'he79, 12'he8c,
  12'he9f, 12'heb2, 12'hfff };

  reg [11:0]      dbmx10_2490 [250:0] = { 
  12'h000, 12'h000, 12'h000, 12'h000, 12'h000, 12'h000, 12'h000, 12'h000,
  12'h000, 12'h000, 12'h000, 12'h000, 12'h000, 12'h000, 12'h000, 12'h000,
  12'h000, 12'h000, 12'h000, 12'h000, 12'h000, 12'h000, 12'h000, 12'h000,
  12'h000, 12'h000, 12'h000, 12'h000, 12'h000, 12'h000, 12'h000, 12'h000,  // 61.9dBm rhs
  12'h000, 12'h000, 12'h000, 12'h000, 12'h000, 12'h000, 12'h000, 12'h000,
  12'h000, 12'h000, 12'h000, 12'h000, 12'h000, 12'h000, 12'h000, 12'h000,
  12'h000, 12'h000, 12'h000, 12'h013, 12'h026, 12'h039, 12'h04c, 12'h05f,  // 60.0dBm third from left
  12'h072, 12'h085, 12'h098, 12'h0ab, 12'h0be, 12'h0d1, 12'h0e4, 12'h0f7,
  12'h10a, 12'h11d, 12'h130, 12'h143, 12'h156, 12'h169, 12'h17c, 12'h18f,
  12'h1a2, 12'h1b5, 12'h1c8, 12'h1db, 12'h1ee, 12'h201, 12'h214, 12'h227,
  12'h23a, 12'h24d, 12'h260, 12'h273, 12'h286, 12'h299, 12'h2ac, 12'h2bf,
  12'h2d2, 12'h2e5, 12'h2f8, 12'h30b, 12'h31e, 12'h331, 12'h344, 12'h357,
  12'h36a, 12'h37d, 12'h390, 12'h3a3, 12'h3b6, 12'h3c9, 12'h3dc, 12'h3ef,
  12'h402, 12'h415, 12'h428, 12'h43b, 12'h44e, 12'h461, 12'h474, 12'h487,
  12'h49a, 12'h4ad, 12'h4c0, 12'h4d3, 12'h4e6, 12'h4f9, 12'h50c, 12'h51f,
  12'h532, 12'h545, 12'h558, 12'h56b, 12'h57e, 12'h591, 12'h5a4, 12'h5b7,
  12'h5ca, 12'h5dd, 12'h5f0, 12'h603, 12'h616, 12'h629, 12'h63c, 12'h64f,
  12'h662, 12'h675, 12'h688, 12'h69b, 12'h6ae, 12'h6c1, 12'h6d4, 12'h6e7,
  12'h6fa, 12'h70d, 12'h720, 12'h733, 12'h746, 12'h759, 12'h76c, 12'h77f,
  12'h792, 12'h7a5, 12'h7b8, 12'h7cb, 12'h7de, 12'h7f1, 12'h804, 12'h817,
  12'h82a, 12'h83d, 12'h850, 12'h863, 12'h876, 12'h889, 12'h89c, 12'h8af,
  12'h8c2, 12'h8d5, 12'h8e8, 12'h8fb, 12'h90e, 12'h921, 12'h934, 12'h947,
  12'h95a, 12'h96d, 12'h980, 12'h993, 12'h9a6, 12'h9b9, 12'h9cc, 12'h9df,
  12'h9f2, 12'ha05, 12'ha18, 12'ha2b, 12'ha3e, 12'ha51, 12'ha64, 12'ha77,
  12'ha8a, 12'ha9d, 12'hab0, 12'hac3, 12'had6, 12'hae9, 12'hafc, 12'hb0f,
  12'hb22, 12'hb35, 12'hb48, 12'h5b5, 12'hb6e, 12'hb81, 12'hb94, 12'hba7,
  12'hbba, 12'hbcd, 12'hbe0, 12'hbf3, 12'hc06, 12'hc19, 12'hc2c, 12'hc3f,
  12'hc52, 12'hc65, 12'hc78, 12'hc8b, 12'hc9e, 12'hcb1, 12'hcc4, 12'hcd7,
  12'hcea, 12'hcfd, 12'hd10, 12'hd23, 12'h160, 12'hd36, 12'hd49, 12'hd5c,
  12'hd6f, 12'hd82, 12'hd95, 12'hda8, 12'hdbb, 12'hdce, 12'hde1, 12'hdf4,
  12'he07, 12'he1a, 12'he2d, 12'he40, 12'he53, 12'he66, 12'he79, 12'he8c,
  12'he9f, 12'heb2, 12'hfff };

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
  localparam PWR_INTCPT3        = 21;
  localparam PWR_INTCPT4        = 22;
  localparam PWR_INIT1          = 23;
  localparam PWR_INIT2          = 24;
  
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
          multiply <= 1'b0;
          if(q7dot8x10[19:8] - DBM_OFFSET[19:8] < 0)
            dbm_idx <= 12'd0;
          else if(q7dot8x10[19:8] - DBM_OFFSET[19:8] > DBM_MAX_OFFSET)
            dbm_idx <= DBM_MAX_OFFSET;
          else
            dbm_idx <= q7dot8x10[19:8] - DBM_OFFSET[19:8]; // (/256.0) - 400, the array index for requested power
          dbmx10_o <= q7dot8x10[19:8];  // present power setting for all top-level modules to access, dBm x10
          slope_is_neg <= 1'b0;         // clear a flag
          state <= PWR_SLOPE1;
        end
        PWR_SLOPE1: begin
          // interpolate between power tables
          if(frequency_i <= FRQ2) begin
          // slope = ((dbmx10_2410[dbm_idx] - dbmx10_2430[dbm_idx]))/(FRQ_DELTA);
          // Using (slope * 2**32) ==> (1/FRQ_DELTA) * 2**32 = 214.74836 ~= 215
          // slope * 2**32 ~= 215 * (dbmx10_2410[dbm_idx] - dbmx10_2430[dbm_idx]);
          //
          // Then intercept = dbmx10_2430[dbm_idx] - ((slope*2**32)*frq2)/2**32;
          //
          // Assuming max delta between freq tables of 2048, 215*2048 = 440,320.
          // This requires 19 bits, use a 32 bit register.
            dbmA <= {20'd0, dbmx10_2410[dbm_idx] - dbmx10_2430[dbm_idx]};            
            if(dbmx10_2410[dbm_idx] < dbmx10_2430[dbm_idx])
              slope_is_neg <= 1'b1;
          end
          else if(frequency_i <= FRQ3) begin
            dbmA <= {20'd0, dbmx10_2430[dbm_idx] - dbmx10_2450[dbm_idx]};    
            if(dbmx10_2430[dbm_idx] < dbmx10_2450[dbm_idx])
              slope_is_neg <= 1'b1;
          end
          else if(frequency_i <= FRQ4) begin
            dbmA <= {20'd0, dbmx10_2450[dbm_idx] - dbmx10_2470[dbm_idx]};           
            if(dbmx10_2450[dbm_idx] < dbmx10_2470[dbm_idx])
              slope_is_neg <= 1'b1;
          end
          else begin
            dbmA <= {20'd0, dbmx10_2470[dbm_idx] - dbmx10_2490[dbm_idx]};           
            if(dbmx10_2470[dbm_idx] < dbmx10_2490[dbm_idx])
              slope_is_neg <= 1'b1;
          end
          // Dummy in a non-0 value for testing
    //dbmA <= {32'd80};                    
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
          interp_mul <= 1'b0;
          slope <= prod1[31:0];     // save product, prod1 = (slope * 2**32)    
          dbmA <= prod1[31:0];      // slope*2**32 into dbmA
          // F2 into multiplicand
          if(frequency_i <= FRQ2) begin
            interp1 <= FRQ2;
          end
          else if(frequency_i <= FRQ3) begin
            interp1 <= FRQ3;            
          end
          else if(frequency_i <= FRQ4) begin
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
          // prod1 is slope*FRQ2*2**32, intercept is upper 32 bits of prod1
          // setup to use it in next state
          interp_mul <= 1'b0;
          if(frequency_i <= FRQ2) begin
            intercept <= {4'd0, dbmx10_2430[dbm_idx]};
          end
          else if(frequency_i <= FRQ3) begin
            intercept <= {4'd0, dbmx10_2450[dbm_idx]};
          end
          else if(frequency_i <= FRQ4) begin
            intercept <= {4'd0, dbmx10_2470[dbm_idx]};
          end
          else begin
            intercept <= {4'd0, dbmx10_2490[dbm_idx]};
          end
          state <= PWR_INTCPT3;
        end
        PWR_INTCPT3: begin
          // prod1 still slope*FRQ2*2**32, intercept is upper 32 bits of prod1
          if(slope_is_neg)
            intercept <= intercept + prod1[47:32];
          else
            intercept <= intercept - prod1[47:32];
          state <= PWR_INTCPT4;            
        end
        PWR_INTCPT4: begin
          if(prod1[31] == 1'b1)
            intercept <= intercept + 16'd1;        
          // we have (slope*2**32) & intercept, calculate our dac value
          // dac <= (slope*frequency)/2**32 + intercept;          
          // Load up for next multiply
          dbmA <= slope;
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
          interp_mul <= 1'b0;        
          // re-use interp1 register
          if(prod1[31] == 1'b1)
            interp1[15:0] <= prod1[47:32] + intercept + 1;
          else
            interp1[15:0] <= prod1[47:32] + intercept;
          state <= PWR_DBM4;
        end
        PWR_DBM4: begin
          // Ready to send data to both DAC's. Just use this FSM to do it, 
          // except value is not in input fifo. Set next_state to PWR_VGA2
          // and let it run.
          power <= {8'd0, 8'h17, interp1[11:0], 4'd0}; 
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
