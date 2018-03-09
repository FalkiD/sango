//////////////////////////////////////////////////////////////////////////////////
// Company: Ampleon 
// Engineer: Rick Rigby
// 
// Create Date: 03/28/2016 06:13:10 PM
// Design Name: Frequency processor for S4 AD9954 DDS programming
// Module Name: frequency
// Project Name: Sango family
// Target Devices: ARTIX-7, AD9954
// Tool Versions: 
// Description: Process fifo of frequencies, populate the SPI fifo
//              for caller to write to SPI
// 
// Dependencies: 
// 
// Revision:
//          0.02 - 08-Mar-2018 improvments:
//                  After writing frequency tuning word, wait for DDS_SS to go low,
//                  then high, wait for SYN_SS to go low, then high, wait up to xx ms
//                  for SYN_LOCK to turn ON. If no SYN lock, set status to ERR code
// Revision 0.01 - File Created
// Additional Comments:  
// 
//////////////////////////////////////////////////////////////////////////////////

/*
 * Programming notes:
 *
 * -On the S4, changing frequency while a pattern is running is supported.
 * We'll use either two frequency registers, or a flag, to control
 * overriding the frequency on the S4.
 */

`include "timescale.v"
`include "status.h"
`include "opcodes.h"

module freq_s4 #(parameter FILL_BITS = 6,
                 parameter FRQ_BITS = 32,
                 parameter SYN_LOCK_TICKS = 1000000)    // default=10ms    
(
  input  wire             sys_clk,
  input  wire             sys_rst_n,
    
  input  wire             freq_en,

  // Frequency(ies) are in Hz in input fifo
  input  wire [FRQ_BITS-1:0] frq_fifo_i,        // frequency fifo
  output reg              frq_fifo_ren_o,       // fifo read line
  input  wire             frq_fifo_empty_i,     // fifo empty flag
  input  wire [FILL_BITS-1:0] frq_fifo_count_i, // fifo count, for debug message only

  // This writes to FIFO in the DDS SPI instance
  output reg  [31:0]      ftw_o,             // tuning word output, to DDS input fifo          
  output reg              ftw_wen_o,         // frequency tuning word fifo we.

  output wire [31:0]      frequency_o,       // System frequency(Hz) so all top-level modules can access

  input  wire             dds_ss_i,          // DDS SPI SS signal
  input  wire             syn_ss_i,          // SYN SPI SS signal
  input  wire             syn_lock_i,        // SYN PLL lock signal
  output reg              frq_mute_n_o,      // control SYN mute signal while waiting for PLL lock

  output reg  [7:0]       status_o           // 0=Busy, SUCCESS when done, or an error code
);

  // Main Globals
  reg [6:0]       state = 0;
  reg [6:0]       next_state;         // saved while waiting for multiply/divide in FRQ_WAIT state
  reg [6:0]       next_spiwr_state;   // saved while waiting for SPI writes to finish before next request

  reg  [31:0]      frequency = 32'd0;
  assign frequency_o = frequency;     // keep global frequency updated
  
  // Latency for multiply operation, Xilinx multiplier
  localparam MULTIPLIER_CLOCKS = 6'd6;
  reg  [5:0]       latency_counter;    // wait for multiplier & divider 

  // SYN lock timeout counter
  reg  [31:0]      synlock_counter = 32'h0000_0000;

  reg  [31:0]      K = 32'h30037BD4;    //32'h0C00DEF5 (*4 since using 100MHz instead of 400MHz);        // Tuning word scale
  wire [63:0]      FTW;                     // FTW calculated
  reg              multiply;

  // Xilinx multiplier to perform 32 bit multiplication, output is 64 bits
  ftw_mult ftw_multiplier (
     .CLK(sys_clk),
     .A(frequency),
     .B(K),
     .CE(multiply),
     .P(FTW)
  );      
    
  /////////////////////////////////
  // Frequency state definitions //
  /////////////////////////////////
  localparam FRQ_IDLE      = 0;
  localparam FRQ_SPCR      = 1;
  localparam FRQ_READ      = 2;
  localparam FRQ_TOMHZ     = 3;
  localparam FRQ_DDS_MULT  = 4;
//  localparam FRQ_DDS_RND  =  5;
  localparam FRQ_WRITE     = 6;
  localparam FRQ_FIFO_WRT  = 7;
  localparam FRQ_WAIT      = 8;
  localparam FRQ_DDS_SSON  = 9;     // wait for DDS SS ON
  localparam FRQ_DDS_SSOFF = 10;    // wait for DDS SS OFF
  localparam FRQ_SYN_SSON  = 11;    // wait for SYN SS ON
  localparam FRQ_SYN_SSOFF = 12;    // wait for SYN SS OFF
  localparam FRQ_SYN_LOCK  = 13;    // wait for SYN PLL lock
      
  always @(posedge sys_clk)
  begin
    if(!sys_rst_n) begin
      state <= FRQ_IDLE;            
      frq_fifo_ren_o <= 0;
      ftw_o <= 32'd0;
      ftw_wen_o <= 1'b0;
      frq_mute_n_o <= 1'b1; 
      status_o <= `SUCCESS;
    end
    else if(freq_en == 1'b1) begin
      if(frequency == 0) begin
        // FPGA was just powered ON, initialize all HW... TBD
        frequency <= 32'd2450000000;    // Hz
      end
      case(state)
      FRQ_WAIT: begin
        if(latency_counter == 0) begin
          state <= next_state;
          multiply <= 1'b0;
        end
        else
          latency_counter <= latency_counter - 1;
      end
      FRQ_IDLE: begin
        if(!frq_fifo_empty_i) begin
          frq_fifo_ren_o <= 1'b1;
          state <= FRQ_SPCR;
          status_o <= `SUCCESS;
        end
      end
      FRQ_SPCR: begin
        state <= FRQ_READ;
      end
      FRQ_READ: begin
        frequency <= frq_fifo_i;        // requested frequency in Hertz
        state <= FRQ_DDS_MULT;
      end
      FRQ_DDS_MULT: begin
        frq_fifo_ren_o <= 1'b0;
        multiply <= 1'b1;
        latency_counter <= MULTIPLIER_CLOCKS;
        next_state <= FRQ_WRITE;
        state <= FRQ_WAIT;
      end
      FRQ_WRITE: begin
        if(FTW[31] == 1'b1)
          ftw_o <= FTW[63:32] + 32'd1;
        else
          ftw_o <= FTW[63:32];
        ftw_wen_o = 1'b1;
        state <= FRQ_FIFO_WRT;
      end
//      FRQ_FIFO_WRT: begin
//        ftw_wen_o = 1'b0;
//        state <= FRQ_IDLE;
//        status_o <= `SUCCESS;
//      end
      FRQ_FIFO_WRT: begin
        ftw_wen_o = 1'b0;
        state <= FRQ_DDS_SSON;
      end
      FRQ_DDS_SSON: begin
        if(dds_ss_i == 1'b0) begin
            frq_mute_n_o <= 1'b0;       // MUTE SYN while waiting
            state <= FRQ_DDS_SSOFF;
        end
      end
      FRQ_DDS_SSOFF: begin
        if(dds_ss_i == 1'b1)
            state <= FRQ_SYN_SSON;
      end
      FRQ_SYN_SSON: begin
        if(syn_ss_i == 1'b0)
            state <= FRQ_SYN_SSOFF;
      end
      FRQ_SYN_SSOFF: begin
        if(syn_ss_i == 1'b1) begin
            synlock_counter <= SYN_LOCK_TICKS;
            state <= FRQ_SYN_LOCK;
        end
      end
      FRQ_SYN_LOCK: begin               // Wait up to SYN_LOCK_MS for lock signal
        if(syn_lock_i == 1'b1) begin
            frq_mute_n_o <= 1'b1;       // Done, un-mute SYN
            state <= FRQ_IDLE;
            status_o <= `SUCCESS;
        end
        else begin
    `ifdef XILINX_SIMULATOR
            if(synlock_counter == 32'd800000) begin
                frq_mute_n_o <= 1'b1;       // Done, un-mute SYN
                state <= FRQ_IDLE;
                status_o <= `SUCCESS;
            end
    `else
            if(synlock_counter == 32'h0000_0000) begin
                state <= FRQ_IDLE;
                status_o <= `ERR_PLL_LOCK;      // timeout error
            end
    `endif
            else
                synlock_counter <= synlock_counter - 32'h0000_0001;
        end
      end
      default: begin
        status_o <= `ERR_UNKNOWN_FRQ_STATE;
        state <= FRQ_IDLE;
      end
      endcase
    end
  end
endmodule
    
