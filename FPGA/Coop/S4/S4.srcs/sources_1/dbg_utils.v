`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 3D RF Energy Corp.
// Engineer: Rick Rigby
// 
// Create Date: 08/09/2018 07:34:18 AM
// Design Name: S6
// Module Name: dbg_utils
// Project Name: S6
// Target Devices: 
// Tool Versions: 
// Description: Debugging utilities, pulse generator, debug SPI module
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

`include "version.v"
`include "status.h"
`include "timescale.v"
`include "opcodes.h"

// Using 100MHz sys_clk:
//  localparam    COUNTER_100MS   = 32'd10000000;     
//  localparam    COUNTER_50MS    = 32'd5000000;      // 5e6 * 10e-9 ==> 50e-3
//  localparam    COUNTER_25MS    = 32'd2500000;
module dbg_utils #(parameter PERIOD = 32'd10000000,     // 100ms default
                   parameter PULSE_WIDTH = 32'd1000)    // 10us default
(
  input  wire        sys_clk,
  input  wire        sys_rst_n,

  input  wire        pulse_en_i,        // enable pulse generator
  output wire        pulse_o,           // pulse output pin       

  // SPI debugging module interface, moved from top level
  input  wire [7:0]  spi_byte0_i,       // [13:0];
  input  wire [7:0]  spi_byte1_i,       // [13:0];
  input  wire [7:0]  spi_byte2_i,       // [13:0];
  input  wire [7:0]  spi_byte3_i,       // [13:0];
  input  wire [7:0]  spi_byte4_i,       // [13:0];
  input  wire [7:0]  spi_byte5_i,       // [13:0];
  input  wire [7:0]  spi_byte6_i,       // [13:0];
  input  wire [7:0]  spi_byte7_i,       // [13:0];
  input  wire [7:0]  spi_byte8_i,       // [13:0];
  input  wire [7:0]  spi_byte9_i,       // [13:0];
  input  wire [7:0]  spi_byte10_i,      // [13:0];
  input  wire [7:0]  spi_byte11_i,      // [13:0];
  input  wire [7:0]  spi_byte12_i,      // [13:0];
  input  wire [7:0]  spi_byte13_i,      // [13:0];

  input  wire [3:0]  spi_bytes_i,       // bytes to send
  input  wire        spi_start_i,
  output wire [3:0]  spi_state_o,    

  input  wire        SPI_MISO_i,
  output wire        SPI_MOSI_o,
  output wire        SPI_SCLK_o,
  output reg         SPI_SSn_o
);

    // pulse generator
    reg           pulse;
    reg  [31:0]   pulse_counter;
    always @(posedge sys_clk) begin
        if(sys_rst_n == 1'b0) begin
            pulse <= pulse_en_i;           // pulse if enabled
            pulse_counter <= 32'd0;
        end
        else begin
          
          if(pulse_counter == PULSE_WIDTH) begin
              pulse <= 1'b0;
              pulse_counter <= pulse_counter + 32'h0000_0001;
          end
          else if(pulse_counter == PERIOD) begin
              pulse <= pulse_en_i;
              pulse_counter <= 32'd0;
          end
          else begin
              pulse_counter <= pulse_counter + 32'h0000_0001;
          end
        end
    end    
    // concurrent assignments
    assign pulse_o = pulse;
    
    // ******************************************************************************
    // * RMR Debug SPI                                                              *
    // *                                                                            *
    // *  spi:  Initial SPI instance for debugging s4 HW                            *
    // *        31-Mar-2017 Add SPI instances to debug on s4                        *
    // *        We'll run at 12.5MHz (100MHz/8), CPOL=0, CPHA=0                     *
    // *                                                                            *
    // ******************************************************************************

      // SPI debugging connections for w 03000040 command
      // Write up to 14 byte to SPI device
      wire [7:0]   arr_spi_bytes [13:0];

      reg         SPI_MISO;
      wire        SPI_MOSI;
      wire        SPI_SCLK;
      reg         SPI_SSn;
      
      reg         spi_run = 0;
      reg  [7:0]  spi_write;
      wire [7:0]  spi_read;
      wire        spi_busy;         // 'each byte' busy
      wire        spi_done_byte;    // 1=done with a byte, data is valid
      spi #(.CLK_DIV(3)) debug_spi 
      (
          .clk(sys_clk),
          .rst(!sys_rst_n),
          .miso(SPI_MISO),
          .mosi(SPI_MOSI),
          .sck(SPI_SCLK),
          .start(spi_run),
          .data_in(spi_write),
          .data_out(spi_read),
          .busy(spi_busy),
          .new_data(spi_done_byte)     // 1=signal, data_out is valid
      );
      
      // Run the debug SPI instance     
      reg [3:0]   spi_state    = `SPI_IDLE; 
      reg [3:0]   dbg_spi_count;      // down counter         
      
      always @(posedge sys_clk) begin
        if(sys_rst_n == 1'b0) begin
          SPI_SSn <= 1'b1;
          spi_state <= `SPI_IDLE;    
        end
        else begin
          case(spi_state)
          `SPI_IDLE: begin
            if(spi_start_i) begin
              spi_run <= 1'b1;
              dbg_spi_count <= 0;
              spi_write <= arr_spi_bytes[0];
              spi_state <= `SPI_START_WAIT;
              SPI_SSn <= 1'b0;
            end
            else
              SPI_SSn = 1'b1;
          end
          `SPI_FETCH_DEVICE: begin
          end
          `SPI_START_WAIT: begin
            if(spi_busy == 1'b1) begin
              dbg_spi_count <= dbg_spi_count + 1;
              spi_state <= `SPI_WRITING;
            end
          end
          `SPI_WRITING: begin
            if(spi_done_byte == 1'b1) begin
              // ready for next byte 
              if(dbg_spi_count == spi_bytes_i) begin
                spi_run <= 1'b0;
                //dbg_spi_done <= 1'b1;        
                spi_state <= `SPI_SSN_OFF;
              end
              else begin
                spi_write <= arr_spi_bytes[dbg_spi_count];
                spi_state <= `SPI_START_WAIT;
              end
            end
          end
          `SPI_SSN_OFF: begin
            if(spi_busy == 1'b0) begin
              SPI_SSn <= 1'b1;
              spi_state <= `SPI_IDLE;
            end
          end
          endcase
        end
      end
      // SPI concurrent assignments
      assign spi_state_o = spi_state;
      assign arr_spi_bytes[0]  = spi_byte0_i;
      assign arr_spi_bytes[1]  = spi_byte1_i;
      assign arr_spi_bytes[2]  = spi_byte2_i;
      assign arr_spi_bytes[3]  = spi_byte3_i;
      assign arr_spi_bytes[4]  = spi_byte4_i;
      assign arr_spi_bytes[5]  = spi_byte5_i;
      assign arr_spi_bytes[6]  = spi_byte6_i;
      assign arr_spi_bytes[7]  = spi_byte7_i;
      assign arr_spi_bytes[8]  = spi_byte8_i;
      assign arr_spi_bytes[9]  = spi_byte9_i;
      assign arr_spi_bytes[10] = spi_byte10_i;
      assign arr_spi_bytes[11] = spi_byte11_i;
      assign arr_spi_bytes[12] = spi_byte12_i;
      assign arr_spi_bytes[13] = spi_byte13_i;

endmodule
