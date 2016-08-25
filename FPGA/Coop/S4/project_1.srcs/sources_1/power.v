//////////////////////////////////////////////////////////////////////////////////
// Company: Ampleon
// Engineer: Rick Rigby
// 
// Create Date: 07/19/2016 01:38:49 PM
// Design Name: S4, X7 opcode processor core
// Module Name: power
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments: Implement power calculations. S4 will be similar to the M2
//                      Created for S4 initially
// 
//////////////////////////////////////////////////////////////////////////////////

`include "timescale.v"
`include "version.v"

`include "status.h"
`include "opcodes.h"
`include "queue_spi.h"

module power(
    input               clk,
    input               rst,
    
    input               power_en,
    input               spi_processor_idle, // Only queue SPI data when it's idle

    input               x7_mode,            // S4 is a limited version of X7, true if X7, false=S4
    input               high_speed_syn,     // synthesiser mode, true=high speed syn mode, false=high accuracy mode

    // Power opcode(s) are in input fifo
    // Power opcode byte 0 is channel#,
    // byte 1 unused, byte 2 is 8 lsb's,
    // byte 3 is 8 msb's of Q7.8 format power
    // in dBm. (Positive values only)
    input [31:0]        power_fifo_i,        // power fifo
    output reg          power_fifo_rd_en_o,  // fifo read line
    input               power_fifo_empty_i,  // fifo empty flag
    input [15:0]        power_fifo_count_i,  // fifo count, for debug message only

    // SPI data is written to dual-clock fifo, then SPI write request is queued.
    // spi_processor_idle is asserted when write is finished by top level.
    output reg [7:0]    spi_o,              // spi fifo data
    output reg          spi_wr_en_o,        // spi fifo write enable
    input               spi_fifo_empty_i,   // spi fifo empty flag
    input               spi_fifo_full_i,    // spi fifo full flag
    input               spi_wr_ack_i,       // spi fifo write acknowledge

    // The fifo to request an SPI write from the top level
    output reg [7:0]    spiwr_queue_data_o,       // queue request for write
    output reg          spiwr_queue_wr_en_o,      // spi fifo write enable
    input               spiwr_queue_fifo_empty_i, // spi fifo empty flag
    input               spiwr_queue_fifo_full_i,  // spi fifo full flag
    input               spiwr_queue_wr_ack_i,     // fifo write acknowledge

    output reg [7:0]    status_o,           // SUCCESS when done, or an error code
    output reg          busy_o              // Module busy flag
    );

    // Main Globals
    reg [6:0]       state = 0;
    reg [6:0]       next_state;         // saved while waiting for multiply/divide in FRQ_WAIT state
    reg [6:0]       next_spiwr_state;   // saved while waiting for SPI writes to finish before next request

    reg [31:0]      power = 0;      
    // Latency for math operations, Xilinx multiplier & divrem divider have no reliable "done" line???
    `define MULTIPLIER_CLOCKS 4
    `define DIVIDER_CLOCKS 42
    reg [5:0]       latency_counter;    // wait for multiplier & divider 
    reg [3:0]       byte_idx;           // countdown when writing bytes to fifo
    reg [5:0]       shift;              // up to 63 bits

    // Xilinx multiplier.
    // A input is 56 bits. B input is 24 bits
    // Output is 64 bits
    reg [55:0] multA;                   // A multiplier input
    reg [23:0] multB;                   // B multiplier input
    wire [63:0] multiplier_result;      // Result
    mult48 ddsMultiply (
       .CLK(clk),
       .A(multA),
       .B(multB),
       .CE(power_en),
       .P(multiplier_result)
     );      
    
    // Instantiate simple division ip for division not
    // requiring remainder.
    // Use 32-bit divider to convert programmed frequency 
    // in Hertz to MHz, other calculations for limits, etc
    parameter WIDTH_FR = 32;
    reg  [31:0] divisor;             // always 1MHz here
    reg  [31:0] dividend;            // frequency in Hertz
    wire [31:0] quotient;            // MHz
    wire        divide_done;         // Division done
    reg         div_enable;          // Divider enable
    division #(WIDTH_FR) divnorem (
        .enable(div_enable),
        .A(dividend), 
        .B(divisor), 
        .result(quotient),
        .done(divide_done)
    );

    /////////////////////////////////////////////////////////
    // user-programmed power, power table, corresponding 
    // magnitude table, etc.
    /////////////////////////////////////////////////////////
    reg [3:0]       channel;            // 1-16 minus 1
    reg [15:0]      dbmx10;             // ((desired dBm - (40*256)) * 10) / 256 (xx.x dBm * 10, an integer)   
    localparam      dbm_offset = 16'd10240;     // Offset is 40dBm, 40*256 will be subtracted from user programmed Q7.8 value 
    localparam      pwr_table_size = 8'd21;
    // Note: array indexing reverse order from C
    reg [7:0]       power_table [20:0] = {8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 
                                            8'h0f, 8'h1e, 8'h2d, 8'h3c, 
                                            8'h4b, 8'h5a, 8'h69, 8'h78,
                                            8'h87, 8'h96, 8'ha5, 8'hb4, 
                                            8'hc3, 8'hd2, 8'he1, 8'hf0  };
    reg [5:0]       table_index;
    reg [15:0]      mag_table [20:0] = { 16'h20, 16'h28, 16'h30, 16'h38,
                                        16'h40, 16'h50, 16'h60, 16'h70, 16'h80,
                                        16'ha0, 16'hc0, 16'he0, 16'h100,
                                        16'h140, 16'h180, 16'h1c0, 16'h200,
                                        16'h280, 16'h300, 16'h380, 16'h400 };
    reg [7:0]       numerator;
    reg [15:0]      denominator;
    reg [15:0]      mag_step;
    reg [15:0]      mag_data;       // interpolated mag_table value for hardware
    `define PWR_BYTES       2

    /*
        LTC6946fb output power
        RFO[1:0]=0, -9.7 to -6dBm
        ....
        RFO[1:0]=3, -1.2 to 2.3dBm
    
    */

    /////////////////////////////////
    // Set Power state definitions //
    /////////////////////////////////
    `define PWR_IDLE            0
    `define PWR_READ            1
    `define PWR_INTERNAL_DBM1   2   // ((user dBm - (40*256)) * 10) / 256 (xx.x dBm * 10, an integer)
    `define PWR_INTERNAL_DBM2   3
    `define PWR_INIT_LOOP       4
    `define PWR_LOOP_TOP        5
    `define PWR_MULT            6
    `define PWR_DIVIDE          7
    `define PWR_DIV_WAIT        8
    
    `define PWR_SPIWRDATA_WAIT      40  // Dual clock fifo needs an extra clock at begin & end
    `define PWR_SPIWRDATA_FINISH    41
    `define PWR_SPIWRQUE_WAIT       42
    `define PWR_SPIWRQUE_FINISH     43
    `define PWR_SPI_PROC_WAIT       44  // Wait for SPI processor to finish
    
    // done calculations, queuing data for SPI states
    `define PWR_QUEUE               60
    `define PWR_QUEUE_CMD           61

    // Waiting for multiply/divide state, 7 bits available 
    `define PWR_WAIT                127
    ////////////////////////////////////////
    // End of power state definitions //
    ////////////////////////////////////////

`ifdef XILINX_SIMULATOR
    integer         filepwr = 0;
    reg [7:0]       dbgdata;
