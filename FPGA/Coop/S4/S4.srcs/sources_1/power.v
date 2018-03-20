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
//  We'll default to high-gain mode, 
//  datasheet figure 12 gives gain data(higain)
//  at 2.6GHz while varying both VGAIN1 & VGAIN2
//  Looks like 3.3v ~ -12dB, 0v ~ +2dB
//
//  Note: higain mode is controlled by input line from top level.
// 
// Dependencies: 
// 
// Revision:
// Rev 0.02 - 19-Mar-2018, fix frequency interpolation.
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
  
  input  wire           doInit_i,       // Initialize DAC's after reset

  // during calibration, frequency_i indicates which table to update  
  input  wire           doCalibrate_i,  // Update power table from CALPTBL opcode
  input  wire  [11:0]   caldata_i,      // 12-bits cal data
  input  wire  [11:0]   calidx_i,       // index of cal data

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

  input  wire           vga_higain_i,             // default to 1, high gain mode
  input  wire           vga_dacctla_i,            // DAC control A bit. Normally fix A, control dac B

  // outputs, VGA SPI to DAC7563
  output wire           VGA_MOSI_o,
  output wire           VGA_SCLK_o,
  output reg            VGA_SSn_o,       
  output wire           VGA_VSW_o,                // VSW controls gain mode, 1=high, 0=low

  input  wire [31:0]    frequency_i,              // current frequency in Hertz
  
  output reg  [11:0]    dbmx10_o,                 // present power setting for all top-level modules to access
  
  output reg  [7:0]     status_o       // 0=busy, SUCCESS when done, or an error code

