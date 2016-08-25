//////////////////////////////////////////////////////////////////////////////////
// Company: Ampleon
// Engineer: Rick Rigby
// 
// Create Date: 08/04/2016 02:25:17 PM
// Design Name: 
// Module Name: bias
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: bias processor module. Receives bias opcodes from
//              opcode processor. Geenerates SPI data to be written
//              top hardware. Waits for SPI arbiter to grant access
//              to SPI bus, writes data.
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

`include "timescale.v"
`include "version.v"

`include "status.h"
`include "opcodes.h"
`include "queue_spi.h"

module bias(
    input               clk,
    input               rst,
    
    input               bias_en,

    input               x7_mode,            // S4 is a limited version of X7, true if X7, false=S4
    input               high_speed_syn,     // synthesiser mode, true=high speed syn mode, false=high accuracy mode

    // Bias opcode(s) are in input fifo
    input [15:0]        bias_fifo_i,        // pulse fifo
    output reg          bias_fifo_rd_en_o,  // fifo read line
    input               bias_fifo_empty_i,  // fifo empty flag
    input [9:0]         bias_fifo_count_i,  // fifo count, for debug message only

    // SPI data is written to dual-clock fifo, then SPI write request is queued.
    // SPI arbiter request is made for SPI access
    output reg [7:0]    spi_o,              // spi fifo data
    output reg          spi_wr_en_o,        // spi fifo write enable
    input               spi_fifo_empty_i,   // spi fifo empty flag
    input               spi_fifo_full_i,    // spi fifo full flag
    input               spi_wr_ack_i,       // spi fifo write acknowledge
    //input [8:0]         spi_fifo_count_i,   // spi fifo counter

    // The fifo to request an SPI write from the top level
    output reg [7:0]    spiwr_queue_data_o,       // queue request for DDS write
    output reg          spiwr_queue_wr_en_o,      // spi fifo write enable
    input               spiwr_queue_fifo_empty_i, // spi fifo empty flag
    input               spiwr_queue_fifo_full_i,  // spi fifo full flag
    input               spiwr_queue_wr_ack_i,     // fifo write acknowledge
    //input [4:0]         spiwr_queue_fifo_count_i, // spi fifo counter

    output reg [7:0]    status_o,           // SUCCESS when done, or an error code
    output reg          busy_o              // Module busy flag
    );

    // Main Globals
    reg [6:0]       state = 0;

// Do S4 initially
//`ifdef X7_CORE
//`else
//`endif

    /////////////////////////////////////////////////////////
    // user-programmed bias opcode parsing
    /////////////////////////////////////////////////////////
    reg [3:0]       channel;            // 1-16 minus 1
    reg             on_off;             // 0=bias off, 1=bias on   

    /////////////////////////////////
    // Set Bias state definitions //
    /////////////////////////////////
    `define BIAS_IDLE            0
    `define BIAS_READ            1
    
    ////////////////////////////////////////
    // End of bias state definitions //
    ////////////////////////////////////////

`ifdef XILINX_SIMULATOR
    integer         filebias = 0;
    reg [7:0]       dbgdata;
`endif

    always @( posedge clk)
    begin
        if( rst )
        begin
            state <= `BIAS_IDLE;
            bias_fifo_rd_en_o <= 1'b0;
            on_off <= 1'b0;
            channel <= 4'b0000;
        end
        else if(bias_en == 1)
        begin
            case(state)
            `BIAS_IDLE: begin
                if(!bias_fifo_empty_i) begin
                    bias_fifo_rd_en_o <= 1;   // read next value
                    state <= `BIAS_READ;
                    busy_o <= 1'b1;
                end
                    busy_o <= 1'b0;
            end             
            `BIAS_READ: begin
                // read bias data from fifo
                on_off <= bias_fifo_i;
                bias_fifo_rd_en_o <= 0;
                state <= `BIAS_IDLE;
            `ifdef XILINX_SIMULATOR
                if(filebias == 0)
                    filebias = $fopen("../../../project_1.srcs/sources_1/bias_in.txt", "a");
                $fdisplay (filebias, "Bias:0x%h", bias_fifo_i);
                if(bias_fifo_empty_i) begin
                    $fclose(filebias);
                    filebias = 0;
                end
            `endif
            end
            default: begin
                status_o = `ERR_UNKNOWN_BIAS_STATE;
                state = `BIAS_IDLE;
            end
            endcase
        end
    end    
endmodule