`endif

    always @( posedge clk)
    begin
        if( rst )
        begin
            state <= `PWR_IDLE;
            next_state <= `PWR_IDLE;
            next_spiwr_state <= `PWR_IDLE;            
            power_fifo_rd_en_o <= 1'b0;
            power <= 32'h00000000;
            latency_counter <= 6'b000000; 
            channel <= 4'b0000;
            dbmx10 <= 16'h0000;   
            table_index <= 6'b000000;
            numerator <= 8'h00;
            denominator <= 16'h0001;
            mag_step <= 16'h0000;
            mag_data <= 16'h0000;
        end
        else if(power_en == 1)
        begin
            case(state)
            `PWR_WAIT: begin
                if(latency_counter == 0)
                    state <= next_state;
                else
                    latency_counter <= latency_counter - 1;
            end
            // Wait for SPI processor to finish before
            // starting next SPI request
            `PWR_SPI_PROC_WAIT: begin
                if(spi_processor_idle) begin
                    state <= next_spiwr_state;
                end
            end
            `PWR_SPIWRDATA_WAIT: begin
                // Write ACK takes one extra clock at the beginning & end
                if(spi_wr_ack_i == 1)
                    state <= next_state;
            end
            `PWR_SPIWRDATA_FINISH: begin
                // need to wait for spi_fifo_empty_i flag to go OFF
                // when it does, queue the SPI write command
                if(!spi_fifo_empty_i)
                    state <= next_state;
            end
            `PWR_SPIWRQUE_WAIT: begin
                // Write ACK takes one extra clock at the beginning & end
                // need to wait for spiwr_queue_fifo_empty_i flag to go OFF
                if(spiwr_queue_wr_en_o && spiwr_queue_wr_ack_i)
                    spiwr_queue_wr_en_o <= 0;
                if(!spiwr_queue_fifo_empty_i)
                    state <= next_state;
            end
            `PWR_IDLE: begin
                if(!power_fifo_empty_i) begin
                    power_fifo_rd_en_o <= 1;   // read next value
                    state <= `PWR_READ;
                    busy_o <= 1'b1;
                end
                else
                    busy_o <= 1'b0;
            end             
            `PWR_READ: begin
                // read power from fifo
                power <= power_fifo_i;
                power_fifo_rd_en_o <= 0;
                state <= `PWR_INTERNAL_DBM1;
            `ifdef XILINX_SIMULATOR
                if(filepwr == 0)
                    filepwr = $fopen("../../../project_1.srcs/sources_1/pwr_in.txt", "a");
            `endif
            end
            `PWR_INTERNAL_DBM1: begin
                multA <= power[31:16] - dbm_offset;
                multB <= 16'd10;
                latency_counter <= `MULTIPLIER_CLOCKS;
                next_state <= `PWR_INTERNAL_DBM2;
                state <= `PWR_WAIT;
            end
            `PWR_INTERNAL_DBM2: begin
                dbmx10 <= multiplier_result >> 8; 
                state <= `PWR_INIT_LOOP;
            end
            `PWR_INIT_LOOP: begin
                table_index <= 0;
                state <= `PWR_LOOP_TOP;
            `ifdef XILINX_SIMULATOR
                $fdisplay (filepwr, "Power(Q8.7):0x%h, dbmx10:%d", power, dbmx10);
            `endif
            end
            `PWR_LOOP_TOP: begin
                if(dbmx10 > power_table[table_index]) begin
                    numerator <= dbmx10 - power_table[table_index];
                    // Verilog "static array" indexing is in reverse order
                    denominator <= power_table[table_index - 1] - power_table[table_index];
                    mag_step <= mag_table[table_index - 1] - mag_table[table_index];
                    state <= `PWR_MULT;
                end
                else begin
                    if(table_index < pwr_table_size - 1) begin 
                        table_index <= table_index + 1;
                    end
                    else begin
                        status_o <= `ERR_POWER_INVALID;
                        state <= `PWR_IDLE;
                    end
                end
            end
            `PWR_MULT: begin
                multA <= mag_step;
                multB <= numerator;
                latency_counter <= `MULTIPLIER_CLOCKS;
                next_state <= `PWR_DIVIDE;
                state <= `PWR_WAIT;
            end
            `PWR_DIVIDE: begin
                dividend <= multiplier_result;
                divisor <= denominator;
                div_enable <= 1;
                state <= `PWR_DIV_WAIT;            // Wait for result
            end
            `PWR_DIV_WAIT: begin
                if(divide_done) begin
                    mag_data <= quotient[15:0] + mag_table[table_index];
                    div_enable <= 0;
                    state <= `PWR_IDLE;
//                    byte_idx <= `PWR_BYTES;
//                    state <= `PWR_QUEUE;
                end
            end
            `PWR_QUEUE: begin
                //
                // Queue calculated bytes for SPI write
                //
                // When queueing has finished, byte_idx will be 0,
                // waiting for top level to write DDS at this point,
                // When SPI write is finished, go back to idle
                if(byte_idx == 0) begin
                    // wait in this state (PWR_QUEUE, byte_idx=0) until SPI fifo is empty (write has finished)
                    if(spi_processor_idle) begin
                        // done with write SPI, continue calculations if necessary
                        state = `PWR_IDLE;  // Done
                        status_o = `SUCCESS;
                    end
                end
                else begin
                    byte_idx = byte_idx - 1;
                    if(byte_idx == 0) begin
                        // Data bytes are in SPI fifo at top level, queue request to write.
                        // But first, wait for fifo_empty to turn OFF
                        spi_wr_en_o <= 0;   // Turn OFF writes!
                        next_state <= `PWR_QUEUE_CMD;  // after fifo empty turns OFF
                        state <= `PWR_SPIWRDATA_FINISH;
                    end
                    else begin
                        shift = (`PWR_BYTES - byte_idx) << 3;
                        spi_wr_en_o <= 1;       // Enable writes, SPI processor is not busy
                        spi_o <= (mag_data >> shift);
                        next_state <= `PWR_QUEUE_CMD;
                        state <= `PWR_SPIWRDATA_WAIT;
                    `ifdef XILINX_SIMULATOR
                        dbgdata = (mag_data >> shift);
                        $fdisplay (filepwr, "%02h", dbgdata);
                    `endif
                    end
                end
            end
            `PWR_QUEUE_CMD: begin
                // SPI data written to fifo, fifo empty OFF, write SPI processor request
                spiwr_queue_data_o <= `SPI_PWR;     // queue request for Power write
                spiwr_queue_wr_en_o <= 1;           // spi queue fifo write enable
                next_state <= `PWR_QUEUE;           // after queueing cmd, wait in PWR_QUEUE state
                state <= `PWR_SPIWRQUE_WAIT;
            `ifdef XILINX_SIMULATOR
                $fdisplay (filepwr, "  ");   // spacer line
                //$fdisplay (filepwr, "Done with power %d\n", power);
                $fclose (filepwr);
                filepwr = 0;
            `endif
            end
            default:
                begin
                    status_o = `ERR_UNKNOWN_PWR_STATE;
                    state = `PWR_IDLE;
                end
            endcase
        end
    end    
endmodule
