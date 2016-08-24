//////////////////////////////////////////////////////////////////////////////////
// Company: Ampleon 
// Engineer: Rick Rigby
// 
// Create Date: 07/05/2016 04:13:50 PM
// Design Name: Sango opcode processor
// Module Name: initialize
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: Initialization sequence to startup Sango SPI hardware
//      Project Defines are used to generate either Sango X7 code
//      or Sango S4 code
// 
// Dependencies: Vivado -> Project Settings -> Verilog Options:
//                  X7_Core = 1 to produce X7 initialization
//                  X7_Core = 0 to produce S4 initialization 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

`include "timescale.v"
`include "version.v"

`include "status.h"
`include "queue_spi.h"

module initialize(
    input rst,
    input clk,
    input init_enable,
    input spi_processor_idle,

    // SPI data is written to dual-clock fifo, then SPI write request is queued.
    // spi_processor_idle is asserted when write is finished by top level.
    output reg [7:0]    spi_o,              // spi DDS fifo data
    output reg          spi_wr_en_o,        // spi DDS fifo write enable
    input               spi_fifo_empty_i,   // spi DDS fifo empty flag
    input               spi_fifo_full_i,    // spi DDS fifo full flag
    input               spi_wr_ack_i,       // spi DDS fifo write acknowledge

    // The fifo to request an SPI write from the top level
    output reg [7:0]    spiwr_queue_data_o,       // queue request for DDS write
    output reg          spiwr_queue_wr_en_o,      // spi DDS fifo write enable
    input               spiwr_queue_fifo_empty_i, // spi DDS fifo empty flag
    input               spiwr_queue_fifo_full_i,  // spi DDS fifo full flag
    input               spiwr_queue_wr_ack_i,     // fifo write acknowledge

    output reg          init_done,              // signal caller all done
    output reg [7:0]    status_o                // SUCCESS when done, or an error code
    );

///// Hack... until SPI bus arbiter in place, can't have 2 modules driving SPI processor fifo's
//    // SPI data is written to dual-clock fifo, then SPI write request is queued.
//    // spi_processor_idle is asserted when write is finished by top level.
//    reg [7:0]    spi_o;              // spi DDS fifo data
//    reg          spi_wr_en_o;        // spi DDS fifo write enable

//    // The fifo to request an SPI write from the top level
//    reg [7:0]    spiwr_queue_data_o;       // queue request for DDS write
//    reg          spiwr_queue_wr_en_o;      // spi DDS fifo write enable
///// End Hack
    
    reg [5:0]   state = 0;
    reg [1:0]   done_delay; // Wait a couple of clocks when done for caller to clear 'run' flag
    reg [5:0]   next_state;
    reg [5:0]   byte_counter;
//    reg [7:0]   tmp;

    // States, 6 bits:
    `define INIT_IDLE           0
    `define INIT_WAIT           1
    `define INIT_SPI_PROC_WAIT  2
    `define INIT_WRDATA_WAIT    3
    `define INIT_WRDATA_FINISH  4
    `define INIT_WRQUE_WAIT     5
    `define INIT_DONE_WAIT      6
    `define INIT_DONE           7
    
