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

//`include "timescale.v"
`include "version.v"

`include "status.h"
`include "opcodes.h"

module freq_s4 #(parameter FILL_BITS = 6,
                 parameter FRQ_BITS = 32)
(
  input                   sys_clk,
  input                   sys_rst_n,
    
  input                   freq_en,
  input                   spi_idle, // Only queue SPI data when it's idle

  // Frequency(ies) are in Hz in input fifo
  input [FRQ_BITS-1:0]    frq_fifo_i,        // frequency fifo
  output reg              frq_fifo_ren_o,    // fifo read line
  input                   frq_fifo_empty_i,  // fifo empty flag
  input [FILL_BITS-1:0]   frq_fifo_count_i,  // fifo count, for debug message only

  output reg [31:0]       ftw_o,             // tuning word output          

    // SPI data is written to dual-clock fifo, then SPI write request is queued.
    // spi_processor_idle is asserted when write is finished by top level.
//    output reg [7:0]    spi_o,              // spi DDS fifo data
//    output reg          spi_wr_en_o,        // spi DDS fifo write enable
//    input               spi_fifo_empty_i,   // spi DDS fifo empty flag
//    input               spi_fifo_full_i,    // spi DDS fifo full flag
//    input               spi_wr_ack_i,       // spi DDS fifo write acknowledge

    // The fifo to request an SPI write from the top level
//    output reg [7:0]    spiwr_queue_data_o,       // queue request for DDS write
//    output reg          spiwr_queue_wr_en_o,      // spi DDS fifo write enable
//    input               spiwr_queue_fifo_empty_i, // spi DDS fifo empty flag
//    input               spiwr_queue_fifo_full_i,  // spi DDS fifo full flag
//    input               spiwr_queue_wr_ack_i,     // fifo write acknowledge

  output reg [7:0]        status_o,               // SUCCESS when done, or an error code
  output reg              busy_o                  // State of this module
);

  // Main Globals
  reg [6:0]       state = 0;
  reg [6:0]       next_state;         // saved while waiting for multiply/divide in FRQ_WAIT state
  reg [6:0]       next_spiwr_state;   // saved while waiting for SPI writes to finish before next request

  reg  [31:0]      frequency = 32'd0;
  // Latency for multiply operation, Xilinx multiplier
  `define MULTIPLIER_CLOCKS 6'd6
  reg  [5:0]       latency_counter;    // wait for multiplier & divider 

  reg  [31:0]      K = 32'h0C00DEF5;        // Tuning word scale
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
  `define FRQ_IDLE        0
  `define FRQ_SPCR        1
  `define FRQ_READ        2
  `define FRQ_TOMHZ       3
  `define FRQ_DDS_MULT    4
//  `define FRQ_DDS_RND     5
  `define FRQ_WRITE       6
  `define FRQ_WAIT        7
    
  always @(posedge sys_clk)
  begin
    if(!sys_rst_n)
    begin
      state <= `FRQ_IDLE;            
      frq_fifo_ren_o <= 0;
      ftw_o <= 32'd0;
    end
    else if(freq_en == 1'b1)
    begin
      case(state)
      `FRQ_WAIT: begin
        if(latency_counter == 0) begin
          state <= next_state;
          multiply <= 1'b0;
        end
        else
          latency_counter <= latency_counter - 1;
      end
      `FRQ_IDLE: begin
        if(!frq_fifo_empty_i) begin
          frq_fifo_ren_o <= 1'b1;
          state <= `FRQ_SPCR;
        end
      end
      `FRQ_SPCR: begin
        state <= `FRQ_READ;
      end
      `FRQ_READ: begin
        frequency <= frq_fifo_i;
        state <= `FRQ_DDS_MULT;
      end
      `FRQ_DDS_MULT: begin
        frq_fifo_ren_o <= 1'b0;
        multiply <= 1'b1;
        latency_counter <= `MULTIPLIER_CLOCKS;
        next_state <= `FRQ_WRITE;
        state <= `FRQ_WAIT;
      end
      `FRQ_WRITE: begin
        if(FTW[31] == 1'b1)
          ftw_o <= FTW[63:32] + 32'd1;
        else
          ftw_o <= FTW[63:32];
        state <= `FRQ_IDLE;
      end
      default: begin
        status_o <= `ERR_UNKNOWN_FRQ_STATE;
        state <= `FRQ_IDLE;
      end
      endcase
    end
  end
endmodule
    
