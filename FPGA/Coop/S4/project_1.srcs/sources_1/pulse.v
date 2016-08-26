//////////////////////////////////////////////////////////////////////////////////
// Company: Ampleon
// Engineer: Rick Rigby
// 
// Create Date: 08/03/2016 02:22:58 PM
// Design Name: 
// Module Name: pulse
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: pulse will parse the pulse opcode, create a pattern,
//              and run it once.
//      Pulse opcode has width of pulse in 100ns ticks and
//      optionally a measurement flag and measurement offset.
//      Calculate how many clock ticks these intervals are and then
//      loads the pattern RAM with entries. Generic pattern entries
//      will be 16 bits. 
//          d0 will be 1 for ON & 0 for OFF.
//          d1 will be 1 for measurement, 0 for no measurement
//          measurements will be stored in a corresponding
//          measurement RAM. 16 lsb's will be forward power,
//          16 msb's will be reflected power. 
//
//  This module will instantiate and run the pattern processor, 
//  which is just a 'special' version of the opcode processor.
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
`include "patterns.h"

module pulse(
    input               clk,
    input               rst,
    
    input               pulse_en,

    input               x7_mode,            // S4 is a limited version of X7, true if X7, false=S4
    input               high_speed_syn,     // synthesiser mode, true=high speed syn mode, false=high accuracy mode

    // use the last programmed values when processing pulse opcodes
    // pass in 6 bytes without using array
    input  [7:0]       last_power0,
    input  [7:0]       last_power1,
    input  [7:0]       last_power2,
    input  [7:0]       last_power3,
    input  [7:0]       last_power4,
    input  [7:0]       last_power5,
    input  [7:0]       last_frequency0,
    input  [7:0]       last_frequency1,
    input  [7:0]       last_frequency2,
    input  [7:0]       last_frequency3,
    input  [7:0]       last_frequency4,
    input  [7:0]       last_frequency5,
    input  [7:0]       last_bias0,
    input  [7:0]       last_bias1,
    input  [7:0]       last_bias2,
    input  [7:0]       last_bias3,

    // Pulse opcode(s) are in input fifo
    input [63:0]        pulse_fifo_i,        // pulse fifo
    output reg          pulse_fifo_rd_en_o,  // fifo read line
    input               pulse_fifo_empty_i,  // fifo empty flag
    input [15:0]        pulse_fifo_count_i,  // fifo count, for debug message only

    // **Pulse will generate a pattern and run it, rather than write SPI bytes**
    output reg          pattern_ram_wr_en,
    output reg [23:0]   pattern_ram_addr, 
    output reg [15:0]   pattern_ram_data_in,
    output     [23:0]   pattern_ram_count_o, 

    output reg          request_run_pattern,
    input               pattern_running,

    output [31:0]       ptn_opcodes_processed_o,
    output reg [7:0]    status_o,               // SUCCESS when done, or an error code
    output reg          busy_o
    );

    // Main Globals
//    `define         TICKS_PER_PTN_CLK   5   // 5 50MHz ticks per 100ns pattern tick.
    reg [6:0]       state = 0;
    reg [6:0]       next_state;         // saved while waiting

    reg [63:0]      pulse = 64'h0000_0000_0000_0000;      

// Do S4 initially
//`ifdef X7_CORE
//`else
//`endif

//    //////////////////////////////////////////////////////////////////
//    // Instantiate fifo's used by pattern opcode processor
//    //////////////////////////////////////////////////////////////////

//    // fifo's want low-true reset
//    wire rst_n;
//    assign rst_n = ~rst;