//  // Debugging interpolation registers
//  output reg  [11:0]    Y2_o,
//  output reg  [11:0]    Y1_o,
//  output reg  [31:0]    slope_o,
//  output reg  [47:0]    intercept_o,
//  output reg  [11:0]    dac_o
);

  localparam DBM_OFFSET       = 24'd102400;  // 40.0 dBm * 256 * 10
  localparam DBM_MAX          = 24'd166400;  // 65.0 dBm * 256 * 10
  localparam DBM_MAX_OFFSET   = 24'd250;     // 251 entries per table at 0.1dBm intervals
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
  
  localparam CTL_DACB_ONLY      = 8'h11;
  localparam CTL_DACA_ALSO      = 8'h17;

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
  reg  [7:0]      dac_control;        // defaults to B only, change w/CONFIG opcode
  
  // interpolation multiplier vars
  reg  [31:0]     dbmA;
  reg  [31:0]     interp1;
  wire [63:0]     prod1;
  reg             interp_mul;   // enable interpolation multiplier
  
  // interpolation vars
  reg  [31:0]     slope;        // slope * 2**32
  reg             slope_is_neg; // flag if slope is negative
  reg  [47:0]     intercept;
  reg  [47:0]     result;

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

  // power tables, initialized to linear values, written
  // at startup by MCU to calibrated values
  localparam TOP_INDEX = 12'd250;
  reg [11:0]      dbmx10_2410 [0:250];
  reg [11:0]      dbmx10_2430 [0:250];
  reg [11:0]      dbmx10_2450 [0:250];
  reg [11:0]      dbmx10_2470 [0:250];
  reg [11:0]      dbmx10_2490 [0:250];
  // power tables initialized flag
  reg             tbl_init = 1'b0;

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
    .CLK_DIV(2),                // use 25MHz, DAC max is 50MHz
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
  localparam PWR_DBM5           = 9;
  localparam PWR_VGA1           = 10;
  localparam PWR_VGA2           = 11;
  localparam PWR_VGA3           = 12;
  localparam PWR_VGA4           = 13;
  localparam PWR_VGA5           = 14;
  localparam PWR_WAIT           = 15;
  localparam WAIT_SPI           = 16;
  localparam PWR_SLOPE1         = 17;
  localparam PWR_SLOPE2         = 18;
  localparam PWR_SLOPE3         = 19;
  localparam PWR_INTCPT1        = 20;
  localparam PWR_INTCPT2        = 21;
  localparam PWR_INTCPT3        = 22;
  localparam PWR_INTCPT4        = 23;
  localparam PWR_INTCPT5        = 24;
  localparam PWR_INIT1          = 25;
  localparam PWR_INIT2          = 26;
  localparam PWR_TBL_INIT       = 27;
  localparam PWR_TBL_CAL        = 28;

  localparam    DAC_WORD0       = 32'h00380000;     // Disable internal refs, Gain=1
  localparam    DAC_WORD1       = 32'h00300003;     // LDAC pin inactive DAC A & B
  localparam    DACAB_FS        = 32'h0017FFF0;     // DAC AB input, write both. full scale is minimum power

  ////////////////////////////////////////
  // End of power state definitions //
  ////////////////////////////////////////

  assign VGA_VSW_o = vga_higain_i;  // Default is 1, high-gain mode

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
      dac_control <= CTL_DACB_ONLY;     // defaults to B only, change w/CONFIG opcode
      result <= 48'h0000_0000_0000;
    end
    else if(power_en == 1) begin

      if(vga_dacctla_i && dac_control != CTL_DACA_ALSO)
        dac_control <= CTL_DACA_ALSO;
      else if(!vga_dacctla_i && dac_control != CTL_DACB_ONLY)
        dac_control <= CTL_DACB_ONLY;

      // calibrate is special case, overwrite the values in the
      // cal table from the opcode processor
      if(doCalibrate_i) begin
      
        if(frequency_i == FRQ1) begin
            dbmx10_2410[calidx_i] <= caldata_i;
        end
        else if(frequency_i == FRQ2) begin
            dbmx10_2430[calidx_i] <= caldata_i;
        end
        else if(frequency_i == FRQ3) begin
            dbmx10_2450[calidx_i] <= caldata_i;
        end
        else if(frequency_i == FRQ4) begin
            dbmx10_2470[calidx_i] <= caldata_i;
        end
        else begin
            dbmx10_2490[calidx_i] <= caldata_i;
        end
      end
    
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
        PWR_TBL_INIT: begin
          // fill power table RAM with default values
          // this will follow PWR_INIT1 after sys_rst
          if(dbm_idx == 0) begin
            dbmx10_2410[0] <= 12'hfff;
            dbmx10_2430[0] <= 12'hfff;
            dbmx10_2450[0] <= 12'hfff;
            dbmx10_2470[0] <= 12'hfff;
            dbmx10_2490[0] <= 12'hfff;
            state <= PWR_IDLE;
          end
          else begin
            dbmx10_2410[dbm_idx] <= power[11:0];
            dbmx10_2430[dbm_idx] <= power[11:0];
            dbmx10_2450[dbm_idx] <= power[11:0];
            dbmx10_2470[dbm_idx] <= power[11:0];
            dbmx10_2490[dbm_idx] <= power[11:0];
            dbm_idx <= dbm_idx - 1;
            power[11:0] <= power[11:0] + 11'h010;
          end
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
            //state <= PWR_IDLE;
            init_wordnum <= 3'd0;            
            // Follow INIT_DACS with init power table
            //else if(tbl_init == 1'b0) begin
            state <= PWR_TBL_INIT;
            dbm_idx <= TOP_INDEX;
            power[11:0] <= 12'd0; 
            //end
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
          if(!vga_dacctla_i)
            // control only DAC B, clear ctl bits for dac A
            power[23:16] <= CTL_DACB_ONLY;
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
          // min is 40dBm*256*10=102,400
          // max is 65dBm*256*10=166,400 => 0x28a00. Use 12 bits beginning at d8
          multiply <= 1'b0;
          if(DBM_OFFSET[19:8] >= q7dot8x10[19:8])
            dbm_idx <= 12'd0;
          else if(q7dot8x10[19:8] >= DBM_MAX[19:8])
            dbm_idx <= DBM_MAX_OFFSET;
          else
            dbm_idx <= q7dot8x10[19:8] - DBM_OFFSET[19:8]; // (/256.0) - 400, the array index for requested power
          dbmx10_o <= q7dot8x10[19:8];  // present power setting for all top-level modules to access, dBm x10
          slope_is_neg <= 1'b0;         // clear a flag
          state <= PWR_SLOPE1;
        end
        PWR_SLOPE1: begin
          // interpolate between power tables
          // jump to state <= PWR_VGA2; once power variable is set
          if(frequency_i <= FRQ2) begin
          // slope = ((dbmx10_2430[dbm_idx] - dbmx10_2410[dbm_idx]))/(FRQ_DELTA); // (Yb-Ya)/(Xb-Xa)
          // Using (slope * 2**32) ==> (1/FRQ_DELTA) * 2**32 = 214.74836 ~= 215
          // slope * 2**32 ~= 215 * (dbmx10_2430[dbm_idx] - dbmx10_2410[dbm_idx]);
          //
          // Then intercept*(2**32) = 2**32*(mX2) - 2**32*Y2 ==> ((slope*2**32)*frq2) - dbmx10_2430[dbm_idx]*2**32;
          // intercept = intercept >> 32;
          // Assuming max delta between freq tables of 2048, 215*2048 = 440,320.
          // This requires 19 bits, use a 32 bit register.
            dbmA <= dbmx10_2430[dbm_idx] - dbmx10_2410[dbm_idx];            
//            if(dbmx10_2430[dbm_idx] < dbmx10_2410[dbm_idx])
//              slope_is_neg <= 1'b1;
//            Y2_o <= dbmx10_2430[dbm_idx];
//            Y1_o <= dbmx10_2410[dbm_idx];
          end
          else if(frequency_i <= FRQ3) begin
            dbmA <= dbmx10_2450[dbm_idx] - dbmx10_2430[dbm_idx];    
