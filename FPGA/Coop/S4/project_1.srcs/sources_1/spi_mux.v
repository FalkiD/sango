//////////////////////////////////////////////////////////////////////////////////
// Company: Ampleon
// Engineer: Rick Rigby
// 
// Create Date: 07/13/2016 09:35:04 AM
// Design Name: 
// Module Name: spi_mux
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 8-way mux of the SPI processor input fifo and
//              SPI queue fifo lines
//              This module only handles writing the fifo data.
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
//    JL Cooper  08/09/2016  Added commented code in old Verilog style.
// 
//////////////////////////////////////////////////////////////////////////////////

`include "timescale.v"
`include "version.v"

`include "status.h"
`include "spi_arbiter.h"

module spi_mux(
    input wire          clk,
    input wire          rst,
    input wire          enable_i,

    input wire [2:0]    mux_select_i,       // Mux selector, 0-7

    // SPI data is written to dual-clock fifo, then SPI write request is queued.
    // spi_processor_idle is asserted when write is finished by top level.
    output reg [7:0]    spi_data_o,         // spi fifo data
    output reg          spi_wr_en_o,        // spi fifo write enable
    input               spi_fifo_empty_i,   // spi fifo empty flag
    input               spi_fifo_full_i,    // spi fifo full flag
    input               spi_wr_ack_i,       // spi fifo write acknowledge

    // The fifo to request an SPI write from the top level
    output reg [7:0]    spiwr_queue_data_o,       // queue request for DDS write
    output reg          spiwr_queue_wr_en_o,      // spiqueue fifo write enable
    input               spiwr_queue_fifo_empty_i, // spiqueue fifo empty flag
    input               spiwr_queue_fifo_full_i,  // spiqueue fifo full flag
    input               spiwr_queue_wr_ack_i,     // spiqueue fifo write acknowledge

    // Mux'd array
//    input [7:0]         fifo_data_i[7:0],         // spi fifo data
    input [7:0]         fifo_data_i7,             // spi fifo data from input #7.	
    input [7:0]         fifo_data_i6,             // spi fifo data from input #6.	
    input [7:0]         fifo_data_i5,             // spi fifo data from input #5.	
    input [7:0]         fifo_data_i4,             // spi fifo data from input #4.	
    input [7:0]         fifo_data_i3,             // spi fifo data from input #3.	
    input [7:0]         fifo_data_i2,             // spi fifo data from input #2.	
    input [7:0]         fifo_data_i1,             // spi fifo data from input #1.	
    input [7:0]         fifo_data_i0,             // spi fifo data from input #0.	
    //input               fifo_wr_en_i[7:0],        // spi fifo write enable
    input               fifo_wr_en_i7,              // spi fifo write enable
    input               fifo_wr_en_i6,              // spi fifo write enable
    input               fifo_wr_en_i5,              // spi fifo write enable
    input               fifo_wr_en_i4,              // spi fifo write enable
    input               fifo_wr_en_i3,              // spi fifo write enable
    input               fifo_wr_en_i2,              // spi fifo write enable
    input               fifo_wr_en_i1,              // spi fifo write enable
    input               fifo_wr_en_i0,              // spi fifo write enable
    //output reg          fifo_empty_o[7:0],        // spi fifo empty flag
    output reg          fifo_empty_o7,              // spi fifo empty flag
    output reg          fifo_empty_o6,              // spi fifo empty flag
    output reg          fifo_empty_o5,              // spi fifo empty flag
    output reg          fifo_empty_o4,              // spi fifo empty flag
    output reg          fifo_empty_o3,              // spi fifo empty flag
    output reg          fifo_empty_o2,              // spi fifo empty flag
    output reg          fifo_empty_o1,              // spi fifo empty flag
    output reg          fifo_empty_o0,              // spi fifo empty flag

    //output reg          fifo_full_o[7:0],         // spi fifo full flag
    output reg          fifo_full_o7,               // spi fifo full flag
    output reg          fifo_full_o6,               // spi fifo full flag
    output reg          fifo_full_o5,               // spi fifo full flag
    output reg          fifo_full_o4,               // spi fifo full flag
    output reg          fifo_full_o3,               // spi fifo full flag
    output reg          fifo_full_o2,               // spi fifo full flag
    output reg          fifo_full_o1,               // spi fifo full flag
    output reg          fifo_full_o0,               // spi fifo full flag
    
    //output reg          fifo_wr_ack_o[7:0],       // spi fifo write acknowledge
    output reg          fifo_wr_ack_o7,             // spi fifo write acknowledge
    output reg          fifo_wr_ack_o6,             // spi fifo write acknowledge
    output reg          fifo_wr_ack_o5,             // spi fifo write acknowledge
    output reg          fifo_wr_ack_o4,             // spi fifo write acknowledge
    output reg          fifo_wr_ack_o3,             // spi fifo write acknowledge
    output reg          fifo_wr_ack_o2,             // spi fifo write acknowledge
    output reg          fifo_wr_ack_o1,             // spi fifo write acknowledge
    output reg          fifo_wr_ack_o0,             // spi fifo write acknowledge

    // Mux'd command array
//    input [7:0]         cmd_fifo_data_i[7:0],       // spi queue fifo data
    input[7:0]          cmd_fifo_data_i7,
    input[7:0]          cmd_fifo_data_i6,
    input[7:0]          cmd_fifo_data_i5,
    input[7:0]          cmd_fifo_data_i4,
    input[7:0]          cmd_fifo_data_i3,
    input[7:0]          cmd_fifo_data_i2,
    input[7:0]          cmd_fifo_data_i1,
    input[7:0]          cmd_fifo_data_i0,

    //input               cmd_fifo_wr_en_i[7:0],      // spi queue fifo write enable
    input               cmd_fifo_wr_en_i7,          // spi queue fifo write enable
    input               cmd_fifo_wr_en_i6,          // spi queue fifo write enable
    input               cmd_fifo_wr_en_i5,          // spi queue fifo write enable
    input               cmd_fifo_wr_en_i4,          // spi queue fifo write enable
    input               cmd_fifo_wr_en_i3,          // spi queue fifo write enable
    input               cmd_fifo_wr_en_i2,          // spi queue fifo write enable
    input               cmd_fifo_wr_en_i1,          // spi queue fifo write enable
    input               cmd_fifo_wr_en_i0,          // spi queue fifo write enable
    
    //output reg          cmd_fifo_empty_o[7:0],      // spi queue fifo empty flag
    output reg          cmd_fifo_empty_o7,          // spi queue fifo empty flag    
    output reg          cmd_fifo_empty_o6,          // spi queue fifo empty flag    
    output reg          cmd_fifo_empty_o5,          // spi queue fifo empty flag    
    output reg          cmd_fifo_empty_o4,          // spi queue fifo empty flag    
    output reg          cmd_fifo_empty_o3,          // spi queue fifo empty flag    
    output reg          cmd_fifo_empty_o2,          // spi queue fifo empty flag    
    output reg          cmd_fifo_empty_o1,          // spi queue fifo empty flag    
    output reg          cmd_fifo_empty_o0,          // spi queue fifo empty flag    
    
    //output reg          cmd_fifo_full_o[7:0],       // spi queue fifo full flag
    output reg          cmd_fifo_full_o7,           // spi queue fifo full flag
    output reg          cmd_fifo_full_o6,           // spi queue fifo full flag
    output reg          cmd_fifo_full_o5,           // spi queue fifo full flag
    output reg          cmd_fifo_full_o4,           // spi queue fifo full flag
    output reg          cmd_fifo_full_o3,           // spi queue fifo full flag
    output reg          cmd_fifo_full_o2,           // spi queue fifo full flag
    output reg          cmd_fifo_full_o1,           // spi queue fifo full flag
    output reg          cmd_fifo_full_o0,           // spi queue fifo full flag
    
    //output reg          cmd_fifo_wr_ack_o[7:0]      // spi queue fifo write acknowledge
    output reg          cmd_fifo_wr_ack_o7,      // spi queue fifo write acknowledge
    output reg          cmd_fifo_wr_ack_o6,      // spi queue fifo write acknowledge
    output reg          cmd_fifo_wr_ack_o5,      // spi queue fifo write acknowledge
    output reg          cmd_fifo_wr_ack_o4,      // spi queue fifo write acknowledge
    output reg          cmd_fifo_wr_ack_o3,      // spi queue fifo write acknowledge
    output reg          cmd_fifo_wr_ack_o2,      // spi queue fifo write acknowledge
    output reg          cmd_fifo_wr_ack_o1,      // spi queue fifo write acknowledge
    output reg          cmd_fifo_wr_ack_o0
    );

    always @(*)
    begin
        if(enable_i && !rst)
        begin
            //spi_data_o = fifo_data_i[mux_select_i];
            case (mux_select_i)
            3'b000: begin
                spi_data_o = fifo_data_i0;
                spi_wr_en_o = fifo_wr_en_i0;
                fifo_empty_o0 = spi_fifo_empty_i;
                fifo_full_o0 = spi_fifo_full_i;
                fifo_wr_ack_o0 = spi_wr_ack_i;

                spiwr_queue_data_o = cmd_fifo_data_i0;
                spiwr_queue_wr_en_o = cmd_fifo_wr_en_i0;
                cmd_fifo_empty_o0 = spiwr_queue_fifo_empty_i;
                cmd_fifo_full_o0 = spiwr_queue_fifo_full_i;
                cmd_fifo_wr_ack_o0 = spiwr_queue_wr_ack_i; 
            end
            3'b001: begin
                spi_data_o = fifo_data_i1;
                spi_wr_en_o = fifo_wr_en_i1;
                fifo_empty_o1 = spi_fifo_empty_i;
                fifo_full_o1 = spi_fifo_full_i;
                fifo_wr_ack_o1 = spi_wr_ack_i;
    
                spiwr_queue_data_o = cmd_fifo_data_i1;
                spiwr_queue_wr_en_o = cmd_fifo_wr_en_i1;
                cmd_fifo_empty_o1 = spiwr_queue_fifo_empty_i;
                cmd_fifo_full_o1 = spiwr_queue_fifo_full_i;
                cmd_fifo_wr_ack_o1 = spiwr_queue_wr_ack_i; 
            end
            3'b010: begin
                spi_data_o = fifo_data_i2;
                spi_wr_en_o = fifo_wr_en_i2;
                fifo_empty_o2 = spi_fifo_empty_i;
                fifo_full_o2 = spi_fifo_full_i;
                fifo_wr_ack_o2 = spi_wr_ack_i;
    
                spiwr_queue_data_o = cmd_fifo_data_i2;
                spiwr_queue_wr_en_o = cmd_fifo_wr_en_i2;
                cmd_fifo_empty_o2 = spiwr_queue_fifo_empty_i;
                cmd_fifo_full_o2 = spiwr_queue_fifo_full_i;
                cmd_fifo_wr_ack_o2 = spiwr_queue_wr_ack_i; 
            end
            3'b011: begin
                spi_data_o = fifo_data_i3;
                spi_wr_en_o = fifo_wr_en_i3;
                fifo_empty_o3 = spi_fifo_empty_i;
                fifo_full_o3 = spi_fifo_full_i;
                fifo_wr_ack_o3 = spi_wr_ack_i;
    
                spiwr_queue_data_o = cmd_fifo_data_i3;
                spiwr_queue_wr_en_o = cmd_fifo_wr_en_i3;
                cmd_fifo_empty_o3 = spiwr_queue_fifo_empty_i;
                cmd_fifo_full_o3 = spiwr_queue_fifo_full_i;
                cmd_fifo_wr_ack_o3 = spiwr_queue_wr_ack_i; 
            end
            3'b100: begin
                spi_data_o = fifo_data_i4;
                spi_wr_en_o = fifo_wr_en_i4;
                fifo_empty_o4 = spi_fifo_empty_i;
                fifo_full_o4 = spi_fifo_full_i;
                fifo_wr_ack_o4 = spi_wr_ack_i;
    
                spiwr_queue_data_o = cmd_fifo_data_i4;
                spiwr_queue_wr_en_o = cmd_fifo_wr_en_i4;
                cmd_fifo_empty_o4 = spiwr_queue_fifo_empty_i;
                cmd_fifo_full_o4 = spiwr_queue_fifo_full_i;
                cmd_fifo_wr_ack_o4 = spiwr_queue_wr_ack_i; 
            end
            3'b101: begin
                spi_data_o = fifo_data_i5;
                spi_wr_en_o = fifo_wr_en_i5;
                fifo_empty_o5 = spi_fifo_empty_i;
                fifo_full_o5 = spi_fifo_full_i;
                fifo_wr_ack_o5 = spi_wr_ack_i;
    
                spiwr_queue_data_o = cmd_fifo_data_i5;
                spiwr_queue_wr_en_o = cmd_fifo_wr_en_i5;
                cmd_fifo_empty_o5 = spiwr_queue_fifo_empty_i;
                cmd_fifo_full_o5 = spiwr_queue_fifo_full_i;
                cmd_fifo_wr_ack_o5 = spiwr_queue_wr_ack_i; 
            end
            3'b110: begin
                spi_data_o = fifo_data_i6;
                spi_wr_en_o = fifo_wr_en_i6;
                fifo_empty_o6 = spi_fifo_empty_i;
                fifo_full_o6 = spi_fifo_full_i;
                fifo_wr_ack_o6 = spi_wr_ack_i;
    
                spiwr_queue_data_o = cmd_fifo_data_i6;
                spiwr_queue_wr_en_o = cmd_fifo_wr_en_i6;
                cmd_fifo_empty_o6 = spiwr_queue_fifo_empty_i;
                cmd_fifo_full_o6 = spiwr_queue_fifo_full_i;
                cmd_fifo_wr_ack_o6 = spiwr_queue_wr_ack_i; 
            end
            3'b111: begin
                spi_data_o = fifo_data_i7;
                spi_wr_en_o = fifo_wr_en_i7;
                fifo_empty_o7 = spi_fifo_empty_i;
                fifo_full_o7 = spi_fifo_full_i;
                fifo_wr_ack_o7 = spi_wr_ack_i;
    
                spiwr_queue_data_o = cmd_fifo_data_i7;
                spiwr_queue_wr_en_o = cmd_fifo_wr_en_i7;
                cmd_fifo_empty_o7 = spiwr_queue_fifo_empty_i;
                cmd_fifo_full_o7 = spiwr_queue_fifo_full_i;
                cmd_fifo_wr_ack_o7 = spiwr_queue_wr_ack_i; 
            end
            endcase
        end
    end
endmodule