//    ///////////////////////////////////////////////////////////////////////
//    // Frequency FIFO
//    // variables for frequency FIFO, written by pattern processor, 
//    // read by pattern frequency processor instance
//    ///////////////////////////////////////////////////////////////////////
//    wire        ptn_freq_fifo_rst_i = 0;
//    reg         ptn_freq_fifo_clk_en = 0;
//    wire        ptn_freq_fifo_wr_en;
//    wire        ptn_freq_fifo_rd_en;
//    wire [31:0] ptn_freq_fifo_data_in;
//    wire [31:0] ptn_freq_fifo_data_out;
//    wire [9:0]  ptn_freq_fifo_count;    // 512 max
//    wire        ptn_freq_fifo_empty, ptn_freq_fifo_full;
//    wire        ptn_freq_fifo_pf_full, ptn_freq_fifo_pf_flag, ptn_freq_fifo_pf_empty;
//    // Instantiate fifo that the pattern opcode processor is using to store frequencies
//    swiss_army_fifo #(
//      .USE_BRAM(1),
//      .WIDTH(32),
//      .DEPTH(128),                   // 512 byte opcode block of only freq opcodes holds 85 frequencies
//      .FILL_LEVEL_BITS(10),
//      .PF_FULL_POINT(127),
//      .PF_FLAG_POINT(64),
//      .PF_EMPTY_POINT(1)
//    ) freq_fifo(
//        .sys_rst_n(rst_n),
//        .sys_clk(clk),
//        .sys_clk_en(pulse_en),
        
//        .reset_i(ptn_freq_fifo_rst_i),
        
//        .fifo_wr_i(ptn_freq_fifo_wr_en),
//        .fifo_din(ptn_freq_fifo_data_in),
        
//        .fifo_rd_i(ptn_freq_fifo_rd_en),
//        .fifo_dout(ptn_freq_fifo_data_out),
        
//        .fifo_fill_level(ptn_freq_fifo_count),
//        .fifo_full(ptn_freq_fifo_full),
//        .fifo_empty(ptn_freq_fifo_empty),
//        .fifo_pf_full(ptn_freq_fifo_pf_full),
//        .fifo_pf_flag(ptn_freq_fifo_pf_flag),
//        .fifo_pf_empty(ptn_freq_fifo_pf_empty)           
//    );
              
//    /////////////////////////////////////////////////////////////////////////////////////
//    // Power FIFO                       
//    // Instantiate fifo that the pattern processor is using to store power opcodes
//    // Written by pattern processor, read by pattern power processor instance
//    /////////////////////////////////////////////////////////////////////////////////////
//    wire        ptn_pwr_fifo_rst_i = 0;
//    reg         ptn_pwr_fifo_clk_en = 0;
//    wire        ptn_pwr_fifo_wr_en;
//    wire        ptn_pwr_fifo_rd_en;
//    wire [31:0] ptn_pwr_fifo_data_in;
//    wire [31:0] ptn_pwr_fifo_data_out;
//    wire [15:0] ptn_pwr_fifo_count;
//    wire        ptn_pwr_fifo_empty, ptn_pwr_fifo_full;
//    wire        ptn_pwr_fifo_pf_full, ptn_pwr_fifo_pf_flag, ptn_pwr_fifo_pf_empty;
//    swiss_army_fifo #(
//      .USE_BRAM(1),
//      .WIDTH(32),
//      .DEPTH(128),                   // 512 byte opcode block of only pwr opcodes holds 85 powers
//      .FILL_LEVEL_BITS(16),
//      .PF_FULL_POINT(127),
//      .PF_FLAG_POINT(64),
//      .PF_EMPTY_POINT(1)
//    ) power_fifo(
//        .sys_rst_n(rst_n),
//        .sys_clk(clk),
//        .sys_clk_en(pulse_en),
        
//        .reset_i(ptn_pwr_fifo_rst_i),
        
//        .fifo_wr_i(ptn_pwr_fifo_wr_en),
//        .fifo_din(ptn_pwr_fifo_data_in),
        
//        .fifo_rd_i(ptn_pwr_fifo_rd_en),
//        .fifo_dout(ptn_pwr_fifo_data_out),
        
//        .fifo_fill_level(ptn_pwr_fifo_count),
//        .fifo_full(ptn_pwr_fifo_full),
//        .fifo_empty(ptn_pwr_fifo_empty),
//        .fifo_pf_full(ptn_pwr_fifo_pf_full),
//        .fifo_pf_flag(ptn_pwr_fifo_pf_flag),
//        .fifo_pf_empty(ptn_pwr_fifo_pf_empty)           
//    );