//            if(dbmx10_2450[dbm_idx] < dbmx10_2430[dbm_idx])
//              slope_is_neg <= 1'b1;
//            Y2_o <= dbmx10_2450[dbm_idx];
//            Y1_o <= dbmx10_2430[dbm_idx];
          end
          else if(frequency_i <= FRQ4) begin
            dbmA <= dbmx10_2470[dbm_idx] - dbmx10_2450[dbm_idx];           
//            if(dbmx10_2470[dbm_idx] < dbmx10_2450[dbm_idx])
//              slope_is_neg <= 1'b1;
//            Y2_o <= dbmx10_2470[dbm_idx];
//            Y1_o <= dbmx10_2450[dbm_idx];
          end
          else begin
            dbmA <= dbmx10_2490[dbm_idx] - dbmx10_2470[dbm_idx];           
//            if(dbmx10_2490[dbm_idx] < dbmx10_2470[dbm_idx])
//              slope_is_neg <= 1'b1;
//            Y2_o <= dbmx10_2490[dbm_idx];
//            Y1_o <= dbmx10_2470[dbm_idx];
          end
          interp1 <= {16'd0, K};
          state <= PWR_SLOPE2;
        end
        PWR_SLOPE2: begin
          // Calculate (Y2-Y1) * [(1/(X2-X1)) * 2**32] where [] = 215 ==> K
          interp_mul <= 1'b1;
          latency_counter <= MULTIPLIER_CLOCKS;
          next_state <= PWR_SLOPE3;
          state <= PWR_WAIT;
        end
        PWR_SLOPE3: begin
          // prod1 is 64 bit (slope * 2**32)
          interp_mul <= 1'b0;
          slope <= prod1[31:0];    
//          slope_o <= prod1[31:0];   // TBD dbg
          dbmA <= prod1[31:0];      // slope*2**32 into dbmA
          // Use slope and X2, Y2 to calculate intercept
          // 2**32 * b = 2**32 * m * X2  -  2**32 * Y2
          // X2(Frq2) into multiplicand, calculate (2**32*slope*X2)
          // Y2 * 2**32 into intercept register for later step
          if(frequency_i <= FRQ2) begin
            interp1 <= FRQ2;
            intercept <= {4'd0, dbmx10_2430[dbm_idx], 32'h0000_0000};  // setup for later step
          end
          else if(frequency_i <= FRQ3) begin
            interp1 <= FRQ3;            
            intercept <= {4'h0, dbmx10_2450[dbm_idx], 32'h0000_0000};  // setup for later step
          end
          else if(frequency_i <= FRQ4) begin
            interp1 <= FRQ4;           
            intercept <= {4'd0, dbmx10_2470[dbm_idx], 32'h0000_0000};  // setup for later step
          end
          else begin
            interp1 <= FRQ5;           
            intercept <= {4'd0, dbmx10_2490[dbm_idx], 32'h0000_0000};  // setup for later step
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
          // prod1 is 2**32 * m * X2, 48 bits
          // intercept register contains Y2 * 2**32, to be subtracted from prod1,
          // 2**32 * b = prod1 - intercept
          interp_mul <= 1'b0;
          intercept <= prod1[47:0] - intercept;

          // we have m & b, setup for final dac calculation
          // we have (slope*2**32) & intercept*2**32, calculate our dac value
          // dac <= ((slope*2**32*frequency) + intercept*2**32) >> 32;          
          dbmA <= slope;
          interp1 <= frequency_i;        

          state <= PWR_DBM2;
        end
        PWR_DBM2: begin
          // TBD debugging
          //intercept_o <= intercept;

          interp_mul <= 1'b1;
          latency_counter <= MULTIPLIER_CLOCKS;          
          next_state <= PWR_DBM3;
          state <= PWR_WAIT;
        end
        PWR_DBM3: begin
          interp_mul <= 1'b0;
          result <= prod1[47:0];
          state <= PWR_DBM4;
        end
        PWR_DBM4: begin
          result <= result - intercept; // should be +, intercept has wrong sign somehow?
          state <= PWR_DBM5;
        end
        PWR_DBM5: begin
          //
          // result register is interpolated dac value * 2**32
          //
          // Ready to send data to both DAC's. Use this FSM to do it, 
          // except value is not in input fifo. Set next_state to PWR_VGA2
          // and let it run.
          // TBD dac_o <= result[43:32];
          power <= {8'd0, dac_control, result[43:32], 4'd0}; 
          state <= PWR_VGA2;        // write 1st byte of 3
          VGA_SSn_o <= 1'b0;
        end
        default: begin
          status_o <= `ERR_UNKNOWN_PWR_STATE;
          state <= PWR_IDLE;
        end
        endcase
    end
  end

endmodule
