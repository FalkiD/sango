`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: Ampleon USA
// Engineer: Rick Rigby
// 
// Create Date: 07/15/2017 02:47:49 PM
// Design Name: S4 FPGA core
// Module Name: run_spi
// Project Name: S4
// Target Devices: Artix-7
// Tool Versions: Vivado 2016.4
// Description: Run an SPI instance
// 
// Dependencies: spi_master.v
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

//`include "timescale.v"
`include "version.v"
`include "status.h"

module run_spi  #(parameter WIDTH = 32,         // Width of input word(s)
                  parameter MS_FIRST = 1'b1,    // MS byte sent first
                  parameter TOTAL_BYTES = 4)
(
  input  wire               sys_clk,
  input  wire               sys_rst_n,
  
  input  wire               spi_en,
  output reg                spi_done_o,

  input  wire               spi_go,
  input  wire [WIDTH-1:0]   spi_dat_i,
  
  output reg                SSn,
  input  wire               MISO,
  output reg                MOSI,
  output wire               SCLK,

  output reg [7:0]          status_o            // SUCCESS when done, or an error code
);

// ******************************************************************************
// *                                                                            *
// *  spi:  SPI instance for s4 HW                            *
// *        We'll run at 12.5MHz (100MHz/8), CPOL=0, CPHA=0                     *
// *                                                                            *
// ******************************************************************************
 
  reg         spi_run = 0;
  reg  [7:0]  spi_write;
  wire [7:0]  spi_read;
  wire        spi_busy;         // 'each byte' busy
  wire        spi_done_byte;    // 1=done with a byte, data is valid
  spi #(.CLK_DIV(3)) syn_spi 
  (
      .clk(sys_clk),
      .rst(!sys_rst_n),
      .miso(MISO),
      .mosi(MOSI),
      .sck(SCLK),
      .start(spi_run),
      .data_in(spi_write),
      .data_out(spi_read),
      .busy(spi_busy),
      .new_data(spi_done_byte)     // 1=signal, data_out is valid
  );

  // Run an SPI instance
  localparam SPI_IDLE         = 4'd0;
  localparam SPI_START_WAIT   = 4'd1;
  localparam SPI_WRITING      = 4'd2;
  localparam SPI_SSN_OFF      = 4'd3;
 
  reg [3:0]   spi_state    = SPI_IDLE;    
  reg [4:0]   spi_count;
  reg [4:0]   spi_bytes;
  
  always @(posedge sys_clk) begin
    if(sys_rst_n == 1'b0) begin
      spi_bytes <= TOTAL_BYTES;
      SSn <= 1'b1;
      spi_state <= SPI_IDLE;    
    end
    else begin
      case(spi_state)
      SPI_IDLE: begin
        if(spi_go) begin
          spi_run <= 1'b1;
          spi_count <= 0;
          spi_write <= spi_dat_i[WIDTH-1:WIDTH-8];
          spi_state <= SPI_START_WAIT;
          SSn <= 1'b0;
        end
        else
          SSn = 1'b1;
      end
      SPI_START_WAIT: begin
        if(spi_busy == 1'b1) begin
          spi_count <= spi_count + 1;
          spi_state <= SPI_WRITING;
        end
      end
      SPI_WRITING: begin
        if(spi_done_byte == 1'b1) begin
          // ready for next byte 
          if(spi_count == spi_bytes) begin
            spi_run <= 1'b0;
            spi_done_o <= 1'b1;        
            spi_state <= SPI_SSN_OFF;
          end
          else begin
            case(spi_count)
            1: spi_write <= spi_dat_i[23:16];
            2: spi_write <= spi_dat_i[15:8];
            3: spi_write <= spi_dat_i[7:0];
            endcase
            spi_state <= SPI_START_WAIT;
          end
        end
      end
      SPI_SSN_OFF: begin
        if(spi_busy == 1'b0) begin
          SSn <= 1'b1;
          spi_state <= SPI_IDLE;
        end
      end
      endcase
    end
  end

endmodule