`ifdef X7_CORE
    
// SPI initialization values from X7 perl, written ls byte first:
    //my %spis =
    //    ('dds_cfr1'  => {dev => 0x00, val => 0x0000004000, len => 5},
    //     'dds_cfr2'  => {dev => 0x00, val => 0x010002499000, len => 6},
    //     'dds_pcr0'  => {dev => 0x00, val => 0x0600000d9df51b3bea, len => 9},
    //     'dds_pcr1'  => {dev => 0x00, val => 0x070000000000000000, len => 9},
    //     'dds_pcr2'  => {dev => 0x00, val => 0x080000000000000000, len => 9},
    //     'dds_pcr3'  => {dev => 0x00, val => 0x090000000000000000, len => 9},
    //     'dds_pcr4'  => {dev => 0x00, val => 0x0a0000000000000000, len => 9},
    //     'dds_pcr5'  => {dev => 0x00, val => 0x0b0000000000000000, len => 9},
    //     'dds_pcr6'  => {dev => 0x00, val => 0x0c0000000000000000, len => 9},
    //     'dds_pcr7'  => {dev => 0x00, val => 0x0d0000000000000000, len => 9},
    //     'rsyn_init' => {dev => 0x01, val => 0x1ff813, len => 3},
    //     'rsyn_func' => {dev => 0x01, val => 0x1ff812, len => 3},
    //     'rsyn_ref'  => {dev => 0x01, val => 0x000008, len => 3},
    //     'rsyn_div'  => {dev => 0x01, val => 0x000b19, len => 3},
    //     'fr_conf'  => {dev => 0x02, val => 0x000081, len => 3},
    //     'fr_out0'  => {dev => 0x02, val => 0x001908, len => 3},
    //     'fr_div0'  => {dev => 0x02, val => 0x001521, len => 3},
    //     'fr_out1'  => {dev => 0x02, val => 0x001f80, len => 3},
    //     'fr_out2'  => {dev => 0x02, val => 0x002580, len => 3},
    //     'fr_out3'  => {dev => 0x02, val => 0x002b80, len => 3},
    //     'msyn_init' => {dev => 0x03, val => 0x1ff813, len => 3},
    //     'msyn_func' => {dev => 0x03, val => 0x1ff812, len => 3},
    //     'msyn_ref'  => {dev => 0x03, val => 0x000004, len => 3},
    //     'msyn_div'  => {dev => 0x03, val => 0x000a0d, len => 3},
    //     'mbw'  => {dev => 0x04, val => 0x08, len => 1},  # TODO
    //    );
    //my @spi_init = ('dds_cfr1','dds_cfr2','dds_pcr0',
    //  'rsyn_init','rsyn_func','rsyn_ref','rsyn_div',
    //  'mbw','msyn_init','msyn_func','msyn_ref','msyn_div');
    //#  'fr_conf','fr_out0','fr_out1','fr_out2','fr_out3','fr_div0');
    
    // Need to write these ls byte first
    reg [7:0] dds_cfr1 [4:0] = {8'h00, 8'h00, 8'h00, 8'h40, 8'h00};    // 0x0000004000    
    reg [7:0] dds_cfr2 [5:0] = {8'h01, 8'h00, 8'h02, 8'h49, 8'h90, 8'h00};
    reg [7:0] dds_pcr0 [8:0] = {8'h06, 8'h00, 8'h00, 8'h0d, 8'h9d, 8'hf5, 8'h1b, 8'h3b, 8'hea};
//    reg dds_pcr1[7:0] = {8'h07, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00};
//    reg dds_pcr2[7:0] = {8'h08, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00};
//    reg dds_pcr3[7:0] = {8'h09, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00};
//    reg dds_pcr4[7:0] = {8'h0a, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00};
//    reg dds_pcr5[7:0] = {8'h0b, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00};
//    reg dds_pcr6[7:0] = {8'h0c, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00};
//    reg dds_pcr7[7:0] = {8'h0d, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00};
    reg [7:0] rsyn_init [2:0] = {8'h1f, 8'hf8, 8'h13};
    reg [7:0] rsyn_func [2:0] = {8'h1f, 8'hf8, 8'h12};
    reg [7:0] rsyn_ref [2:0] = {8'h00, 8'h00, 8'h08};
    reg [7:0] rsyn_div [2:0] = {8'h00, 8'h0b, 8'h19};
//    reg fr_conf[7:0] = {8'h00, 8'h00, 8'h81};
//    reg fr_out0[7:0] = {8'h00, 8'h19, 8'h08};
//    reg fr_div0[7:0] = {8'h00, 8'h15, 8'h21};
//    reg fr_out1[7:0] = {8'h00, 8'h1f, 8'h80};
//    reg fr_out2[7:0] = {8'h00, 8'h25, 8'h80};
//    reg fr_out3[7:0] = {8'h00, 8'h2b, 8'h80};
    reg [7:0] msyn_init [2:0] = {8'h1f, 8'hf8, 8'h13};
    reg [7:0] msyn_func [2:0] = {8'h1f, 8'hf8, 8'h12};
    reg [7:0] msyn_ref [2:0] = {8'h00, 8'h00, 8'h04};
    reg [7:0] msyn_div [2:0] = {8'h00, 8'h0a, 8'h0d};
    // TBD reg mbw[7:0] = {8'h08};
    //my @spi_init = ('dds_cfr1','dds_cfr2','dds_pcr0',
    //  'rsyn_init','rsyn_func','rsyn_ref','rsyn_div',
    //  'mbw','msyn_init','msyn_func','msyn_ref','msyn_div');
    //#  'fr_conf','fr_out0','fr_out1','fr_out2','fr_out3','fr_div0');

    // States, 6 bits:
// done by IDLE    `define START_DDS_CFR1
    `define START_DDS_CFR1      9
    `define QUE_DDS_CFR1        10
    `define START_DDS_CFR2      11
    `define QUE_DDS_CFR2        12
    `define START_DDS_PCR0      13
    `define QUE_DDS_PCR0        14
    `define START_RSYN_INIT     15
    `define QUE_RSYN_INIT       16
    `define START_RSYN_FUNC     17
    `define QUE_RSYN_FUNC       18
    `define START_RSYN_REF      19
    `define QUE_RSYN_REF        20
    `define START_RSYN_DIV      21
    `define QUE_RSYN_DIV        22
    `define START_MSYN_INIT     23
    `define QUE_MSYN_INIT       24
    `define START_MSYN_FUNC     25
    `define QUE_MSYN_FUNC       26
    `define START_MSYN_REF      27
    `define QUE_MSYN_REF        28
    `define START_MSYN_DIV      29
    `define QUE_MSYN_DIV        30

    always @(posedge clk)
    begin
        if( rst )
        begin
            state <= `INIT_IDLE;            
            spi_wr_en_o <= 0; //1'bZ;
            spiwr_queue_wr_en_o <= 0; //1'bZ;
            status_o <= 0;
            init_done <= 0;
        end
        else
        begin
            case(state)
            `INIT_IDLE: begin
                if(init_enable && spi_processor_idle) begin
                    // Queue the array data and write for each register
                    init_done <= 0;
                    byte_counter <= `DDS_CFR1_BYTES;    // setup counter
                    state <= `START_DDS_CFR1;
                end
            end