//    /////////////////////////////////////////////////////////////////////////////////////
//    // Pulse FIFO is a dummy, pulse opcodes have been unrolled into their
//    // component opcodes (power, measure) already.
//    /////////////////////////////////////////////////////////////////////////////////////
//    wire        ptn_pulse_fifo_rst_i = 0;
//    reg         ptn_pulse_fifo_clk_en = 0;
//    wire        ptn_pulse_fifo_wr_en;
//    wire        ptn_pulse_fifo_rd_en;
//    wire [63:0] ptn_pulse_fifo_data_in;
//    wire [63:0] ptn_pulse_fifo_data_out;
//    wire [15:0] ptn_pulse_fifo_count;
//    wire        ptn_pulse_fifo_empty, ptn_pulse_fifo_full;
//    wire        ptn_pulse_fifo_pf_full, ptn_pulse_fifo_pf_flag, ptn_pulse_fifo_pf_empty;
    
//    /////////////////////////////////////////////////////////////////////////////////////
//    // Bias FIFO                       
//    // Instantiate fifo that the pattern processor is using to store bias opcodes
//    // Written by pattern processor, read by pattern bias processor instance
//    /////////////////////////////////////////////////////////////////////////////////////
//    wire        ptn_bias_fifo_rst_i = 0;
//    reg         ptn_bias_fifo_clk_en = 0;
//    wire        ptn_bias_fifo_wr_en;
//    wire        ptn_bias_fifo_rd_en;
//    wire [15:0] ptn_bias_fifo_data_in;
//    wire [15:0] ptn_bias_fifo_data_out;
//    wire [9:0]  ptn_bias_fifo_count;
//    wire        ptn_bias_fifo_empty, ptn_bias_fifo_full;
//    wire        ptn_bias_fifo_pf_full, ptn_bias_fifo_pf_flag, ptn_bias_fifo_pf_empty;
//    swiss_army_fifo #(
//      .USE_BRAM(1),
//      .WIDTH(16),
//      .DEPTH(128),                   // 512 byte opcode block of only pwr opcodes holds 85 powers
//      .FILL_LEVEL_BITS(10),
//      .PF_FULL_POINT(127),
//      .PF_FLAG_POINT(64),
//      .PF_EMPTY_POINT(1)
//    ) bias_fifo(
//        .sys_rst_n(rst_n),
//        .sys_clk(clk),
//        .sys_clk_en(pulse_en),
        
//        .reset_i(ptn_bias_fifo_rst_i),
        
//        .fifo_wr_i(ptn_bias_fifo_wr_en),
//        .fifo_din(ptn_bias_fifo_data_in),
        
//        .fifo_rd_i(ptn_bias_fifo_rd_en),
//        .fifo_dout(ptn_bias_fifo_data_out),
        
//        .fifo_fill_level(ptn_bias_fifo_count),
//        .fifo_full(ptn_bias_fifo_full),
//        .fifo_empty(ptn_bias_fifo_empty),
//        .fifo_pf_full(ptn_bias_fifo_pf_full),
//        .fifo_pf_flag(ptn_bias_fifo_pf_flag),
//        .fifo_pf_empty(ptn_bias_fifo_pf_empty)           
//    );

//    //////////////////////////////////////////////
//    // Pattern opcode processor FIFO
//    // pulse & pattern opcodes will write to this FIFO
//    // Pattern processor will execute from this FIFO
//    // Assumes 32-bit opcodes, 64k of them
//    //////////////////////////////////////////////
//    wire        ptn_fifo_rst_i = 0;
//    reg         ptn_fifo_clk_en = 0;
//    reg         ptn_fifo_wr_en;
//    wire        ptn_fifo_rd_en;
//    reg [7:0]   ptn_fifo_data_in;
//    wire [7:0]  ptn_fifo_data_out;
//    wire [15:0]  ptn_fifo_count; // was 15:0    18:0
//    wire        ptn_fifo_empty, ptn_fifo_full;
//    wire        ptn_fifo_pf_full, ptn_fifo_pf_flag, ptn_fifo_pf_empty;
//    swiss_army_fifo #(
//        .USE_BRAM(1),
//        .WIDTH(8),
//        .DEPTH(32768),         // 32768 for 2**15(15:0 ptn_fifo_count)    2**18, 262144
//        .FILL_LEVEL_BITS(16),   // 1 more bit 19
//        .PF_FULL_POINT(32767),   // 32767   262143
//        .PF_FLAG_POINT(16384),   // 16384   131072
//        .PF_EMPTY_POINT(1)
//    ) ptn_opcodes(
//        .sys_rst_n(rst_n),
//        .sys_clk(clk),
//        .sys_clk_en(ptn_fifo_clk_en),
        
