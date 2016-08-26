//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/28/2016 06:13:10 PM
// Design Name: 
// Module Name: opcodes
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 01-Aug-2016  The FIFO we're using takes an extra clock after asserting rd_en before the data is ready.
//              Also takes an extra clock after un-asserting rd_en to stop reading.
// 
//////////////////////////////////////////////////////////////////////////////////

`include "timescale.v"
`include "version.v"

`include "status.h"
`include "opcodes.h"

`define BUF_WIDTH 9    // BUF_SIZE = 16 -> BUF_WIDTH = 4, no. of bits to be used in pointer
`define BUF_SIZE ( 1<<`BUF_WIDTH )

`define STATE_IDLE                  7'h01
`define STATE_FETCH_WAIT            7'h02   // 1 extra clock after assert rd_en   
`define STATE_FETCH                 7'h03
`define STATE_LENGTH                7'h04
`define STATE_DATA                  7'h05
`define STATE_FIFO_WRITE            7'h06
`define STATE_DATA_WR_MULTIBYTE     7'h07

/*
    Opcode block MUST be terminated by a NULL opcode
*/
module opcodes(
    input clk,
    input rst,
    input ce,

    input [7:0] opcode_fifo_i,      // opcode fifo
    output reg rd_en_o,             // fifo read line
    input fifo_empty_i,             // fifo empty flag
    input [9:0] opcode_fifo_count_i,  // opcode fifo counter

    input [15:0] system_state_i,    // overall state of system, "running a pattern", for example

    output reg [7:0] response_o,    // to fifo, response bytes(status, measurements, echo, etc)
    output reg response_wr_en_o,    // response fifo write enable
    input response_fifo_empty_i,    // response fifo empty flag
    input response_fifo_full_i,     // response fifo full flag
    output reg response_ready_o,    // response is waiting

    output reg [31:0] frequency_o,  // to fifo, frequency output in MHz
    output reg frq_wr_en_o,         // frequency fifo write enable
    input frq_fifo_empty_i,         // frequency fifo empty flag
    input frq_fifo_full_i,          // frequency fifo full flag

    output reg [31:0] power_o,      // to fifo, power output in dBm
    output reg pwr_wr_en_o,         // power fifo write enable
    input pwr_fifo_empty_i,         // power fifo empty flag
    input pwr_fifo_full_i,          // power fifo full flag

// phase is X7 only, do later
//    output reg [15:0] phase_o,      // to fifo, phase output in degrees
//    output reg phs_wr_en_o,         // phase fifo write enable
//    input phs_fifo_empty_i,         // phase fifo empty flag
//    input phs_fifo_full_i,          // phase fifo full flag

    output reg [63:0] pulse_o,          // to fifo, pulse opcode
    output reg pulse_wr_en_o,           // pulse fifo write enable
    input pulse_fifo_empty_i,           // pulse fifo empty flag
    input pulse_fifo_full_i,            // pulse fifo full flag

    output reg [15:0] bias_o,           // to fifo, bias opcode
    output reg bias_wr_en_o,           // bias fifo write enable
    input bias_fifo_empty_i,           // bias fifo empty flag
    input bias_fifo_full_i,            // bias fifo full flag

    // save the last programmed values for use when processing pulse opcodes
    output [7:0] last_power0,
    output [7:0] last_power1,
    output [7:0] last_power2,
    output [7:0] last_power3,
    output [7:0] last_power4,
    output [7:0] last_power5,
    output [7:0] last_frequency0,
    output [7:0] last_frequency1,
    output [7:0] last_frequency2,
    output [7:0] last_frequency3,
    output [7:0] last_frequency4,
    output [7:0] last_frequency5,
    output [7:0] last_bias0,
    output [7:0] last_bias1,
    output [7:0] last_bias2,
    output [7:0] last_bias3,
    output [7:0] last_bias4,
    output [7:0] last_bias5,

    output reg [31:0] opcode_counter_o,     // count opcodes for status info                     
    output reg [7:0]  status_o,             // NULL opcode terminates, done=0, or error code
    output reg        busy_o
    );

`ifdef XILINX_SIMULATOR
    integer         fileopcode = 0;
    integer         filefreqs = 0;
    integer         filepwr = 0;
    integer         filepulse = 0;
    integer         filebias = 0;
    integer         fileopcerr = 0;
    reg [7:0]       dbgdata;
`endif

    reg [6:0]   state = 0;
    reg [6:0]   opcode = 0;         // Opcode being processed
    reg [9:0]   length = 0;         // bytes of opcode data to read
    reg [63:0]  uinttmp;            // up to 64-bit tmp for opcode data
    reg         len_upr = 0;        // Persist upper bit of length
    reg [9:0]   data_length;        // Save opcode data length
    
    // handle opcode data in a common way
    reg [31:0]  shift = 0;              // tmp used building opcode data

    // save last programmed values for use when processing pulse opcodes
    reg [7:0]   last_power [5:0];       // 4 bytes plus 2 for opcode & length
    reg [7:0]   last_frequency [5:0];   // ditto
    reg [7:0]   last_bias   [5:0];      // ditto
    // write saved values to registers next level up
    assign last_power0 = last_power[0];
    assign last_power1 = last_power[1];
    assign last_power2 = last_power[2];
    assign last_power3 = last_power[3];
    assign last_power4 = last_power[4];
    assign last_power5 = last_power[5];
    assign last_frequency0 = last_frequency[0];
    assign last_frequency1 = last_frequency[1];
    assign last_frequency2 = last_frequency[2];
    assign last_frequency3 = last_frequency[3];
    assign last_frequency4 = last_frequency[4];
    assign last_frequency5 = last_frequency[5];
    assign last_bias0 = last_bias[0];
    assign last_bias1 = last_bias[1];
    assign last_bias2 = last_bias[2];
    assign last_bias3 = last_bias[3];
    assign last_bias4 = last_bias[4];
    assign last_bias5 = last_bias[5];

    // flag for each opcode, argument data is a block of bytes(1) or an integer(0)
    // Xilinx Verilog is MS data 1st, LS data last. Opcode 0 will be last entry
    // So far only PTN_DATA and ECHO use a block of bytes as arg data
    reg arg_is_bytes [127:0] = 
    {1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0,
     1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0,
     1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 
     1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 
     1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 
     1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 
     1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 
     1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0};    
//   0..., DBG_READREG, DBG_MBWSPI, DBG_MSYNSPI, DBG_RSYNSPI, DBG_DDSSPI, DBG_FLASHSPI, DBG_IQDATA, DBG_IQSPI, DBG_IQCTRL, DBG_OPCTRL, DBG_LEVELSPI, DBG_ATTENSPI
//   0..., MEAS_ZMCTL, MEAS_ZMSIZE
//   0,0,0,0,0,0,0,0,0,0,0,0, PTN_DATA, PTN_PATCTL, PTN_PATADR, PTN_PATCLK
//   0, 0, 0, ECHO, PAINTFCFG, SYNCCONF, TRIGCONF, LENGTH, MODE, BIAS, PULSE, PHASE, POWER, FREQ, STATUS, TERMINATOR

    always @( posedge clk) begin
        if( rst ) begin //|| (state != `STATE_IDLE && fifo_empty_i == 1))
            opcode <= 0;
            len_upr <= 0;
            length <= 9'b000000000;
            data_length <= 9'b000000000;
            rd_en_o <= 1'b0; // Added by John Clayton
            frq_wr_en_o <= 1'b0;
            pwr_wr_en_o <= 1'b0;
            pulse_wr_en_o <= 1'b0;
            bias_wr_en_o <= 1'b0;
            opcode_counter_o <= 0;
            uinttmp <= 64'h0000_0000_0000_0000;
            response_wr_en_o <= 1'b0;
            response_ready_o <= 1'b0;
            busy_o <= 1'b0;
            status_o <= 8'h00;
            state <= `STATE_IDLE;                     

            last_power[0] <= 0;
            last_power[1] <= 0;
            last_power[2] <= 0;
            last_power[3] <= 0;
            last_power[4] <= 0;
            last_power[5] <= 0;
            last_frequency[0] <= 0;
            last_frequency[1] <= 0;
            last_frequency[2] <= 0;
            last_frequency[3] <= 0;
            last_frequency[4] <= 0;
            last_frequency[5] <= 0;
            last_bias[0] <= 0;
            last_bias[1] <= 0;
            last_bias[2] <= 0;
            last_bias[3] <= 0;
            last_bias[4] <= 0;
            last_bias[5] <= 0;
        end
        else if(ce == 1) begin
            case(state)
            `STATE_IDLE: begin
                if(status_o <= `SUCCESS) begin  // Don't continue when status is ERR
                    if(!fifo_empty_i) begin 
                        rd_en_o <= 1;
                        status_o <= 0;
                        opcode <= 0;
                        len_upr <= 0;
                        length <= 9'b000000000;
                        data_length <= 9'b000000000;
                        uinttmp <= 64'h0000_0000_0000_0000;
                        busy_o <= 1'b1;
                        
                        frq_wr_en_o <= 1'b0;
                        pwr_wr_en_o <= 1'b0;
                        pulse_wr_en_o <= 1'b0;
                        bias_wr_en_o <= 1'b0;
                        response_wr_en_o <= 1'b0;
                        //response_ready_o <= 1'b0;   ??Reset after response has been read
                        
                        state <= `STATE_FETCH_WAIT;
                    end
                    else
                        busy_o <= 1'b0;
                end
            end
            `STATE_FETCH_WAIT: begin
                length <= opcode_fifo_i;
                state <= `STATE_FETCH;
            end
            `STATE_FETCH: begin
                shift <= 8'h00;
                uinttmp <= 64'h0000_0000_0000_0000;
                length <= opcode_fifo_i;
                state <= `STATE_LENGTH;  // Part 1 of length, get length msb & get opcode next
            end
            `STATE_LENGTH: begin
                length <= length | ((opcode_fifo_i & 1) << 8);
                data_length <= 0;
                opcode <= (opcode_fifo_i & 8'hFE) >> 1;
                state <= `STATE_DATA;  // got opcode, start reading data
                `ifdef XILINX_SIMULATOR
                    if(fileopcode == 0)
                        fileopcode = $fopen("../../../project_1.srcs/sources_1/opc_from_fifo.txt", "a");
                    $fdisplay (fileopcode, "%02h, length:%d", (opcode_fifo_i & 8'hFE) >> 1, length);
                `endif
            end
            `STATE_DATA: begin
            // Gather opcode data payload
            // Most opcodes will use the same code here, just different number of bytes.
                if(opcode == 0) begin
                `ifdef XILINX_SIMULATOR
                    $fdisplay (fileopcode, "Terminated on 0, count:%d", opcode_counter_o);
                    $fclose(fileopcode);
                    fileopcode = 0;
                    $fclose(filefreqs);
                    filefreqs = 0;
                    $fclose(filepwr);
                    filepwr = 0;
                    $fclose(filepulse);
                    filepulse = 0;
                    $fclose(filebias);
                    filebias = 0;
                    $fclose(fileopcerr);
                    fileopcerr = 0;
                `endif
                    rd_en_o <= 0;   // Disable read fifo
                    status_o <= `SUCCESS;
                    busy_o <= 1'b0;             
                    state <= `STATE_IDLE;
                end
                
                if(data_length == 0)
                    data_length <= length;  // Save length for later processing.

                if(!arg_is_bytes[opcode[6:0]]) begin    // Opcode with integer argument
                    // common processsing...
                    if(length == 0) begin   // write to correct fifo
                        case(opcode)
                        `STATUS:  begin
                        end
                        `FREQ: begin
                            frequency_o <= uinttmp[31:0];
                            frq_wr_en_o <= 1;   // enable write frequency FIFO
                            // Don't process anymore opcodes until fifo is written
                            state <= `STATE_FIFO_WRITE;                                    
                        `ifdef XILINX_SIMULATOR
                            if(filefreqs == 0)
                                filefreqs = $fopen("../../../project_1.srcs/sources_1/opcode_freqs_to_fifo.txt", "a");
                            $fdisplay (filefreqs, "Wrote %d Hz to freq processor fifo", uinttmp[31:0]);
                        `endif
                        end
                        `POWER: begin
                            power_o <= uinttmp[31:0];
                            pwr_wr_en_o <= 1;   // enable write power FIFO
                            // Don't process anymore opcodes until fifo is written
                            state <= `STATE_FIFO_WRITE;                                    
                        `ifdef XILINX_SIMULATOR
                            if(filepwr == 0)
                                filepwr = $fopen("../../../project_1.srcs/sources_1/opcode_pwr_to_fifo.txt", "a");
                            $fdisplay (filepwr, "Wrote 0x%h to power processor fifo", uinttmp[31:0]);
                        `endif
                        end
        //                        `PHASE:
        //                            begin
        //                            end
                        `PULSE: begin
                            pulse_o <= uinttmp[63:0];
                            pulse_wr_en_o <= 1;   // enable write ulse FIFO
                            // Don't process anymore opcodes until fifo is written
                            state <= `STATE_FIFO_WRITE;                                    
                        `ifdef XILINX_SIMULATOR
                            if(filepulse == 0)
                                filepulse = $fopen("../../../project_1.srcs/sources_1/opcode_pulse_to_fifo.txt", "a");
                            $fdisplay (filepulse, "Wrote 0x%h to pulse processor fifo", uinttmp[63:0]);
                        `endif
                        end
                        `BIAS: begin
                            bias_o <= uinttmp[15:0];
                            bias_wr_en_o <= 1;   // enable write ulse FIFO
                            // Don't process anymore opcodes until fifo is written
                            state <= `STATE_FIFO_WRITE;                                    
                        `ifdef XILINX_SIMULATOR
                            if(filebias == 0)
                                filebias = $fopen("../../../project_1.srcs/sources_1/opcode_bias_to_fifo.txt", "a");
                            $fdisplay (filebias, "Wrote 0x%h to bias processor fifo", uinttmp[15:0]);
                        `endif
                        end
        //                        `TRIGCONF:
        //                            begin
        //                            end
        //                        `SYNCCONF:
        //                            begin
        //                            end
        //                        `PAINTFCFG:
        //                            begin
        //                            end
    //                        `PTN_PATCLK:
        //                            begin
        //                            end
        //                        `PTN_PATADR:
        //                            begin
        //                            end
        //                        `PTN_PATCTL:
        //                            begin
        //                            end
        //                        `PTN_DATA:
        //                            begin
        //                            end
        //                        `MEAS_ZMSIZE:
        //                            begin
        //                            end
        //                        `MEAS_ZMCTL:
        //                            begin
        //                            end
        //                        `DBG_ATTENSPI:
        //                            begin
        //                            end
        //                        `DBG_LEVELSPI:
        //                            begin
        //                            end
        //                        `DBG_OPCTRL:
        //                            begin
        //                            end
        //                        `DBG_IQCTRL:
        //                            begin
        //                            end
        //                        `DBG_IQSPI:
        //                            begin
        //                            end
        //                        `DBG_IQDATA:
        //                            begin
        //                            end
        //                        `DBG_FLASHSPI:
        //                            begin
        //                            end
        //                        `DBG_DDSSPI:
        //                            begin
        //                            end
        //                        `DBG_RSYNSPI:
        //                            begin
        //                            end
        //                        `DBG_MSYNSPI:
        //                            begin
        //                            end
        //                        `DBG_MBWSPI:
        //                            begin
        //                            end
        //                        `DBG_READREG:
        //                            begin
        //                            end
                        default: begin
                            status_o <= `ERR_INVALID_OPCODE;
                            state <= `STATE_IDLE;
                        end
                        endcase
                    end // if(length == 0) block
                    else begin  // integer argument, 2 to 8 bytes in length
                        uinttmp <= uinttmp | (opcode_fifo_i << shift);
                        if(length == 2)         // Turn OFF with 1 clock left. 1=last read, 0=begin write fifo
                            rd_en_o <= 0;       // disable opcode fifo reads
                        length <= length - 1;
                        shift <= shift + 8'd8;
                    end
                end
                else begin  // if(arg_is_bytes[opcode[6:0]]) 
                    // argument data is a block of bytes, save it
                    // Normally pattern data, can be debug or echo opcodes
                    // Pattern data is not valid when a pattern is running (opcodes w/integer args are valid)
                    if(system_state_i & `STATE_PTN_BUSY) begin
                    `ifdef XILINX_SIMULATOR
                        if(fileopcerr == 0)
                            fileopcerr = $fopen("../../../project_1.srcs/sources_1/opcode_status.txt", "a");
                        $fdisplay (fileopcerr, "*ERROR*:Cannot write pattern data while pattern is running");
                    `endif
                        status_o <= `ERR_PATTERN_RUNNING;
                        state <= `STATE_IDLE;
                    end
                    else begin
                        case(opcode)
                        `ECHO: begin
                            if(response_fifo_full_i) begin
                            `ifdef XILINX_SIMULATOR
                                if(fileopcerr == 0)
                                    fileopcerr = $fopen("../../../project_1.srcs/sources_1/opcode_status.txt", "a");
                                $fdisplay (fileopcerr, "*ERROR*:Response fifo is full, ECHO can't write response");
                                $fclose(fileopcerr);
                                fileopcerr = 0;
                            `endif
                                response_ready_o <= 1'b0;
                                status_o <= `ERR_RSP_FIFO_FULL;
                                state <= `STATE_IDLE;
                            end
                            else begin
                                response_o <= ~opcode_fifo_i;       // complement the data for echo test
                                response_wr_en_o <= 1;
                                rd_en_o <= 0;                       // turn off reading while waiting for write
                                length <= length - 1;
                                state <= `STATE_DATA_WR_MULTIBYTE;  // wait for write of byte to output memory
                                if(length == 0) begin
                                    response_ready_o <= 1'b1;
                                    state <= `STATE_IDLE;           // next opcode
                                end
                                else if(response_ready_o == 1'b1)
                                    response_ready_o <= 1'b0;
                            end
                         end
                        `PTN_DATA: begin
                        end
                        endcase
                    end    
                end
            end
            `STATE_FIFO_WRITE:
            begin
                // Don't process anymore opcodes until fifo is written
                frq_wr_en_o <= 0;   // All off until next opcode ready
                pwr_wr_en_o <= 0;
                pulse_wr_en_o <= 0;
                bias_wr_en_o <= 0;
           `ifdef XILINX_SIMULATOR
                if(fifo_empty_i) begin
                    $fdisplay (fileopcode, "Done processing opcodes, count:%d", opcode_counter_o);
                    $fclose(fileopcode);
                    fileopcode = 0;
                    $fclose(filefreqs);
                    filefreqs = 0;
                    $fclose(filepwr);
                    filepwr = 0;
                    $fclose(filepulse);
                    filepulse = 0;
                    $fclose(filebias);
                    filebias = 0;
                    $fclose(fileopcerr);
                    fileopcerr = 0;
                end
           `endif
                busy_o <= 1'b0;
                state <= `STATE_IDLE;
                // Count opcode
                opcode_counter_o <= opcode_counter_o + 1;                     
            end
            `STATE_DATA_WR_MULTIBYTE: begin     // turn OFF write, continue multibyte data read
                response_wr_en_o <= 0;          // write OFF
                rd_en_o <= 1;                   // read next byte ON
                state <= `STATE_DATA;
            end
            default:
            begin
                status_o = `ERR_INVALID_STATE;
                busy_o <= 1'b0;
                state <= `STATE_IDLE;
            end
            endcase;    // main state machine case
        end // if(ce == 1) block
    end // always block    
endmodule