//            `INIT_WAIT: begin
//                if(latency_counter == 0)
//                    state <= next_state;
//                else
//                    latency_counter <= latency_counter - 1;
//            end
            // Wait for SPI processor to finish before
            // starting next SPI request (next register)
            `INIT_SPI_PROC_WAIT: begin
                if(spi_processor_idle) begin
                    state <= next_state;
                end
            end
            `INIT_WRDATA_WAIT: begin
                // Write ACK takes one extra clock at the beginning & end
                if(spi_wr_ack_i == 1)
                    state <= next_state;
            end
            `INIT_WRDATA_FINISH: begin
                // need to wait for spi_fifo_empty_i flag to go OFF
                // when it does, queue the SPI write command
                if(!spi_fifo_empty_i)
                    state <= next_state;
            end
            `INIT_WRQUE_WAIT: begin
                // Write ACK takes one extra clock at the beginning & end
                // need to wait for spiwr_queue_fifo_empty_i flag to go OFF
                //
                // Wait for write ack, turn OFF writes
                // Wait for queue fifo empty OFF, enter SPI_WAIT_PROC state,
                //    waiting for SPI IO to finish, then go to next register(state)
                if(spiwr_queue_wr_en_o && spiwr_queue_wr_ack_i)
                    spiwr_queue_wr_en_o <= 0;
                if(!spiwr_queue_fifo_empty_i)
                    state <= `INIT_SPI_PROC_WAIT;
            end
            
            `START_DDS_CFR1: begin
                spi_wr_en_o <= 1;
                spi_o <= dds_cfr1[`DDS_CFR1_BYTES - byte_counter];  // ls byte first
                next_state <= `QUE_DDS_CFR1;
                state <= `INIT_WRDATA_WAIT;
            end
            `QUE_DDS_CFR1: begin
                byte_counter = byte_counter - 1;
                if(byte_counter == 0 ) begin
                    spi_wr_en_o <= 0;
                    spiwr_queue_data_o <= `SPI_DDS;     // queue request for write DDS
                    spiwr_queue_wr_en_o <= 1;           // spi queue fifo write enable
                    next_state <= `START_DDS_CFR2;      // after queueing cmd, wait for SPI processor idle, then next register
                    byte_counter <= `DDS_CFR2_BYTES;
                    state <= `INIT_WRQUE_WAIT;
//                `ifdef XILINX_SIMULATOR
//                    $fdisplay (filedds, "  ");   // spacer line
//                    $fclose (filedds);
//                    filedds = 0;
//                `endif
                end
                else begin
                    spi_o <= dds_cfr1[`DDS_CFR1_BYTES - byte_counter];
                    state <= `INIT_WRDATA_WAIT; // next_state already set, comes back here
                end
            end
            `START_DDS_CFR2: begin
                spi_wr_en_o <= 1;
                spi_o <= dds_cfr2[`DDS_CFR2_BYTES - byte_counter];  // ls byte first
                next_state <= `QUE_DDS_CFR2;
                state <= `INIT_WRDATA_WAIT;
            end
            `QUE_DDS_CFR2: begin
                byte_counter = byte_counter - 1;
                if(byte_counter == 0 ) begin
                    spi_wr_en_o <= 0;
                    spiwr_queue_data_o <= `SPI_DDS;     // queue request for write DDS
                    spiwr_queue_wr_en_o <= 1;           // spi queue fifo write enable
                    next_state <= `START_DDS_PCR0;      // after queueing cmd, wait for SPI processor idle, then next register
                    byte_counter <= `DDS_PCR_BYTES;
                    state <= `INIT_WRQUE_WAIT;
    //                `ifdef XILINX_SIMULATOR
    //                    $fdisplay (filedds, "  ");   // spacer line
    //                    $fclose (filedds);
    //                    filedds = 0;
    //                `endif
                end
                else begin
                    spi_o <= dds_cfr2[`DDS_CFR2_BYTES - byte_counter];
                    state <= `INIT_WRDATA_WAIT; // next_state already set, comes back here
                end
            end
            `START_DDS_PCR0: begin
                spi_wr_en_o <= 1;
                spi_o <= dds_pcr0[`DDS_PCR_BYTES - byte_counter];  // ls byte first
                next_state <= `QUE_DDS_PCR0;
                state <= `INIT_WRDATA_WAIT;
            end
            `QUE_DDS_PCR0: begin
                byte_counter = byte_counter - 1;
                if(byte_counter == 0 ) begin
                    spi_wr_en_o <= 0;
                    spiwr_queue_data_o <= `SPI_DDS;     // queue request for write DDS
                    spiwr_queue_wr_en_o <= 1;           // spi queue fifo write enable
                    next_state <= `START_RSYN_INIT;     // after queueing cmd, wait for SPI processor idle, then next register
                byte_counter <= `RSYN_BYTES;
                    state <= `INIT_WRQUE_WAIT;
                end
                else begin
                    spi_o <= dds_pcr0[`DDS_PCR_BYTES - byte_counter];
                    state <= `INIT_WRDATA_WAIT; // next_state already set, comes back here
                end
            end
            `START_RSYN_INIT: begin
                spi_wr_en_o <= 1;
                spi_o <= rsyn_init[`RSYN_BYTES - byte_counter];  // ls byte first
                next_state <= `QUE_RSYN_INIT;
                state <= `INIT_WRDATA_WAIT;
            end
            `QUE_RSYN_INIT: begin
                byte_counter = byte_counter - 1;
                if(byte_counter == 0 ) begin
                    spi_wr_en_o <= 0;
                    spiwr_queue_data_o <= `SPI_RSYN;    // queue request for write RSYN
                    spiwr_queue_wr_en_o <= 1;           // spi queue fifo write enable
                    next_state <= `START_RSYN_FUNC;     // after queueing cmd, wait for SPI processor idle, then next register
                    byte_counter <= `RSYN_BYTES;
                    state <= `INIT_WRQUE_WAIT;
                end
                else begin
                    spi_o <= rsyn_init[`RSYN_BYTES - byte_counter];
                    state <= `INIT_WRDATA_WAIT; // next_state already set, comes back here
                end
            end
            `START_RSYN_FUNC: begin
                spi_wr_en_o <= 1;
                spi_o <= rsyn_func[`RSYN_BYTES - byte_counter];  // ls byte first
                next_state <= `QUE_RSYN_FUNC;
                state <= `INIT_WRDATA_WAIT;
            end
            `QUE_RSYN_FUNC: begin
                byte_counter = byte_counter - 1;
                if(byte_counter == 0 ) begin
                    spi_wr_en_o <= 0;
                    spiwr_queue_data_o <= `SPI_RSYN;    // queue request for write RSYN
                    spiwr_queue_wr_en_o <= 1;           // spi queue fifo write enable
                    next_state <= `START_RSYN_REF;      // after queueing cmd, wait for SPI processor idle, then next register
                    byte_counter <= `RSYN_BYTES;
                    state <= `INIT_WRQUE_WAIT;
                end
                else begin
                    spi_o <= rsyn_func[`RSYN_BYTES - byte_counter];
                    state <= `INIT_WRDATA_WAIT;         // next_state already set, comes back here
                end
            end
            `START_RSYN_REF: begin
                spi_wr_en_o <= 1;
                spi_o <= rsyn_ref[`RSYN_BYTES - byte_counter];  // ls byte first
                next_state <= `QUE_RSYN_REF;
                state <= `INIT_WRDATA_WAIT;
            end
            `QUE_RSYN_REF: begin
                byte_counter = byte_counter - 1;
                if(byte_counter == 0 ) begin
                    spi_wr_en_o <= 0;
                    spiwr_queue_data_o <= `SPI_RSYN;    // queue request for write DDS
                    spiwr_queue_wr_en_o <= 1;           // spi queue fifo write enable
                    next_state <= `START_RSYN_DIV;      // after queueing cmd, wait for SPI processor idle, then next register
                    byte_counter <= `RSYN_BYTES;
                    state <= `INIT_WRQUE_WAIT;
                end
                else begin
                    spi_o <= rsyn_ref[`RSYN_BYTES - byte_counter];
                    state <= `INIT_WRDATA_WAIT;         // next_state already set, comes back here
                end
            end
            `START_RSYN_DIV: begin
                spi_wr_en_o <= 1;
                spi_o <= rsyn_div[`RSYN_BYTES - byte_counter];  // ls byte first
                next_state <= `QUE_RSYN_DIV;
                state <= `INIT_WRDATA_WAIT;
            end
            `QUE_RSYN_DIV: begin
                byte_counter = byte_counter - 1;
                if(byte_counter == 0 ) begin
                    spi_wr_en_o <= 0;
                    spiwr_queue_data_o <= `SPI_RSYN;    // queue request for write DDS
                    spiwr_queue_wr_en_o <= 1;           // spi queue fifo write enable
                    next_state <= `START_MSYN_INIT;     // after queueing cmd, wait for SPI processor idle, then next register
                    byte_counter <= `MSYN_BYTES;
                    state <= `INIT_WRQUE_WAIT;
                end
                else begin
                    spi_o <= rsyn_div[`RSYN_BYTES - byte_counter];
                    state <= `INIT_WRDATA_WAIT;         // next_state already set, comes back here
                end
            end
            `START_MSYN_INIT: begin
                spi_wr_en_o <= 1;
                spi_o <= msyn_init[`MSYN_BYTES - byte_counter];  // ls byte first
                next_state <= `QUE_MSYN_INIT;
                state <= `INIT_WRDATA_WAIT;
            end
            `QUE_MSYN_INIT: begin
                byte_counter = byte_counter - 1;
                if(byte_counter == 0 ) begin
                    spi_wr_en_o <= 0;
                    spiwr_queue_data_o <= `SPI_MSYN;    // queue request for write DDS
                    spiwr_queue_wr_en_o <= 1;           // spi queue fifo write enable
                    next_state <= `START_MSYN_FUNC;     // after queueing cmd, wait for SPI processor idle, then next register
                    byte_counter <= `MSYN_BYTES;
                    state <= `INIT_WRQUE_WAIT;
                end
                else begin
                    spi_o <= msyn_init[`MSYN_BYTES - byte_counter];
                    state <= `INIT_WRDATA_WAIT;         // next_state already set, comes back here
                end
            end
            `START_MSYN_FUNC: begin
                spi_wr_en_o <= 1;
                spi_o <= msyn_func[`MSYN_BYTES - byte_counter];  // ls byte first
                next_state <= `QUE_MSYN_FUNC;
                state <= `INIT_WRDATA_WAIT;
            end
            `QUE_MSYN_FUNC: begin
                byte_counter = byte_counter - 1;
                if(byte_counter == 0 ) begin
                    spi_wr_en_o <= 0;
                    spiwr_queue_data_o <= `SPI_MSYN;    // queue request for write DDS
                    spiwr_queue_wr_en_o <= 1;           // spi queue fifo write enable
                    next_state <= `START_MSYN_REF;     // after queueing cmd, wait for SPI processor idle, then next register
                    byte_counter <= `MSYN_BYTES;
                    state <= `INIT_WRQUE_WAIT;
                end
                else begin
                    spi_o <= msyn_func[`MSYN_BYTES - byte_counter];
                    state <= `INIT_WRDATA_WAIT;         // next_state already set, comes back here
                end
            end
            `START_MSYN_REF: begin
                spi_wr_en_o <= 1;
                spi_o <= msyn_ref[`MSYN_BYTES - byte_counter];  // ls byte first
                next_state <= `QUE_MSYN_REF;
                state <= `INIT_WRDATA_WAIT;
            end
            `QUE_MSYN_REF: begin
                byte_counter = byte_counter - 1;
                if(byte_counter == 0 ) begin
                    spi_wr_en_o <= 0;
                    spiwr_queue_data_o <= `SPI_MSYN;    // queue request for write DDS
                    spiwr_queue_wr_en_o <= 1;           // spi queue fifo write enable
                    next_state <= `START_MSYN_DIV;     // after queueing cmd, wait for SPI processor idle, then next register
                    byte_counter <= `MSYN_BYTES;
                    state <= `INIT_WRQUE_WAIT;
                end
                else begin
                    spi_o <= msyn_ref[`MSYN_BYTES - byte_counter];
                    state <= `INIT_WRDATA_WAIT;         // next_state already set, comes back here
                end
            end
            `START_MSYN_DIV: begin
                spi_wr_en_o <= 1;
                spi_o <= msyn_div[`MSYN_BYTES - byte_counter];  // ls byte first
                next_state <= `QUE_MSYN_DIV;
                state <= `INIT_WRDATA_WAIT;
            end
            `QUE_MSYN_DIV: begin
                byte_counter = byte_counter - 1;
                if(byte_counter == 0 ) begin
                    spi_wr_en_o <= 0;
                    spiwr_queue_data_o <= `SPI_MSYN;    // queue request for write DDS
                    spiwr_queue_wr_en_o <= 1;           // spi queue fifo write enable
                    next_state <= `INIT_DONE_WAIT;           // after queueing cmd, wait for SPI processor idle, then we're done
                    state <= `INIT_WRQUE_WAIT;
                end
                else begin
                    spi_o <= msyn_div[`MSYN_BYTES - byte_counter];
                    state <= `INIT_WRDATA_WAIT;         // next_state already set, comes back here
                end
            end
            `INIT_DONE_WAIT: begin
                done_delay <= 2;    // Wait a couple of clocks for 'run_init' to be cleared by caller
                spi_wr_en_o <= 0;
                spiwr_queue_wr_en_o <= 0;
                init_done <= 1;
                status_o <= 0;
                state <= `INIT_DONE;            
            end
            `INIT_DONE: begin
                if(done_delay == 0)
                    state <= `INIT_IDLE;
                else
                    done_delay = done_delay - 1;
            end
            endcase
        end
    end    
`else
    // S4 initialization sequence
    // Write out initialization values to all SPI registers on enable
    `define DDS_CFR1_BYTES      5
    `define DDS_CFR2_BYTES      6

// done by IDLE    `define START_DDS_CFR1
    `define QUE_DDS_CFR1        10
    `define START_DDS_CFR2      11
    `define QUE_DDS_CFR2        12

    always @(posedge clk)
    begin
        if( rst )
        begin
            state <= `INIT_IDLE;            
            spi_wr_en_o <= 1'bZ;
            spiwr_queue_wr_en_o <= 1'bZ;
            status_o <= 0;
            init_done <= 0;
            spi_o <= 8'bZZZZZZZZ;
            spi_wr_en_o <= 1'bZ;
            spiwr_queue_data_o <= 8'bZZZZZZZZ;
            spiwr_queue_wr_en_o <= 1'bZ;
        end
        else
        begin
            case(state)
            `INIT_IDLE: begin
                if(init_enable && spi_processor_idle)
                    // Queue the array data and write for each register
                    init_done <= 0;
                    byte_counter <= `DDS_CFR1_BYTES;
                    spi_wr_en_o <= 1;
                    spi_o <= dds_cfr1[`DDS_CFR1_BYTES - byte_counter];  // ls byte first
                    next_state <= `QUE_DDS_CFR1;
                    state <= `INIT_WRDATA_WAIT;
            end
            // starting next SPI request (next register)
            `INIT_SPI_PROC_WAIT: begin
                if(spi_processor_idle) begin
                    state <= next_spiwr_state;
                end
            end
            `INIT_WRDATA_WAIT: begin
                // Write ACK takes one extra clock at the beginning & end
                if(spi_wr_ack_i == 1)
                    state <= next_state;
            end
            `INIT_WRDATA_FINISH: begin
                // need to wait for spi_fifo_empty_i flag to go OFF
                // when it does, queue the SPI write command
                if(!spi_fifo_empty_i)
                    state <= next_state;
            end
            `INIT_WRQUE_WAIT: begin
                // Write ACK takes one extra clock at the beginning & end
                // need to wait for spiwr_queue_fifo_empty_i flag to go OFF
                //
                // Wait for write ack, turn OFF writes
                // Wait for queue fifo empty OFF, enter SPI_WAIT_PROC state,
                //    waiting for SPI IO to finish, then go to next register(state)
                if(spiwr_queue_wr_en_o && spiwr_queue_wr_ack_i)
                    spiwr_queue_wr_en_o <= 0;
                if(!spiwr_queue_fifo_empty_i)
                    state <= `INIT_SPI_PROC_WAIT;
            end
            
            `QUE_DDS_CFR1: begin
                byte_counter = byte_counter - 1;
                if(byte_counter == 0 ) begin
                    spi_wr_en_o <= 0;
                    spiwr_queue_data_o <= `SPI_DDS;     // queue request for write DDS
                    spiwr_queue_wr_en_o <= 1;           // spi queue fifo write enable
                    next_state <= `START_DDS_CFR2;      // after queueing cmd, wait for SPI processor idle, then next register
                    state <= `INIT_WRQUE_WAIT;
//                `ifdef XILINX_SIMULATOR
//                    $fdisplay (filedds, "  ");   // spacer line
//                    $fclose (filedds);
//                    filedds = 0;
//                `endif
                end
                else begin
                    spi_o <= dds_cfr1[`DDS_CFR1_BYTES - byte_counter];
                    state <= `INIT_WRDATA_WAIT; // next_state already set, comes back here
                end
            end
            `START_DDS_CFR2: begin
                byte_counter <= `DDS_CFR2_BYTES;
                spi_wr_en_o <= 1;
                spi_o <= dds_cfr2[`DDS_CFR2_BYTES - byte_counter];  // ls byte first
                next_state <= `QUE_DDS_CFR2;
                state <= `INIT_WRDATA_WAIT;
            end
            `QUE_DDS_CFR2: begin
                byte_counter = byte_counter - 1;
                if(byte_counter == 0 ) begin
                    spi_wr_en_o <= 0;
                    spiwr_queue_data_o <= `SPI_DDS;     // queue request for write DDS
                    spiwr_queue_wr_en_o <= 1;           // spi queue fifo write enable
                    next_state <= `INIT_DONE;           // after queueing cmd, wait for SPI processor idle, then next register
                    state <= `INIT_WRQUE_WAIT;
    //                `ifdef XILINX_SIMULATOR
    //                    $fdisplay (filedds, "  ");   // spacer line
    //                    $fclose (filedds);
    //                    filedds = 0;
    //                `endif
                end
                else begin
                    spi_o <= dds_cfr2[`DDS_CFR2_BYTES - byte_counter];
                    state <= `INIT_WRDATA_WAIT; // next_state already set, comes back here
                end
            end
            `INIT_DONE: begin
                spi_wr_en_o <= 0;
                spiwr_queue_wr_en_o <= 0;
                init_done <= 1;
                status_o <= 0;
                state <= `INIT_IDLE;
            end
            endcase
        end
    end    
`endif
endmodule