//        .reset_i(ptn_fifo_rst_i),
        
//        .fifo_wr_i(ptn_fifo_wr_en),
//        .fifo_din(ptn_fifo_data_in),
        
//        .fifo_rd_i(ptn_fifo_rd_en),
//        .fifo_dout(ptn_fifo_data_out),
        
//        .fifo_fill_level(ptn_fifo_count),
//        .fifo_full(ptn_fifo_full),
//        .fifo_empty(ptn_fifo_empty),
//        .fifo_pf_full(ptn_fifo_pf_full),
//        .fifo_pf_flag(ptn_fifo_pf_flag),
//        .fifo_pf_empty(ptn_fifo_pf_empty)           
//    );

//    // Instantiate the pattern  processor module, a 'special'
//    // version of the 'ordinary' opcode processor.
//    // Pattern processor will run until ending pattern
//    // clock tick.
//    // variables for input(opcode) FIFO
//    wire [31:0] ptn_opcode_counter;
//    wire        ptn_processor_busy;
//    wire [7:0]  ptn_processor_status;
//    assign ptn_opcodes_processed_o = ~ptn_opcode_counter;
//    opcodes pattern_processor(
//        .clk(clk),
//        .rst(rst),
//        .ce(1'b0),

//        .opcode_fifo_i(ptn_fifo_data_out),
//        .rd_en_o(ptn_fifo_rd_en),
//        .fifo_empty_i(ptn_fifo_empty),
//        .opcode_fifo_count_i(ptn_fifo_count),
         
//        .frequency_o(ptn_freq_fifo_data_in),        // frequency output in MHz, into FIFO
//        .frq_wr_en_o(ptn_freq_fifo_wr_en),          // freq fifo write line
//        .frq_fifo_empty_i(ptn_freq_fifo_empty),     // freq fifo empty line 
//        .frq_fifo_full_i(ptn_freq_fifo_full),       // frequency fifo full flag

//        .power_o(ptn_pwr_fifo_data_in),             // desired power output in dBm, into FIFO
//        .pwr_wr_en_o(ptn_pwr_fifo_wr_en),           // power fifo write line
//        .pwr_fifo_empty_i(ptn_pwr_fifo_empty),      // power fifo empty line 
//        .pwr_fifo_full_i(ptn_pwr_fifo_full),        // power fifo full flag

//        // pulse opcodes have already been "unrolled", should never get any when running a pattern
//        .pulse_o(ptn_pulse_fifo_data_in),           // to fifo, pulse opcode
//        .pulse_wr_en_o(ptn_pulse_fifo_wr_en),       // write pulse fifo enable
//        .pulse_fifo_empty_i(ptn_pulse_fifo_empty),  // pulse fifo empty flag
//        .pulse_fifo_full_i(ptn_pulse_fifo_full),    // pulse fifo full flag

//        .bias_o(ptn_bias_fifo_data_in),             // to fifo, bias opcode
//        .bias_wr_en_o(ptn_bias_fifo_wr_en),         // write bias fifo enable
//        .bias_fifo_empty_i(ptn_bias_fifo_empty),    // bias fifo empty flag
//        .bias_fifo_full_i(ptn_bias_fifo_full),      // bias fifo full flag

//        .opcode_counter_o(ptn_opcode_counter),                     
//        .status_o(ptn_processor_status),     // done with block, 1 is Success, else 8-bit error code
//        .busy_o(ptn_processor_busy)
//        );


    /////////////////////////////////////////////////////////
    // user-programmed pulse opcode parsing
    /////////////////////////////////////////////////////////
    reg [3:0]       channel;            // 1-16 minus 1
    reg [23:0]      pattern_entries;    // pulse width ticks, 100ns ticks, 100ns to 1.67 seconds   
    reg [23:0]      ticks;              // pattern_entries, used for local countdown   

    // measure bit in the pulse opcode
    `define PULSE_MEASURE       64'h0000_0001_0000_0000; 

    /////////////////////////////////
    // Set Pulse state definitions //
    /////////////////////////////////
    `define PULSE_IDLE          0
    `define PULSE_READ          1
    `define PULSE_WR_BEGIN      2
    `define PULSE_WR_PTN        3
    `define PULSE_PTN_READY     4
    `define PULSE_PTN_RUNNING   5
    ////////////////////////////////////////
    // End of pulse state definitions //
    ////////////////////////////////////////

`ifdef XILINX_SIMULATOR
    integer         filepulse = 0;
    reg [7:0]       dbgdata;
`endif

    assign pattern_ram_count_o = pattern_entries;

    always @( posedge clk)
    begin
        if( rst )
        begin
            state <= `PULSE_IDLE;
            next_state <= `PULSE_IDLE;
            pulse_fifo_rd_en_o <= 1'b0;
            pulse <= 64'h00000000_00000000;
            channel <= 4'b0000;
            pattern_entries <= 24'h00_0000;
            ticks <= 24'h00_0000;
        end
        else if(pulse_en == 1)
        begin
            case(state)
            `PULSE_IDLE: begin
                if(!pulse_fifo_empty_i) begin
                    pulse_fifo_rd_en_o <= 1;   // read next value
                    state <= `PULSE_READ;
                    busy_o <= 1'b1;
                end
                else
                    busy_o <= 1'b0;
            end             
            `PULSE_READ: begin
                // read pulse data from fifo
                pulse <= pulse_fifo_i;
                pattern_entries <= pulse_fifo_i[31:8];  // for external pattern engine
                ticks <= pulse_fifo_i[31:8];            // for countdown here
                pulse_fifo_rd_en_o <= 0;
                state <= `PULSE_WR_BEGIN;
            `ifdef XILINX_SIMULATOR
                if(filepulse == 0)
                    filepulse = $fopen("../../../project_1.srcs/sources_1/pulse_in.txt", "a");
                $fdisplay (filepulse, "Pulse:0x%h", pulse_fifo_i);
            `endif
            end
            `PULSE_WR_BEGIN: begin
                // Begin writing pattern RAM
                pattern_ram_addr <= 16'h0000; 
                if(pulse & 64'h0000_0001_0000_0000 && 
                   pulse[63:40] == 24'h00_0000)
                    pattern_ram_data_in <= (`PTN_ON | `PTN_MEASURE); // RF ON, measure
                else
                    pattern_ram_data_in <= `PTN_ON; // RF ON
                pattern_ram_wr_en <= 1'b1;
                ticks <= ticks - 1;
                state <= `PULSE_WR_PTN;
            end
            `PULSE_WR_PTN: begin
                if(ticks == 0) begin
                `ifdef XILINX_SIMULATOR
                    $fdisplay (filepulse, "Pulse:PTN_READY(waiting)");
                `endif
                    state <= `PULSE_PTN_READY;
                end
                else begin
                    // Write entries in pattern RAM
                    pattern_ram_addr <= pattern_ram_addr + 1;
                    if((pulse & 64'h0000_0001_0000_0000) &&
                       (pattern_ram_addr + 1 >= pulse[63:40]))    // at measurement offset?
                            pattern_ram_data_in <= (`PTN_ON | `PTN_MEASURE); // RF ON, measure
                    else
                        pattern_ram_data_in <= `PTN_ON;        // RF ON
                    ticks <= ticks - 1;
                end
            end
            `PULSE_PTN_READY: begin
                if(pattern_running) begin
                `ifdef XILINX_SIMULATOR
                    $fdisplay (filepulse, "Pulse:PTN_RUNNING");
                `endif
                    state <= `PULSE_PTN_RUNNING;
                end
            end
            `PULSE_PTN_RUNNING: begin
                if(!pattern_running) begin
                `ifdef XILINX_SIMULATOR
                    $fdisplay (filepulse, "Pulse:PTN_DONE");
                    if(pulse_fifo_empty_i) begin
                        $fclose(filepulse);
                        filepulse = 0;
                    end
                `endif
                    status_o = `SUCCESS;
                    state <= `PULSE_IDLE;
                end
            end
            default:
                begin
                `ifdef XILINX_SIMULATOR
                    $fdisplay (filepulse, "Pulse:Unknwon State Error");
                    if(pulse_fifo_empty_i) begin
                        $fclose(filepulse);
                        filepulse = 0;
                    end
                `endif
                    status_o = `ERR_UNKNOWN_PULSE_STATE;
                    state = `PULSE_IDLE;
                end
            endcase
        end
    end    
endmodule
