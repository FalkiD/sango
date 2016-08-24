//------------------------------------------------------------------------------
// (C) Copyright 2016, Ampleon Inc.
//     All rights reserved.
//
// PROPRIETARY INFORMATION
//
// The information contained in this file is the property of Ampleon Inc.
// Except as specifically authorized in writing by Ampleon, the holder of this
// file:
// (1) shall keep all information contained herein confidential and shall protect
//     same in whole or in part from disclosure and dissemination to all third
//     parties and 
// (2) shall use same for operation and maintenance purposes only.
// -----------------------------------------------------------------------------
// Company:         Ampleon
// Engineer:        Rick Rigby
// 
// Create Date:     03/23/2016 08:52:50 AM
// Design Name:     Opcode Processor
// File Name:       top.v
// Module Name:     top
// Project Name:    Sango
// Target Devices:  xc7a35ticsg324-1L (debug)
// Tool Versions:   Vivado 2015.4 (RMR) & 2016.2 (JLC)
// Description:     10ns CLK
// 
// Hierarchy:                                             Scope:
// ---------------------------------------------------    ----------------------------------------------------
//    top.v                                               (top)    
//        timescale.v                                     (NOTE: included by every non-ip *.v)
//        version.v                                       (NOTE: included by every non-ip *.v)
//        opcodes.txt                                     ($readmemh --> top.oplist)
//        status.h                                        --> MULTIPLE includes of this file in project.
//        queue_spi.h                                     --> MULTIPLE includes of this file in project.
//        spi_arbiter.h                                   --> MULTIPLE includes of this file in project.
//        spi_out.txt                                     (top.filespi $fopen "wa")
// 
//        ip/clkgen/clkgen.v
//        arbiter8.v                                      (top.arb8.spi_arbiter)
//        fifo_pack.vhd                                   (top.swiss_army_fifo.mmc_opcodes)
//        fifo_pack.vhd                                   (top.swiss_army_fifo.opcode_response)
//        fifo_pack.vhd                                   (top.swiss_army_fifo.freq_fifo)
//        fifo_pack.vhd                                   (top.swiss_army_fifo.power_fifo)
//        fifo_pack.vhd                                   (top.swiss_army_fifo.pulse_fifo)
//        fifo_pack.vhd                                   (top.swiss_army_fifo.bias_fifo)
//        ptn_ram.v                                       (top.patterns)
//        opcodes.v                                       (top.processor)
//            status.h                                    --> MULTIPLE includes of this file in project.
//            opcodes.h                                   --> MULTIPLE includes of this file in project.
//            opc_from_fifo.txt                           (top.processor.fileopcode = $fopen "wa")
//            opcode_freqs_to_fifo.txt                    (top.processor.filefreqs = $fopen "wa")
//            opcode_pwr_to_fifo.txt                      (top.processor.filepwr = $fopen "wa")
//            opcode_pulse_to_fifo.txt                    (top.processor.filepulse = $fopen "wa")
//            opcode_bias_to_fifo.txt                     (top.processor.filebias = $fopen "wa")
//            opcode_status.txt                           (top.processor.fileopcerr = $fopen "wa")
//        ip/fifo_dualclock.v/sim/fifo_dualclock.vhd      (top.spiwr_fifo)
//        ip/fifo_dualclock.v/synth/fifo_dualclock.vhd    (top.spiwr_fifo)
//        ip/fifo_dualclock.v/sim/fifo_dualclock.vhd      (top.spidata_fifo)
//        ip/fifo_dualclock.v/synth/fifo_dualclock.vhd    (top.spidata_fifo)
//        frequency.v                                     (top.set_freq)
//            opcodes.h                                   --> MULTIPLE includes of this file in project.
//            status.h                                    --> MULTIPLE includes of this file in project.
//            queue_spi.h                                 --> MULTIPLE includes of this file in project.
//            division.v                                  (top.set_freq.divnorem)
//            ip/divider32/sim/divider32.v                (top.set_freq.divrem)
//            ip/divider32/synth/divider32.v              (top.set_freq.divrem)
//            ip/mult48/sim/mult48.vhd                    (top.set_freq.ddsMultiply)
//            ip/mult48/synth/mult48.vhd                  (top.set_freq.ddsMultiply)
//            spi_in.txt                                  (top.set_freq.filedds = $fopen "wa")
//            fr_calcs.txt                                (top.set_freq.filefr = $fopen "wa")
//        power.v                                         (top.set_power)
//            opcodes.h                                   --> MULTIPLE includes of this file in project.
//            status.h                                    --> MULTIPLE includes of this file in project.
//            queue_spi.h                                 --> MULTIPLE includes of this file in project.
//            division.v                                  (top.set_power.divnorem)
//            ip/mult48/sim/mult48.vhd                    (top.set_power.ddsMultiply)
//            ip/mult48/synth/mult48.vhd                  (top.set_power.ddsMultiply)
//            pwr_in.txt                                  (top.set_power.filepwr = $fopen "wa")
//        pulse.v                                         (top.pulse_processor)
//            opcodes.h                                   --> MULTIPLE includes of this file in project.
//            status.h                                    --> MULTIPLE includes of this file in project.
//            queue_spi.h                                 --> MULTIPLE includes of this file in project.
//            fifo_pack.vhd                               (top.pulse_processor.swiss_army_fifo.freq_fifo)
//            fifo_pack.vhd                               (top.pulse_processor.swiss_army_fifo.power_fifo)
//            fifo_pack.vhd                               (top.pulse_processor.swiss_army_fifo.bias_fifo)
//            fifo_pack.vhd                               (top.pulse_processor.swiss_army_fifo.bias_fifo)
//            fifo_pack.vhd                               (top.pulse_processor.swiss_army_fifo.ptn_opcodes)
//            opcodes.v                                   (top.pulse_processor.pattern_processor)
//            pulse_in.txt                                (top.pulse_processor.filepulse = $fopen "wa")
//        bias.v                                          (top.bias_processor)
//            opcodes.h                                   --> MULTIPLE includes of this file in project.
//            status.h                                    --> MULTIPLE includes of this file in project.
//            queue_spi.h                                 --> MULTIPLE includes of this file in project.
//            patterns.h                                  
//            bias_in.txt                                 (top.bias_processor.filebias = $fopen "wa")
//        spi_mux.v                                       (top.spi_fifo_mux)
//            status.h                                    --> MULTIPLE includes of this file in project.
//            spi_arbiter.h                               --> MULTIPLE includes of this file in project.
//        spi_master.v                                    (top.spiwr)
//        uart.v                                          (top.uart1)
//           xmtr.v                                       (top.uart1.xmtr)
//           rcvr.v                                       (top.uart1.rcvr)
//        initialize.v                                    (top.init_x7)
//            status.h                                    --> MULTIPLE includes of this file in project.
//            queue_spi.h                                 --> MULTIPLE includes of this file in project.
//
// 
// 
// Revision 0.00.1  early/2016 RMR File Created
// Revision 0.00.1  08/24/2016 JLC Included in debug repository w/ visual changes.
//
// Additional Comments: General structure/sequence:
//   Fifo's at top level for: opcodes and opcode processor output
//   such as frequency, power, bias, phase, pulse, etc.
//
//   Processor modules for each item, frequency, power, phase, etc
//   will process their respective fifo data and generate SPI data
//   to be sent to hardware.
//
//   Each SPI device also has a fifo at top level. SPI data is written
//   by each subsystem processor into the correct SPI fifo. When a
//   hardware processor has finished generating SPI bytes, a request 
//   to write SPI will be written into the top level SpiQueue fifo.
//
//   An always block at top level will process the SPI queue, writing
//   bytes from a device fifo to the device.
// 
// -----------------------------------------------------------------------------

`include "timescale.v"
`include "version.v"
`include "status.h"
`include "queue_spi.h"
`include "spi_arbiter.h"

`define ENTRIES         16
`define MMC_SECTOR_SIZE 512

// For displaying output with LED's. 50MHz clock
`define MS750      750000000/20     // 750e6 NS/Period = 750ms
`define MS250      250000000/20     // 250 ms
`define MS500      500000000/20     // 500 ms
// Flash 16-bits using 4 led'S every 5 seconds
`define MS2000     2000000000/20    // 2 seconds 
`define MS2500     2500000000/20    // 2.5 seconds 
`define MS3000     3000000000/20    // 3 seconds 
`define MS3500     3500000000/20    // 3.5 seconds 

`define MS5000     250000000        // 5 seconds

`define US150      150000/20        // 150 us
`define MS001      1500000/20       // 1.5ms 

module top(
    input              CLK,
    input              RST,
    //output reg [3:0] LED,

    input              SYN_MISO,
    output             SYN_MOSI,
    output             SYN_SCLK,
    output reg         DDS_SSN,
    output reg         RSYN_SSN,
    output reg         MSYN_SSN,
    output reg         FR_SSN,
    output reg         MBW_SSN,
    
//    input MMCCLK,
//    input MMCCMD,
//    input [7:0] DAT

    // Coop's debugger uart module!
    input  [3:0]       SW,               // ARTY slide switches.
    input  [2:0]       btn,              // ARTY pushbuttons (Using BTN[3] as external reset).
    output reg [3:0]   LED,              // ARTY regular LEDs               (ARTY LD7 - LD4).
    output [3:0]       RGB_GRN,          // ARTY regular LEDs               (ARTY LD7 - LD4).
    output             JD_GPIO7,         // JD is farthest PMod from USB, Ethernet, Power barrel end of ARTY
    output             JD_GPIO6,
    output             JD_GPIO5,
    output             JD_GPIO4,
    output             JD_GPIO3,
    output             JD_GPIO2,
    output             JD_GPIO1,
    output             JD_GPIO0,
    input              UART_TXD,         // ARTY USB-SerialBridge ---> FPGA (Not JTAG).
    output             UART_RXD          // ARTY USB-SerialBridge <--- FPGA (Not JTAG).
);

//----------------------------------------------------------

    // General Signals, latch asynch RST
    wire        rst_n;  // Synchronous low-true reset for VHDL FIFO module & SPI module
    wire        rst;    // Synchronous RST

    // keep track of what's going on, or'd flags
    reg  [15:0] system_state = 0;
    reg  [31:0] opcodes_processed;
    reg  [31:0] ptn_opcodes_processed;

//    // count these when MMC card is plugged into host
//    reg [31:0]  mmcclks = 0;

    /*  
     * Our main 100MHz clock comes from the synthesizer, a differential clock.
     * Use a 50MHz clock for opcode processing to alleviate timing errors during
     * multiplication and division during frequency calculations.
     */
    wire    clk100;                 // 100MHz
    wire    clk50;
    clkgen main_clocks
    (   // Clock in ports
        .clk_in(CLK),               // input clk_in
        // Clock out ports
        .clk(clk100),               // output clk
        .clk50(clk50),              // output clk50
        // Status and control signals
        .reset(RST)                 // input reset
    );
    
    // SPI processor variables
    `define SPI_IDLE            0
    `define SPI_FETCH_DEVICE    1
    `define SPI_FETCH_DATA      2
    `define SPI_FETCH_WAIT      3
    `define SPI_WRITING         4
    reg [3:0]   spi_state    = `SPI_IDLE;    
    reg [7:0]   spi_status   = `SUCCESS;
    reg [3:0]   spi_device   = `SPI_NONE;

    `define SPI_MAX_BYTES       64
    `define SPI_RD_LATENCY      2
    reg [7:0]   spidata[63:0];      // save up to 64 bytes to be written to a device
    reg [7:0]   spibytes    = 0;    // total bytes to be sent
    reg [7:0]   spiindex    = 0;
    reg [3:0]   spi_read_latency;
    
    // Need status that indicates all SPI bytes have been sent, not just fifo_empty.
    wire spi_idle;     // ready if !spi_busy && spiqueue_empty & spi_fifo_empty  

    //
    // 01-Apr fill FIFO & run opcode processor from top.v
    //
    // Don't run opcode processor until FIFO loaded
    // 'run' is a kludge for waiting until we load the opcode fifo from an array.
    // this will be done away with when MMC core is ready.
    reg         run         = 1'b0; // Run opcode processor, use with opcode_processor_en flag, maybe refactor
    // opcode_processor_en line is main opcode processor enable. In final IP it will be
    // asserted by the MMC core when opcodes are available for processing and will 
    // remain asserted until all opcodes are done and SPI data has been written.
    reg         opcode_processor_en = 1'b0; // Disabled until opcode data is ready
    reg  [8:0]  idx;                        // 9-bit FIFO index
    reg  [31:0] address = 0;
    wire [31:0] opcode_counter;

    //////////////////////////////////////////////////////////////
    // Module status registers. These need to be passed back in
    // the 'Status' opcode response. They are persisted as registers.
    // 'wire' values are updated by processor modules.
    //////////////////////////////////////////////////////////////
    wire  [7:0]  opcode_processor_status; // Initial value removed by John Clayton
    reg   [7:0]  opcode_processor_last_status;
    wire  [7:0]  freq_status;
    reg   [7:0]  freq_last_status;
    wire  [7:0]  power_status;
    reg   [7:0]  power_last_status;
    wire  [7:0]  pulse_status;
    reg   [7:0]  pulse_last_status;
    wire  [7:0]  pattern_sequencer_status;
    reg   [7:0]  pattern_sequencer_last_status;

    wire         response_ready;
    wire         opcode_processor_busy;  // State of opcode processor module
    wire         freq_processor_busy;    // State of frequency processor module
    wire         power_processor_busy;   // State of power processor module
    wire         bias_processor_busy;    // State of bias processor module
    wire         pulse_processor_busy;   // State of pulse processor module
    wire         pattern_processor_busy; // State of pattern processor module

    always @(*) begin
        opcode_processor_last_status = opcode_processor_status;
        freq_last_status   = freq_status;
        power_last_status  = power_status;
        pulse_last_status  = pulse_status;
        pattern_sequencer_last_status = pattern_sequencer_status;

        opcodes_processed  = opcode_counter;

        if(response_ready)
            system_state   = system_state | `STATE_RSP_READY;
        else
            system_state   = system_state & ~(`STATE_RSP_READY);
            
        if(opcode_processor_busy)
            system_state   = system_state | `STATE_OPC_BUSY;
        else
            system_state   = system_state & ~(`STATE_OPC_BUSY);
            
        if(freq_processor_busy)
            system_state   = system_state | `STATE_FRQ_BUSY;
        else
            system_state   = system_state & ~(`STATE_FRQ_BUSY);
        
        if(power_processor_busy)
            system_state   = system_state | `STATE_PWR_BUSY;
        else
            system_state   = system_state & ~(`STATE_PWR_BUSY);
            
        if(pulse_processor_busy)
            system_state   = system_state | `STATE_PLS_BUSY;
        else
            system_state   = system_state & ~(`STATE_PLS_BUSY);

        if(bias_processor_busy)
            system_state   = system_state | `STATE_BIAS_BUSY;
        else
            system_state   = system_state & ~(`STATE_BIAS_BUSY);

        if(pattern_processor_busy)
            system_state   = system_state | `STATE_PTN_BUSY;
        else
            system_state   = system_state & ~(`STATE_PTN_BUSY);

        if(spi_busy)
            system_state   = system_state | `STATE_SPI_BUSY;
        else
            system_state   = system_state & ~(`STATE_SPI_BUSY);
    end

    //////////////////////////////////////////////////////////////
    // System state, last programmed values for each channel.
    // Save these as opcodes for easy usage by pattern sequencer
    //////////////////////////////////////////////////////////////
    wire  [7:0]   last_power [5:0];       // 16 channels, 4 bytes per channel
    wire  [7:0]   last_frequency [5:0];   // ditto
    wire  [7:0]   last_bias   [5:0];      // ditto

    /////////////////////////////////////////////////////////////
    // Config items
    /////////////////////////////////////////////////////////////
    wire          x7_mode = 1;
    wire          hi_spd_syn_mode = 0;

    //////////////////////////////////////////////////////////////
    // SPI mux definitions (8 element arrays)
    // 
    // spi_mux_select is the index used by the SPI mux module
    // The arbiter request input is a bitmask and can often have multiple 
    // requests asserted at the same time.
    //
    //////////////////////////////////////////////////////////////
    wire  [2:0] spi_mux_select;                   // Mux selector, array index, set by SPI arbiter
    reg         spi_fifo_mux_enable = 1'b1;       // mux always enabled, like SPI processor
    // SPI mux definitions for each SPI mux input module
    // 0=init
    wire  [7:0] spimx_init_fifo_data_i;           // initialization spi fifo data
    wire        spimx_init_fifo_wr_en_i;          // initialization spi fifo write enable
    wire        spimx_init_fifo_empty_o;          // initialization spi fifo empty flag
    wire        spimx_init_fifo_full_o;           // initialization spi fifo full flag
    wire        spimx_init_fifo_wr_ack_o;         // initialization spi fifo write acknowledge
    // 1=frequency
    wire  [7:0] spimx_freq_fifo_data_i;           // frequency spi fifo data
    wire        spimx_freq_fifo_wr_en_i;          // frequency spi fifo write enable
    wire        spimx_freq_fifo_empty_o;          // frequency spi fifo empty flag
    wire        spimx_freq_fifo_full_o;           // frequency spi fifo full flag
    wire        spimx_freq_fifo_wr_ack_o;         // frequency spi fifo write acknowledge
    // 2=power
    wire  [7:0] spimx_pwr_fifo_data_i;            // power spi fifo data
    wire        spimx_pwr_fifo_wr_en_i;           // power spi fifo write enable
    wire        spimx_pwr_fifo_empty_o;           // power spi fifo empty flag
    wire        spimx_pwr_fifo_full_o;            // power spi fifo full flag
    wire        spimx_pwr_fifo_wr_ack_o;          // power spi fifo write acknowledge
    // 3=phase
    wire  [7:0] spimx_phs_fifo_data_i;            // phase spi fifo data
    wire        spimx_phs_fifo_wr_en_i;           // phase spi fifo write enable
    wire        spimx_phs_fifo_empty_o;           // phase spi fifo empty flag
    wire        spimx_phs_fifo_full_o;            // phase spi fifo full flag
    wire        spimx_phs_fifo_wr_ack_o;          // phase spi fifo write acknowledge
    // 4=pattern
    wire  [7:0] spimx_ptn_fifo_data_i;            // pattern spi fifo data
    wire        spimx_ptn_fifo_wr_en_i;           // pattern spi fifo write enable
    wire        spimx_ptn_fifo_empty_o;           // pattern spi fifo empty flag
    wire        spimx_ptn_fifo_full_o;            // pattern spi fifo full flag
    wire        spimx_ptn_fifo_wr_ack_o;          // pattern spi fifo write acknowledge
    // 5=bias
    wire  [7:0] spimx_bias_fifo_data_i;           // bias spi fifo data
    wire        simx_bias_fifo_wr_en_i;           // bias spi fifo write enable
    wire        simx_bias_fifo_empty_o;           // bias spi fifo empty flag
    wire        simx_bias_fifo_full_o;            // bias spi fifo full flag
    wire        spimx_bias_fifo_wr_ack_o;         // bias spi fifo write acknowledge
    // 6
    wire  [7:0] spimx_6_fifo_data_i;              // bias spi fifo data
    wire        spimx_6_fifo_wr_en_i;             // bias spi fifo write enable
    wire        spimx_6_fifo_empty_o;             // bias spi fifo empty flag
    wire        spimx_6_fifo_full_o;              // bias spi fifo full flag
    wire        spimx_6_fifo_wr_ack_o;            // bias spi fifo write acknowledge
    // 7
    wire  [7:0] spimx_7_fifo_data_i;              // bias spi fifo data
    wire        spimx_7_fifo_wr_en_i;             // bias spi fifo write enable
    wire        spimx_7_fifo_empty_o;             // bias spi fifo empty flag
    wire        spimx_7_fifo_full_o;              // bias spi fifo full flag
    wire        spimx_7_fifo_wr_ack_o;            // bias spi fifo write acknowledge

    // SPI command fifo mux variables
    wire  [7:0] spimx_init_cmd_fifo_data_i;       // spi fifo data
    wire        spimx_init_cmd_fifo_wr_en_i;      // spi fifo write enable
    wire        spimx_init_cmd_fifo_empty_o;      // spi fifo empty flag
    wire        spimx_init_cmd_fifo_full_o;       // spi fifo full flag
    wire        spimx_init_cmd_fifo_wr_ack_o;     // spi fifo write acknowledge

    wire  [7:0] spimx_freq_cmd_fifo_data_i;       // spi fifo data
    wire        spimx_freq_cmd_fifo_wr_en_i;      // spi fifo write enable
    wire        spimx_freq_cmd_fifo_empty_o;      // spi fifo empty flag
    wire        spimx_freq_cmd_fifo_full_o;       // spi fifo full flag
    wire        spimx_freq_cmd_fifo_wr_ack_o;     // spi fifo write acknowledge

    wire  [7:0]  spimx_pwr_cmd_fifo_data_i;       // spi fifo data
    wire        spimx_pwr_cmd_fifo_wr_en_i;       // spi fifo write enable
    wire        spimx_pwr_cmd_fifo_empty_o;       // spi fifo empty flag
    wire        spimx_pwr_cmd_fifo_full_o;        // spi fifo full flag
    wire        spimx_pwr_cmd_fifo_wr_ack_o;      // spi fifo write acknowledge

    wire  [7:0] spimx_phs_cmd_fifo_data_i;        // spi fifo data
    wire        spimx_phs_cmd_fifo_wr_en_i;       // spi fifo write enable
    wire        spimx_phs_cmd_fifo_empty_o;       // spi fifo empty flag
    wire        spimx_phs_cmd_fifo_full_o;        // spi fifo full flag
    wire        spimx_phs_cmd_fifo_wr_ack_o;      // spi fifo write acknowledge

    wire  [7:0] spimx_ptn_cmd_fifo_data_i;        // spi fifo data
    wire        spimx_ptn_cmd_fifo_wr_en_i;       // spi fifo write enable
    wire        spimx_ptn_cmd_fifo_empty_o;       // spi fifo empty flag
    wire        spimx_ptn_cmd_fifo_full_o;        // spi fifo full flag
    wire        spimx_ptn_cmd_fifo_wr_ack_o;      // spi fifo write acknowledge

    wire  [7:0] spimx_bias_cmd_fifo_data_i;       // spi fifo data
    wire        spimx_bias_cmd_fifo_wr_en_i;      // spi fifo write enable
    wire        spimx_bias_cmd_fifo_empty_o;      // spi fifo empty flag
    wire        spimx_bias_cmd_fifo_full_o;       // spi fifo full flag
    wire        spimx_bias_cmd_fifo_wr_ack_o;     // spi fifo write acknowledge

    wire  [7:0] spimx_6_cmd_fifo_data_i;          // spi fifo data
    wire        spimx_6_cmd_fifo_wr_en_i;         // spi fifo write enable
    wire        spimx_6_cmd_fifo_empty_o;         // spi fifo empty flag
    wire        spimx_6_cmd_fifo_full_o;          // spi fifo full flag
    wire        spimx_6_cmd_fifo_wr_ack_o;        // spi fifo write acknowledge

    wire  [7:0] spimx_7_cmd_fifo_data_i;          // spi fifo data
    wire        spimx_7_cmd_fifo_wr_en_i;         // spi fifo write enable
    wire        spimx_7_cmd_fifo_empty_o;         // spi fifo empty flag
    wire        spimx_7_cmd_fifo_full_o;          // spi fifo full flag
    wire        spimx_7_cmd_fifo_wr_ack_o;        // spi fifo write acknowledge

    ///////////////////////////////////////////////////////
    // Arbiter to grant requests for SPI access
    // when available in round-robin order
    ///////////////////////////////////////////////////////
    wire        spi_arbiter_en = 1'b1;
    reg   [7:0] spi_arb_request_i = 8'h00;        // Bitmask, many requests at once
    wire  [7:0] spi_arb_grant_o;                  // Bitmask, only 1 bit asserted(granted) at a time
	
    arb8 spi_arbiter
    (
        .xclk(clk50),
        .xrst(rst),
        .arben(spi_arbiter_en),     // 1 -> SPI arbiter enabled, 0 -> not.
        .req(spi_arb_request_i),    // queue request, bitwise
        .xgnt(spi_arb_grant_o),     // grant, bitwise
        .gntidx(spi_mux_select)     // output as array index for mux selector
    );

    //////////////////////////////////////////////
    // Begin by writing opcodes to this fifo    //
    // When data is written, assert opcode      //
    // processor CE line. The CE line enables   //
    // all required modules to process the      //
    // opcode block, write the SPI data, and    //
    // write the response to the response fifo. //
    // Presently the CE line is represented by  //
    // the 'run' register above.                //
    // This module will indicate that all SPI   //
    // writes are done by writing the response  //
    // when all I/O is done.                    //
    //////////////////////////////////////////////
    // variables for input(opcode) FIFO
    wire        opcodes_fifo_rst_i = 0;
    reg         opcodes_fifo_clk_en = 0;
    reg         opcode_fifo_wr_en;
    wire        opcode_fifo_rd_en;
    reg   [7:0] opcode_fifo_data_in;
    wire  [7:0] opcode_fifo_data_out;
    wire  [9:0] opcode_fifo_count;
    wire        opcode_fifo_empty, opcode_fifo_full;
    wire        opcode_fifo_pf_full, opcode_fifo_pf_flag, opcode_fifo_pf_empty;
    // Instantiate VHDL fifo that the MMC slave core 
    // (or debugging array) is using to store opcodes
    swiss_army_fifo #(
      .USE_BRAM(1),
      .WIDTH(8),
      .DEPTH(512),
      .FILL_LEVEL_BITS(10),
      .PF_FULL_POINT(511),
      .PF_FLAG_POINT(256),
      .PF_EMPTY_POINT(1)
    ) mmc_opcodes(
        .sys_rst_n(rst_n),
        .sys_clk(clk50),
        .sys_clk_en(opcodes_fifo_clk_en),
        
        .reset_i(opcodes_fifo_rst_i),
        
        .fifo_wr_i(opcode_fifo_wr_en),
        .fifo_din(opcode_fifo_data_in),
        
        .fifo_rd_i(opcode_fifo_rd_en),
        .fifo_dout(opcode_fifo_data_out),
        
        .fifo_fill_level(opcode_fifo_count),
        .fifo_full(opcode_fifo_full),
        .fifo_empty(opcode_fifo_empty),
        .fifo_pf_full(opcode_fifo_pf_full),
        .fifo_pf_flag(opcode_fifo_pf_flag),
        .fifo_pf_empty(opcode_fifo_pf_empty)           
    );

    //////////////////////////////////////////////
    // The response to all opcodes will be 
    // written to this fifo. This fifo will be
    // used for status, echo, and measurement
    // opcodes.
    //////////////////////////////////////////////
    // variables for output/response/status FIFO
    wire        response_fifo_rst_i = 0;
    reg         response_fifo_clk_en = 0;
    wire        response_fifo_wr_en;
    wire        response_fifo_rd_en;
    wire  [7:0] response_fifo_data_in;
    wire  [7:0] response_fifo_data_out;
    wire  [9:0] response_fifo_count;
    wire        response_fifo_empty, response_fifo_full;
    wire        response_fifo_pf_full, response_fifo_pf_flag, response_fifo_pf_empty;
    // Instantiate VHDL fifo that the MMC slave core 
    // (or debugging array) is using to read response/status from
    swiss_army_fifo #(
      .USE_BRAM(1),
      .WIDTH(8),
      .DEPTH(512),
      .FILL_LEVEL_BITS(10),
      .PF_FULL_POINT(511),
      .PF_FLAG_POINT(256),
      .PF_EMPTY_POINT(1)
    ) opcode_response(
        .sys_rst_n(rst_n),
        .sys_clk(clk50),
        .sys_clk_en(response_fifo_clk_en),
        
        .reset_i(response_fifo_rst_i),
        
        .fifo_wr_i(response_fifo_wr_en),
        .fifo_din(response_fifo_data_in),
        
        .fifo_rd_i(response_fifo_rd_en),
        .fifo_dout(response_fifo_data_out),
        
        .fifo_fill_level(response_fifo_count),
        .fifo_full(response_fifo_full),
        .fifo_empty(response_fifo_empty),
        .fifo_pf_full(response_fifo_pf_full),
        .fifo_pf_flag(response_fifo_pf_flag),
        .fifo_pf_empty(response_fifo_pf_empty)           
    );

    ///////////////////////////////////////////////////////////////////////
    // Frequency FIFO
    // variables for frequency FIFO, written by opcode processor, 
    // read by frequency processor module
    ///////////////////////////////////////////////////////////////////////
    wire        freq_fifo_rst_i = 0;
    reg         freq_fifo_clk_en = 0;
    wire        freq_fifo_wr_en;
    wire        freq_fifo_rd_en;
    wire [31:0] freq_fifo_data_in;
    wire [31:0] freq_fifo_data_out;
    wire  [9:0] freq_fifo_count;    // 512 max
    wire        freq_fifo_empty, freq_fifo_full;
    wire        freq_fifo_pf_full, freq_fifo_pf_flag, freq_fifo_pf_empty;
    // Instantiate fifo that the opcode processor is using to store frequencies
    swiss_army_fifo #(
      .USE_BRAM(1),
      .WIDTH(32),
      .DEPTH(128),                   // 512 byte opcode block of only freq opcodes holds 85 frequencies
      .FILL_LEVEL_BITS(10),
      .PF_FULL_POINT(127),
      .PF_FLAG_POINT(64),
      .PF_EMPTY_POINT(1)
    ) freq_fifo(
        .sys_rst_n(rst_n),
        .sys_clk(clk50),
        .sys_clk_en(freq_fifo_clk_en),
        
        .reset_i(freq_fifo_rst_i),
        
        .fifo_wr_i(freq_fifo_wr_en),
        .fifo_din(freq_fifo_data_in),
        
        .fifo_rd_i(freq_fifo_rd_en),
        .fifo_dout(freq_fifo_data_out),
        
        .fifo_fill_level(freq_fifo_count),
        .fifo_full(freq_fifo_full),
        .fifo_empty(freq_fifo_empty),
        .fifo_pf_full(freq_fifo_pf_full),
        .fifo_pf_flag(freq_fifo_pf_flag),
        .fifo_pf_empty(freq_fifo_pf_empty)           
    );
              
    /////////////////////////////////////////////////////////////////////////////////////
    // Power FIFO                       
    // Instantiate fifo that the opcode processor is using to store power opcodes
    // Written by opcode processor, read by power processor module
    /////////////////////////////////////////////////////////////////////////////////////
    wire        pwr_fifo_rst_i = 0;
    reg         pwr_fifo_clk_en = 0;
    wire        pwr_fifo_wr_en;
    wire        pwr_fifo_rd_en;
    wire [31:0] pwr_fifo_data_in;
    wire [31:0] pwr_fifo_data_out;
    wire [15:0] pwr_fifo_count;
    wire        pwr_fifo_empty, pwr_fifo_full;
    wire        pwr_fifo_pf_full, pwr_fifo_pf_flag, pwr_fifo_pf_empty;
    swiss_army_fifo #(
      .USE_BRAM(1),
      .WIDTH(32),
      .DEPTH(128),                   // 512 byte opcode block of only pwr opcodes holds 85 powers
      .FILL_LEVEL_BITS(16),
      .PF_FULL_POINT(127),
      .PF_FLAG_POINT(64),
      .PF_EMPTY_POINT(1)
    ) power_fifo(
        .sys_rst_n(rst_n),
        .sys_clk(clk50),
        .sys_clk_en(pwr_fifo_clk_en),
        
        .reset_i(pwr_fifo_rst_i),
        
        .fifo_wr_i(pwr_fifo_wr_en),
        .fifo_din(pwr_fifo_data_in),
        
        .fifo_rd_i(pwr_fifo_rd_en),
        .fifo_dout(pwr_fifo_data_out),
        
        .fifo_fill_level(pwr_fifo_count),
        .fifo_full(pwr_fifo_full),
        .fifo_empty(pwr_fifo_empty),
        .fifo_pf_full(pwr_fifo_pf_full),
        .fifo_pf_flag(pwr_fifo_pf_flag),
        .fifo_pf_empty(pwr_fifo_pf_empty)           
    );

    /////////////////////////////////////////////////////////////////////////////////////
    // Pulse FIFO                       
    // Instantiate fifo that the opcode processor is using to store pulse opcodes
    // Written by opcode processor, read by pulse processor module (or pattern processor?)
    /////////////////////////////////////////////////////////////////////////////////////
    wire        pulse_fifo_rst_i = 0;
    reg         pulse_fifo_clk_en = 0;
    wire        pulse_fifo_wr_en;
    wire        pulse_fifo_rd_en;
    wire [63:0] pulse_fifo_data_in;
    wire [63:0] pulse_fifo_data_out;
    wire [15:0] pulse_fifo_count;
    wire        pulse_fifo_empty, pulse_fifo_full;
    wire        pulse_fifo_pf_full, pulse_fifo_pf_flag, pulse_fifo_pf_empty;
    swiss_army_fifo #(
      .USE_BRAM(1),
      .WIDTH(64),
      .DEPTH(128),                   // 512 byte opcode block of only pwr opcodes holds 85 powers
      .FILL_LEVEL_BITS(16),
      .PF_FULL_POINT(127),
      .PF_FLAG_POINT(64),
      .PF_EMPTY_POINT(1)
    ) pulse_fifo(
        .sys_rst_n(rst_n),
        .sys_clk(clk50),
        .sys_clk_en(pulse_fifo_clk_en),
        
        .reset_i(pulse_fifo_rst_i),
        
        .fifo_wr_i(pulse_fifo_wr_en),
        .fifo_din(pulse_fifo_data_in),
        
        .fifo_rd_i(pulse_fifo_rd_en),
        .fifo_dout(pulse_fifo_data_out),
        
        .fifo_fill_level(pulse_fifo_count),
        .fifo_full(pulse_fifo_full),
        .fifo_empty(pulse_fifo_empty),
        .fifo_pf_full(pulse_fifo_pf_full),
        .fifo_pf_flag(pulse_fifo_pf_flag),
        .fifo_pf_empty(pulse_fifo_pf_empty)           
    );

    /////////////////////////////////////////////////////////////////////////////////////
    // Bias FIFO                       
    // Instantiate fifo that the opcode processor is using to store bias opcodes
    // Written by opcode processor, read by bias processor module
    /////////////////////////////////////////////////////////////////////////////////////
    wire        bias_fifo_rst_i = 0;
    reg         bias_fifo_clk_en = 0;
    wire        bias_fifo_wr_en;
    wire        bias_fifo_rd_en;
    wire [15:0] bias_fifo_data_in;
    wire [15:0] bias_fifo_data_out;
    wire [9:0]  bias_fifo_count;
    wire        bias_fifo_empty, bias_fifo_full;
    wire        bias_fifo_pf_full, bias_fifo_pf_flag, bias_fifo_pf_empty;
    swiss_army_fifo #(
      .USE_BRAM(1),
      .WIDTH(16),
      .DEPTH(128),                   // 512 byte opcode block of only pwr opcodes holds 85 powers
      .FILL_LEVEL_BITS(10),
      .PF_FULL_POINT(127),
      .PF_FLAG_POINT(64),
      .PF_EMPTY_POINT(1)
    ) bias_fifo(
        .sys_rst_n(rst_n),
        .sys_clk(clk50),
        .sys_clk_en(bias_fifo_clk_en),
        
        .reset_i(bias_fifo_rst_i),
        
        .fifo_wr_i(bias_fifo_wr_en),
        .fifo_din(bias_fifo_data_in),
        
        .fifo_rd_i(bias_fifo_rd_en),
        .fifo_dout(bias_fifo_data_out),
        
        .fifo_fill_level(bias_fifo_count),
        .fifo_full(bias_fifo_full),
        .fifo_empty(bias_fifo_empty),
        .fifo_pf_full(bias_fifo_pf_full),
        .fifo_pf_flag(bias_fifo_pf_flag),
        .fifo_pf_empty(bias_fifo_pf_empty)           
    );

    //////////////////////////////////////////////////////////////////////
    // Pattern RAM, 64k initially. (Need to parameterize the size)
    // pulse and pattern opcodes write to pattern RAM.
    // pattern_sequencer runs pattern from pattern RAM
    //////////////////////////////////////////////////////////////////////
    wire        pattern_ram_wr_en; 
    reg         pattern_ram_en = 0;
    // shared bus, need arbiter? Used to load RAM
    // when pattern is running, continuously updated from pattern_sequencer 
    wire [23:0] pattern_ram_addr = 0; 
    wire [15:0] pattern_ram_data_in = 0; 
    wire [15:0] pattern_ram_data_out;
    wire [23:0] pattern_ram_count = 0;  // Must be non-0 to run patterns
    ptn_ram patterns(
        .clk(clk50), 
        .we(pattern_ram_wr_en), 
        .en(pattern_ram_en), 
        .addr(pattern_ram_addr), 
        .data_i(pattern_ram_data_in), 
        .data_o(pattern_ram_data_out)
    );

    // pulse processor requests a pattern run by asserting this line
    // this & other lines need an arbiter to control pattern sequencer
    wire        pulse_run_pattern;
    // client asserts this line to run pattern engine
    // this & other lines need an arbiter to control pattern sequencer
    wire        pattern_sequencer_run = 0;

    //////////////////////////////////////////////////////////////////
    // Pattern sequencer is at top level. It's the 'guts' of this core.
    // variable definitions are here. Implementation is below, after
    // all other modules except teh SPI processor.
    //////////////////////////////////////////////////////////////////
    // pattern engine asserts this line when a pattern is running
    wire        pattern_running;

    // Instantiate the opccode processor module
    // 'opcode_processor_en' flag enables opcode processor.
    // Opcode processor will remain enabled until opcode
    // fifo is empty and all SPI data has been written.
    opcodes processor(
        .clk(clk50),
        .rst(rst),
        .ce(opcode_processor_en),
        .opcode_fifo_i(opcode_fifo_data_out),   // opcode fifo in
        .rd_en_o(opcode_fifo_rd_en),            // opcode fifo read line
        .fifo_empty_i(opcode_fifo_empty),       // opcode fifo empty flag
        .opcode_fifo_count_i(opcode_fifo_count),// opcode fifo count

        .system_state_i(system_state),          // system_state, i.e. idle, running pattern, etc

        .response_o(response_fifo_data_in),             // response, into FIFO
        .response_wr_en_o(response_fifo_wr_en),         // response fifo write line
        .response_fifo_empty_i(response_fifo_empty),    // response fifo empty line 
        .response_fifo_full_i(response_fifo_full),      // response fifo full flag
        .response_ready_o(response_ready),              // response is ready

        .frequency_o(freq_fifo_data_in),        // frequency output in MHz, into FIFO
        .frq_wr_en_o(freq_fifo_wr_en),          // freq fifo write line
        .frq_fifo_empty_i(freq_fifo_empty),     // freq fifo empty line 
        .frq_fifo_full_i(freq_fifo_full),       // frequency fifo full flag

        .power_o(pwr_fifo_data_in),             // desired power output in dBm, into FIFO
        .pwr_wr_en_o(pwr_fifo_wr_en),           // power fifo write line
        .pwr_fifo_empty_i(pwr_fifo_empty),      // power fifo empty line 
        .pwr_fifo_full_i(pwr_fifo_full),        // power fifo full flag

        .pulse_o(pulse_fifo_data_in),           // to fifo, pulse opcode
        .pulse_wr_en_o(pulse_fifo_wr_en),       // write pulse fifo enable
        .pulse_fifo_empty_i(pulse_fifo_empty),  // pulse fifo empty flag
        .pulse_fifo_full_i(pulse_fifo_full),    // pulse fifo full flag

        .bias_o(bias_fifo_data_in),             // to fifo, bias opcode
        .bias_wr_en_o(bias_fifo_wr_en),         // write bias fifo enable
        .bias_fifo_empty_i(bias_fifo_empty),    // bias fifo empty flag
        .bias_fifo_full_i(bias_fifo_full),      // bias fifo full flag

        // save the last programmed values for use when processing pulse opcodes
        .last_power0(last_power[0]),
        .last_power1(last_power[1]),
        .last_power2(last_power[2]),
        .last_power3(last_power[3]),
        .last_power4(last_power[4]),
        .last_power5(last_power[5]),
        .last_frequency0(last_frequency[0]),
        .last_frequency1(last_frequency[1]),
        .last_frequency2(last_frequency[2]),
        .last_frequency3(last_frequency[3]),
        .last_frequency4(last_frequency[4]),
        .last_frequency5(last_frequency[5]),
        .last_bias0(last_bias[0]),
        .last_bias1(last_bias[1]),
        .last_bias2(last_bias[2]),
        .last_bias3(last_bias[3]),

        .opcode_counter_o(opcode_counter),                     
        .status_o(opcode_processor_status),     // done with block, 1 is Success, else 8-bit error code
        .busy_o(opcode_processor_busy)
        );

    // Debugging only, Array of opcode data, load from file, then into FIFO   
    reg  [7:0] oplist [0: `MMC_SECTOR_SIZE-1];
    reg  [9:0] count;

    // SPI request fifo, request a write to an SPI device.
    // Data for the device will already have been written into the
    // SPI data fifo.
    //
    // 'opcode_processor_en' flag enables opcode processor and all
    // its dependents including this instance
    //
    // variables for SPI write request FIFO, written by frequency, power, bias, 
    // pulse, phase, and/or opcode processor, etc modules, 
    // Monitored by SPI master to perform next requested SPI write
    // Each entry will be a request to write a specific SPI device. The data
    // for the device will have already been queued in the specific FIFO.
    //
    // Supported devices are currently:
    //  SPI_DDS
    //  SPI_RSYN
    //  SPI_MSYN
    //  SPI_FR
    //  SPI_MBW
    wire        spiqueue_wr_en;
    wire        spiqueue_wr_ack;
    reg         spiqueue_rd_en;
    wire        spiqueue_rd_valid;
    wire  [7:0] spiqueue_data_in;
    wire  [7:0] spiqueue_data_out;
    wire        spiqueue_empty, spiqueue_full;
    // 28-Jun Must use dual-clock fifo (mistakenly thought swiss_army_fifo was dual-clock)    
    fifo_dualclock spiwr_fifo (
        .rst(rst),                // input wire rst
        .wr_clk(clk50),           // input wire wr_clk
        .rd_clk(clk100),          // input wire rd_clk
        .din(spiqueue_data_in),   // input wire [7 : 0] din
        .wr_en(spiqueue_wr_en),   // input wire wr_en
        .rd_en(spiqueue_rd_en),   // input wire rd_en
        .dout(spiqueue_data_out), // output wire [7 : 0] dout
        .full(spiqueue_full),     // output wire full
        .wr_ack(spiqueue_wr_ack), // output wire wr_ack
        .empty(spiqueue_empty),   // output wire empty
        .valid(spiqueue_rd_valid) // output wire valid
    );

    // variables for SPI FIFO, written by frequency module, read by SPI processor
    // 28-Jun change to dual-clock fifo. Use single data fifo for all SPI data.
    wire        spi_fifo_wr_en;
    wire        spi_fifo_wr_ack;
    reg         spi_fifo_rd_en;
    wire        spi_fifo_rd_valid;
    wire  [7:0] spi_fifo_data_in;
    wire  [7:0] spi_fifo_data_out;
    wire        spi_fifo_empty, spi_fifo_full;
    // 28-Jun Must use dual-clock fifo (mistakenly thought swiss_army_fifo was dual-clock)    
    // Use single fifo for all SPI data
    fifo_dualclock spidata_fifo (
        .rst(rst),                // input wire rst
        .wr_clk(clk50),           // input wire wr_clk
        .rd_clk(clk100),           // input wire rd_clk
        .din(spi_fifo_data_in),   // input wire [7 : 0] din
        .wr_en(spi_fifo_wr_en),   // input wire wr_en
        .rd_en(spi_fifo_rd_en),   // input wire rd_en
        .dout(spi_fifo_data_out), // output wire [7 : 0] dout
        .full(spi_fifo_full),     // output wire full
        .wr_ack(spi_fifo_wr_ack), // output wire wr_ack
        .empty(spi_fifo_empty),   // output wire empty
        .valid(spi_fifo_rd_valid) // output wire valid
    );    

    // Frequency processing module
    frequency   set_freq(
        .clk(clk50),
        .rst(rst),

        .freq_en(opcode_processor_en),
        .spi_processor_idle(spi_idle), // Only queue SPI data when SPI processor is idle
        
        .x7_mode(x7_mode),
        .high_speed_syn(hi_spd_syn_mode),

        .freq_fifo_i(freq_fifo_data_out),       // frequency fifo
        .freq_fifo_rd_en_o(freq_fifo_rd_en),    // frequency fifo read line
        .freq_fifo_empty_i(freq_fifo_empty),    // frequency fifo empty flag
        .freq_fifo_count_i(freq_fifo_count),    // fifo count, for debug message only

        // Only 1 SPI write is valid at a time so single SPI data fifo
        // FREQ is mux index 1
        .spi_o(spimx_freq_fifo_data_i),
        .spi_wr_en_o(spimx_freq_fifo_wr_en_i), 
        .spi_fifo_empty_i(spimx_freq_fifo_empty_o),
        .spi_fifo_full_i(spimx_freq_fifo_full_o),
        .spi_wr_ack_i(spimx_freq_fifo_wr_ack_o),

        // SPI Write request fifo, FREQ is mux index 1
        .spiwr_queue_data_o(spimx_freq_cmd_fifo_data_i),
        .spiwr_queue_wr_en_o(spimx_freq_cmd_fifo_wr_en_i),
        .spiwr_queue_fifo_empty_i(spimx_freq_cmd_fifo_empty_o),
        .spiwr_queue_fifo_full_i(spimx_freq_cmd_fifo_full_o),
        .spiwr_queue_wr_ack_i(spimx_freq_cmd_fifo_wr_ack_o),

        .status_o(freq_status),            // SUCCESS when done, or an error code
        .busy_o(freq_processor_busy)
    );

    ////////////////////////////////////////////////////////////
    // Instantiate power processor module
    ////////////////////////////////////////////////////////////
    power set_power(
        .clk(clk50),
        .rst(rst),
        
        .power_en(opcode_processor_en),
        .spi_processor_idle(spi_idle),      // this needs to be replaced with arbiter
    
        .x7_mode(x7_mode),                  // S4 is a limited version of X7, true if X7, false=S4
        .high_speed_syn(hi_speed_syn),      // synthesiser mode, true=high speed syn mode, false=high accuracy mode
    
        // Power opcode(s) are in input fifo
        // Power opcode byte 0 is channel#,
        // byte 1 unused, byte 2 is 8 lsb's,
        // byte 3 is 8 msb's of Q7.8 format power
        // in dBm. (Positive values only)
        .power_fifo_i(pwr_fifo_data_out),            // power fifo
        .power_fifo_rd_en_o(pwr_fifo_rd_en),      // fifo read line
        .power_fifo_empty_i(pwr_fifo_empty),      // fifo empty flag
        .power_fifo_count_i(pwr_fifo_count),        // fifo count, for debug message only
    
        // SPI data is written to dual-clock fifo, then SPI write request is queued.
        // spi_processor_idle is asserted when write is finished by top level.
        .spi_o(spimx_pwr_fifo_data_i),
        .spi_wr_en_o(spimx_pwr_fifo_wr_en_i),
        .spi_fifo_empty_i(spimx_pwr_fifo_empty_o),
        .spi_fifo_full_i(spimx_pwr_fifo_full_o),
        .spi_wr_ack_i(spimx_pwr_fifo_wr_ack_o),
    
        // SPI Write request fifo, POWER is mux index 2
        .spiwr_queue_data_o(spimx_pwr_cmd_fifo_data_i), //spiqueue_data_in),       // queue request for write
        .spiwr_queue_wr_en_o(spimx_pwr_cmd_fifo_wr_en_i), //spiqueue_wr_en),       // spi fifo write enable
        .spiwr_queue_fifo_empty_i(spimx_pwr_cmd_fifo_empty_o), //spiqueue_empty),  // spi fifo empty flag
        .spiwr_queue_fifo_full_i(spimx_pwr_cmd_fifo_full_o), //spiqueue_full),     // spi fifo full flag
        .spiwr_queue_wr_ack_i(spimx_pwr_cmd_fifo_wr_ack_o), //spiqueue_wr_ack),    // spi fifo write acknowledge
    
        .status_o(power_status),            // SUCCESS when done, or an error code
        .busy_o(power_processor_busy)
    );

    // Module to initialize X7 SPI hardware
    reg         run_init = 0;
    wire        init_done;
    wire  [7:0] init_status;
    initialize init_x7(
        .rst(rst),
        .clk(clk50),
        .init_enable(run_init),
        .spi_processor_idle(spi_idle),

        // SPI DDS data fifo, INIT is mux index 0     
        .spi_o(spimx_init_fifo_data_i),
        .spi_wr_en_o(spimx_init_fifo_wr_en_i),
        .spi_fifo_empty_i(spimx_init_fifo_empty_o),
        .spi_fifo_full_i(spimx_init_fifo_full_o),
        .spi_wr_ack_i(spimx_init_fifo_wr_ack_o),

        // SPI Write request fifo, INIT is mux index 0
        .spiwr_queue_data_o(spimx_init_cmd_fifo_data_i), //spiqueue_data_in),      // queue request for write
        .spiwr_queue_wr_en_o(spimx_init_cmd_fifo_wr_en_i), //spiqueue_wr_en),      // spi fifo write enable
        .spiwr_queue_fifo_empty_i(spimx_init_cmd_fifo_empty_o), //spiqueue_empty), // spi fifo empty flag
        .spiwr_queue_fifo_full_i(spimx_init_cmd_fifo_full_o), //spiqueue_full),    // spi fifo full flag
        .spiwr_queue_wr_ack_i(spimx_init_cmd_fifo_wr_ack_o), //spiqueue_wr_ack),   // spi fifo write acknowledge
    
        .init_done(init_done),              // signal caller all done
        .status_o(init_status)              // SUCCESS when done, or an error code
        );

    /////////////////////////////////////////////////////////////////
    // Mux for SPI processor, up to 8 selections, 5 used initially //
    /////////////////////////////////////////////////////////////////
    spi_mux spi_fifo_mux(
        .clk(clk50),
        .rst(rst),
        .enable_i(spi_fifo_mux_enable),
    
        .mux_select_i(spi_mux_select),                 // Mux selector bitmask, d0-d7

        // SPI data is written to dual-clock fifo, then SPI write request is queued.
        // spi_processor_idle is asserted when write is finished by top level.
        .spi_data_o(spi_fifo_data_in),                 // spi fifo data
        .spi_wr_en_o(spi_fifo_wr_en),                  // spi fifo write enable
        .spi_fifo_empty_i(spi_fifo_empty),             // spi fifo empty flag
        .spi_fifo_full_i(spi_fifo_full),               // spi fifo full flag
        .spi_wr_ack_i(spi_fifo_wr_ack),                // spi fifo write acknowledge

        // Mux the SPI processor command queue fifo
        .spiwr_queue_data_o(spiqueue_data_in),         // queue request for write
        .spiwr_queue_wr_en_o(spiqueue_wr_en),          // spiqueue fifo write enable
        .spiwr_queue_fifo_empty_i(spiqueue_empty),     // spiqueue fifo empty flag
        .spiwr_queue_fifo_full_i(spiqueue_full),       // spiqueue fifo full flag
        .spiwr_queue_wr_ack_i(spiqueue_wr_ack),        // spiqueue fifo write acknowledge

        // Mux connections
        .fifo_data_i0(spimx_init_fifo_data_i),         // spi fifo data
        .fifo_wr_en_i0(spimx_init_fifo_wr_en_i),       // spi fifo write enable
        .fifo_empty_o0(spimx_init_fifo_empty_o),       // spi fifo empty flag
        .fifo_full_o0(spimx_init_fifo_full_o),         // spi fifo full flag
        .fifo_wr_ack_o0(spimx_init_fifo_wr_ack_o),     // spi fifo write acknowledge

        .fifo_data_i1(spimx_freq_fifo_data_i),         // spi fifo data
        .fifo_wr_en_i1(spimx_freq_fifo_wr_en_i),       // spi fifo write enable
        .fifo_empty_o1(spimx_freq_fifo_empty_o),       // spi fifo empty flag
        .fifo_full_o1(spimx_freq_fifo_full_o),         // spi fifo full flag
        .fifo_wr_ack_o1(spimx_freq_fifo_wr_ack_o),     // spi fifo write acknowledge

        .fifo_data_i2(spimx_pwr_fifo_data_i),          // spi fifo data
        .fifo_wr_en_i2(spimx_pwr_fifo_wr_en_i),        // spi fifo write enable
        .fifo_empty_o2(spimx_pwr_fifo_empty_o),        // spi fifo empty flag
        .fifo_full_o2(spimx_pwr_fifo_full_o),          // spi fifo full flag
        .fifo_wr_ack_o2(spimx_pwr_fifo_wr_ack_o),      // spi fifo write acknowledge

        .fifo_data_i3(spimx_phs_fifo_data_i),          // spi fifo data
        .fifo_wr_en_i3(spimx_phs_fifo_wr_en_i),        // spi fifo write enable
        .fifo_empty_o3(spimx_phs_fifo_empty_o),        // spi fifo empty flag
        .fifo_full_o3(spimx_phs_fifo_full_o),          // spi fifo full flag
        .fifo_wr_ack_o3(spimx_phs_fifo_wr_ack_o),      // spi fifo write acknowledge

        .fifo_data_i4(spimx_ptn_fifo_data_i),          // spi fifo data
        .fifo_wr_en_i4(spimx_ptn_fifo_wr_en_i),        // spi fifo write enable
        .fifo_empty_o4(spimx_ptn_fifo_empty_o),        // spi fifo empty flag
        .fifo_full_o4(spimx_ptn_fifo_full_o),          // spi fifo full flag
        .fifo_wr_ack_o4(spimx_ptn_fifo_wr_ack_o),      // spi fifo write acknowledge

        .fifo_data_i5(spimx_bias_fifo_data_i),         // spi fifo data
        .fifo_wr_en_i5(spimx_bias_fifo_wr_en_i),       // spi fifo write enable
        .fifo_empty_o5(spimx_bias_fifo_empty_o),       // spi fifo empty flag
        .fifo_full_o5(spimx_bias_fifo_full_o),         // spi fifo full flag
        .fifo_wr_ack_o5(spimx_bias_fifo_wr_ack_o),     // spi fifo write acknowledge

        .fifo_data_i6(spimx_6_fifo_data_i),            // spi fifo data
        .fifo_wr_en_i6(spimx_6_fifo_wr_en_i),          // spi fifo write enable
        .fifo_empty_o6(spimx_6_fifo_empty_o),          // spi fifo empty flag
        .fifo_full_o6(spimx_6_fifo_full_o),            // spi fifo full flag
        .fifo_wr_ack_o6(spimx_6_fifo_wr_ack_o),        // spi fifo write acknowledge

        .fifo_data_i7(spimx_7_fifo_data_i),            // spi fifo data
        .fifo_wr_en_i7(spimx_7_fifo_wr_en_i),          // spi fifo write enable
        .fifo_empty_o7(spimx_7_fifo_empty_o),          // spi fifo empty flag
        .fifo_full_o7(spimx_7_fifo_full_o),            // spi fifo full flag
        .fifo_wr_ack_o7(spimx_7_fifo_wr_ack_o),        // spi fifo write acknowledge

        // Mux'd commands
        .cmd_fifo_data_i0(spimx_init_cmd_fifo_data_i),       // spi queue fifo data
        .cmd_fifo_wr_en_i0(spimx_init_cmd_fifo_wr_en_i),     // spi queue fifo write enable
        .cmd_fifo_empty_o0(spimx_init_cmd_fifo_empty_o),     // spi queue fifo empty flag
        .cmd_fifo_full_o0(spimx_init_cmd_fifo_full_o),       // spi queue fifo full flag
        .cmd_fifo_wr_ack_o0(spimx_init_cmd_fifo_wr_ack_o),   // spi queue fifo write acknowledge
        
        .cmd_fifo_data_i1(spimx_freq_cmd_fifo_data_i),       // spi queue fifo data
        .cmd_fifo_wr_en_i1(spimx_freq_cmd_fifo_wr_en_i),     // spi queue fifo write enable
        .cmd_fifo_empty_o1(spimx_freq_cmd_fifo_empty_o),     // spi queue fifo empty flag
        .cmd_fifo_full_o1(spimx_freq_cmd_fifo_full_o),       // spi queue fifo full flag
        .cmd_fifo_wr_ack_o1(spimx_freq_cmd_fifo_wr_ack_o),   // spi queue fifo write acknowledge

        .cmd_fifo_data_i2(spimx_pwr_cmd_fifo_data_i),        // spi queue fifo data
        .cmd_fifo_wr_en_i2(spimx_pwr_cmd_fifo_wr_en_i),      // spi queue fifo write enable
        .cmd_fifo_empty_o2(spimx_pwr_cmd_fifo_empty_o),      // spi queue fifo empty flag
        .cmd_fifo_full_o2(spimx_pwr_cmd_fifo_full_o),        // spi queue fifo full flag
        .cmd_fifo_wr_ack_o2(spimx_pwr_cmd_fifo_wr_ack_o),    // spi queue fifo write acknowledge

        .cmd_fifo_data_i3(spimx_phs_cmd_fifo_data_i),        // spi queue fifo data
        .cmd_fifo_wr_en_i3(spimx_phs_cmd_fifo_wr_en_i),      // spi queue fifo write enable
        .cmd_fifo_empty_o3(spimx_phs_cmd_fifo_empty_o),      // spi queue fifo empty flag
        .cmd_fifo_full_o3(spimx_phs_cmd_fifo_full_o),        // spi queue fifo full flag
        .cmd_fifo_wr_ack_o3(spimx_phs_cmd_fifo_wr_ack_o),    // spi queue fifo write acknowledge

        .cmd_fifo_data_i4(spimx_ptn_cmd_fifo_data_i),        // spi queue fifo data
        .cmd_fifo_wr_en_i4(spimx_phs_cmd_fifo_wr_en_i),      // spi queue fifo write enable
        .cmd_fifo_empty_o4(spimx_phs_cmd_fifo_empty_o),      // spi queue fifo empty flag
        .cmd_fifo_full_o4(spimx_phs_cmd_fifo_full_o),        // spi queue fifo full flag
        .cmd_fifo_wr_ack_o4(spimx_phs_cmd_fifo_wr_ack_o),    // spi queue fifo write acknowledge

        .cmd_fifo_data_i5(spimx_bias_cmd_fifo_data_i),       // spi queue fifo data
        .cmd_fifo_wr_en_i5(spimx_bias_cmd_fifo_wr_en_i),     // spi queue fifo write enable
        .cmd_fifo_empty_o5(spimx_bias_cmd_fifo_empty_o),     // spi queue fifo empty flag
        .cmd_fifo_full_o5(spimx_bias_cmd_fifo_full_o),       // spi queue fifo full flag
        .cmd_fifo_wr_ack_o5(spimx_bias_cmd_fifo_wr_ack_o),   // spi queue fifo write acknowledge

        .cmd_fifo_data_i6(spimx_6_cmd_fifo_data_i),          // spi queue fifo data
        .cmd_fifo_wr_en_i6(spimx_6_cmd_fifo_wr_en_i),        // spi queue fifo write enable
        .cmd_fifo_empty_o6(spimx_6_cmd_fifo_empty_o),        // spi queue fifo empty flag
        .cmd_fifo_full_o6(spimx_6_cmd_fifo_full_o),          // spi queue fifo full flag
        .cmd_fifo_wr_ack_o6(spimx_6_cmd_fifo_wr_ack_o),      // spi queue fifo write acknowledge

        .cmd_fifo_data_i7(spimx_7_cmd_fifo_data_i),          // spi queue fifo data
        .cmd_fifo_wr_en_i7(spimx_7_cmd_fifo_wr_en_i),        // spi queue fifo write enable
        .cmd_fifo_empty_o7(spimx_7_cmd_fifo_empty_o),        // spi queue fifo empty flag
        .cmd_fifo_full_o7(spimx_7_cmd_fifo_full_o),          // spi queue fifo full flag
        .cmd_fifo_wr_ack_o7(spimx_7_cmd_fifo_wr_ack_o)       // spi queue fifo write acknowledge
        );

    ///////////////////////////////////////////////////////////
    // Pulse processor, reads pulse fifo,
    // writes pattern RAM. Executes pattern once.
    ///////////////////////////////////////////////////////////
    wire [31:0] ptn_opcode_counter;
    always @(*) begin
        ptn_opcodes_processed = ptn_opcode_counter;
    end // always @ begin
   
    pulse pulse_processor(
        .clk(clk50),
        .rst(rst),
    
        .pulse_en(opcode_processor_en),

        .x7_mode(x7_mode),
        .high_speed_syn(high_speed_syn),

        // use the last programmed values when processing pulse opcodes
        .last_power0(last_power[0]),
        .last_power1(last_power[1]),
        .last_power2(last_power[2]),
        .last_power3(last_power[3]),
        .last_power4(last_power[4]),
        .last_power5(last_power[5]),
        .last_frequency0(last_frequency[0]),
        .last_frequency1(last_frequency[1]),
        .last_frequency2(last_frequency[2]),
        .last_frequency3(last_frequency[3]),
        .last_frequency4(last_frequency[4]),
        .last_frequency5(last_frequency[5]),
        .last_bias0(last_bias[0]),
        .last_bias1(last_bias[1]),
        .last_bias2(last_bias[2]),
        .last_bias3(last_bias[3]),

        // Pulse opcode(s) are in input fifo
        .pulse_fifo_i(pulse_fifo_data_out),
        .pulse_fifo_rd_en_o(pulse_fifo_rd_en),
        .pulse_fifo_empty_i(pulse_fifo_empty),
        .pulse_fifo_count_i(pulse_fifo_count),

        // **Pulse will generate a pattern and run it, rather than write SPI bytes**
        .pattern_ram_wr_en(pattern_ram_wr_en),
        .pattern_ram_addr(pattern_ram_addr), 
        .pattern_ram_data_in(pattern_ram_data_in),
        .pattern_ram_count_o(pattern_ram_count), 

        .request_run_pattern(pulse_run_pattern),
        .pattern_running(pattern_running),

        .ptn_opcodes_processed_o(ptn_opcode_counter),
        .status_o(pulse_status),
        .busy_o(pulse_processor_busy)
    );

    ///////////////////////////////////////////////////////////
    // Bias processor, reads bias fifo,
    // writes SPI data after arbiter grants
    // request for SPI bus.
    ///////////////////////////////////////////////////////////
    bias bias_processor(
        .clk(clk50),
        .rst(rst),
    
        .bias_en(opcode_processor_en),

        .x7_mode(x7_mode),
        .high_speed_syn(high_speed_syn),

        // ** the names of these fifo's are too close, they're different fifo's**

        // Bias opcode(s) are in input fifo
        .bias_fifo_i(bias_fifo_data_out),
        .bias_fifo_rd_en_o(bias_fifo_rd_en),
        .bias_fifo_empty_i(bias_fifo_empty),
        .bias_fifo_count_i(bias_fifo_count),

        // SPI DDS data fifo, BIAS is mux index 5     
        .spi_o(spimx_bias_fifo_data_i),                // spi fifo data
        .spi_wr_en_o(spimx_bias_fifo_wr_en_i),         // spi fifo write enable
        .spi_fifo_empty_i(spimx_bias_fifo_empty_o),    // spi fifo empty flag
        .spi_fifo_full_i(spimx_bias_fifo_full_o),      // spi fifo full flag
        .spi_wr_ack_i(spimx_bias_fifo_wr_ack_o),       // spi fifo write acknowledge

        // SPI Write request fifo, INIT is mux index 0
        .spiwr_queue_data_o(spimx_bias_cmd_fifo_data_i), //spiqueue_data_in),      // queue request for write
        .spiwr_queue_wr_en_o(spimx_bias_cmd_fifo_wr_en_i), //spiqueue_wr_en),       // spi fifo write enable
        .spiwr_queue_fifo_empty_i(spimx_bias_cmd_fifo_empty_o), //spiqueue_empty),  // spi fifo empty flag
        .spiwr_queue_fifo_full_i(spimx_bias_cmd_fifo_full_o), //spiqueue_full),    // spi fifo full flag
        .spiwr_queue_wr_ack_i(spimx_bias_cmd_fifo_wr_ack_o), //spiqueue_wr_ack),     // spi fifo write acknowledge

        .status_o(pulse_status),
        .busy_o(bias_processor_busy)
    );

    //////////////////////////////////////////////////////////////////
    // Pattern sequencer is at top level(here). It's the 'guts' of this core.
    //
    // Load pattern RAM with opcode(s), set pattern_ram_addr to 
    // starting address, assert 'run' line. pattern_ram_en must stay 
    // asserted while pattern runs. Seems like bad design, when 
    // caller asserts pattern_sequencer_run, pattern sequencer 
    // should enable pattern RAM?
    //
    // Initially, process opcodes, one per 100ns pattern tick.
    //////////////////////////////////////////////////////////////////
    // pattern sequencer states
//    `define PATTERN_IDLE            0
//    `define PATTERN_QUEUEING_OPC    1
//    `define PATTERN_WAIT_NEXT       2
    
//    reg [23:0]  pattern_sequencer_addr;
//    localparam  PATTERN_COUNTDOWN    = 5;    // 50MHz main clock to 10MHz conversion
//    reg [23:0]  pattern_counter;
//    //reg [39:0]  next_opcode;
//    reg [7:0]   pattern_state = `PATTERN_IDLE;
//    // This always block fetches the next pattern opcode,
//    // checks for overrun. pattern_state must always be
//    // `PATTERN_IDLE 
//    always @(posedge clk50) begin
//        if(rst) begin
//            pattern_sequencer_status <= 0;
//            pattern_counter <= 0;
//            next_opcode <= `PATTERN_NOOP;
//            pattern_state <= `PATTERN_IDLE;
//        end
//        else begin
//            case(pattern_state)
//            `PATTERN_IDLE: begin
//                 if (pattern_sequencer_run && 
//                     pattern_ram_count > 0) begin
//                    // begin running the pattern, load the opcode fifo
//                    // use power opcode, value should be from last programmed power value?
//                    if(pattern_ram_data_out != `PATTERN_NOOP) begin
//                        opcodes_fifo_clk_en <= 1;
//                        opcode_fifo_wr_en <= 1;
//                        opcode_fifo_data_in <= ;
                    
                    
                    
//                    end
                    
                    
                    
                    
                    
                    
                    
                    
                    
//                    pattern_state <= `PATTERN_QUEUEING_OPC;
        
//                    // pattern tick is 100ns, every 5 ticks of 50MHz clock
//                    if(pattern_counter > 0 && 
//                        (pattern_counter % PATTERN_COUNTDOWN) == 0) begin
        
////                        // Check for overrun, pattern_state must be PATTERN_IDLE 
////                        // when fetching next opcode
////                        if(pattern_state != `PATTERN_IDLE) begin
////                            pattern_state <= `PATTERN_IDLE;
////                            pattern_sequencer_run <= 0;
////                            pattern_sequencer_status <= `ERR_PATTERN_OVERRUN;
////                        end
//                        // grab next opcode from pattern RAM & execute
//                        next_opcode <= pattern_ram_data_out;
//                        pattern_counter <= pattern_counter + 1;
//                        pattern_ram_addr <= pattern_ram_addr + 1;
//                    end
//                end
//            end
//            `PATTERN_QUEUEING_OPC: begin
            
            
//            end
//            `PATTERN_WAIT_NEXT: begin
            
//            end
        
        
//    end


    // SPI processor idle flag
    assign spi_idle = (spi_state == `SPI_IDLE && spiqueue_empty && spi_fifo_empty);

    // Initialization for prototyping, testing 
    initial
    begin
        for (count = 0; count < `MMC_SECTOR_SIZE; count = count +1)
        begin
            oplist[count] = 0;   // NULL terminated opcode block
        end
        // TBD: Bogus, assumes we're running from project_1/project_1.sim/sim_1/behav
        // Need Vivado/environment variable here for path
        `ifdef XILINX_SIMULATOR
            $readmemh("../../../project_1.srcs/sources_1/opcodes.txt", oplist);
        `else
            $readmemh("opcodes.txt", oplist);    
            // NG?? $readmemh({{`SRCFILES},"frequencies.txt"}, oplist); // define SRCFILES in 'SimulationSettings" - Compilation tab
        `endif
        idx = 0;

        opcode_fifo_wr_en = 0;
    end

    // Create a low-true synchronous reset signal, VHDL FIFO uses low-true RST
    assign rst = RST;
    assign rst_n = ~rst;

    // For displaying output with LED's
//    reg [31:0]  arty_interval1 = `MS500;
//    reg [31:0]  arty_interval2 = `MS500 + `MS500;
//    reg [31:0]  arty_interval3 = `MS500 + `MS500 + `MS500;
//    reg [31:0]  arty_interval4 = `MS500 + `MS500 + `MS500 + `MS500;
//    reg [31:0]  clk_counter = 32'h00000000;
    // cut times for scoping Arty JD SPI outputs
    reg [31:0]  arty_interval1 = `MS001;    // 1.5ms
    reg [31:0]  arty_interval2 = `MS001+1;
    reg [31:0]  arty_interval3 = `MS001+2;
    reg [31:0]  arty_interval4 = `MS001+3;
    reg [31:0]  clk_counter = 32'h00000000;

    // "main" & prototyping/testing loop.
    always @(posedge clk50)
    begin
        if( rst )
        begin
            LED <= 4'hf;
            system_state <= `STATE_RESET;
        end
        else begin
            if(system_state & `STATE_RESET) begin
                system_state <= (system_state & ~(`STATE_RESET)) | `STATE_INITIALIZING;
                // request from arbiter
                spi_arb_request_i <= `INIT_SPI; // Initial request                
            end
            else if(system_state & `STATE_INITIALIZING) begin
                if(run_init == 0) begin
                    if(spi_arb_grant_o == `INIT_SPI)
                        run_init <= 1;  // Start when arb has granted us the SPI processor
                end
                else if(init_done) begin
                    system_state <= (system_state & ~(`STATE_INITIALIZING)) | `STATE_INITIALIZED;
                    spi_arb_request_i <= spi_arb_request_i & (~`INIT_SPI); // Done, clear our request                
                    run_init <= 0;
                end
            end

            // Debugging opcode processor, run=0 to load opcode FIFO from debug
            // text file. Once file loaded into FIFO, set run to 1 to start 
            // opcode processor.
            if(run == 0)
            begin
                //LED <= 4'h0;
                // 02-Apr attempt to run opcode processor from top.v
                // Load the opcode FIFO, then let opcode processor run
                // repeat every few seconds, counting total opcodes processed   
                if(opcode_fifo_full == 1)
                begin
                    opcode_fifo_wr_en <= 0;
                    if(system_state & `STATE_INITIALIZED) begin //    init_done) begin
                        // request SPI processor, wait for grant
                        if(!(spi_arb_request_i & `FREQ_SPI))
                            spi_arb_request_i <= `FREQ_SPI; // Initial request
                        else if(spi_arb_grant_o == `FREQ_SPI) begin
                            opcode_processor_en <= 1;   // enable opcode processor
                            // these should move to an always block, following opcode_processor_en.
                            // Would add a clock cycle, fix this later
                            freq_fifo_clk_en <= 1;      // enable frequency fifo
                            pwr_fifo_clk_en <= 1;       // enable power fifo
                            pulse_fifo_clk_en <= 1;     // enable pulse fifo
                            pattern_ram_en <= 1;
                            bias_fifo_clk_en <= 1;      // enable bias fifo
                            run <= 1;
                        end
                    end
                end
                else
                begin
                    if(opcode_fifo_wr_en == 0)
                    begin
                        // opcode fifo load starts here
                        opcodes_fifo_clk_en <= 1;
                        response_fifo_clk_en <= 1;
                        opcode_fifo_wr_en <= 1;
                    end    
        
                    // load the opcode fifo from the array
                    opcode_fifo_data_in <= oplist[idx];
                    idx <= idx + 1;
                end
            end
            else
            begin
                // run == 1 AND frequency fifo has its data
                // Show count of opcodes processed every 2 seconds by flashing
                // 4 bytes(16 bit counter) 300ms apart, MSB/LSB
                // 250MS tick to display info w/Arty LED's
                clk_counter <= clk_counter + 32'h00000001;
            `ifdef XILINX_SIMULATOR
                if(clk_counter == `MS001)
            `else
                if(clk_counter == arty_interval1)
            `endif
                begin
                    LED <= opcodes_processed[15:12];        
                    if(arty_interval1 == `MS500)
                        arty_interval1 = `MS5000;
                end
            `ifdef XILINX_SIMULATOR
                else if(clk_counter == `MS001+1)
            `else
                else if(clk_counter == arty_interval2)
            `endif
                begin
                    LED <= opcodes_processed[11:8];        
                    arty_interval2 <= arty_interval1 + `MS500;
                end
            `ifdef XILINX_SIMULATOR
                else if(clk_counter == `MS001+2)
            `else
                else if(clk_counter == arty_interval3)
            `endif
                begin
                    LED <= opcodes_processed[7:4];        
                    arty_interval3 <= arty_interval2 + `MS500;
                end
            `ifdef XILINX_SIMULATOR
                else if(clk_counter == `MS001+3)
            `else
                else if(clk_counter == arty_interval4)
            `endif
                begin
                    LED <= opcodes_processed[4:0];        
                    clk_counter <= 0;
                    run <= 0; // re-load opcode fifo & process opcodes again
                    idx <= 0;
                    opcode_processor_en <= 0;   // Turn OFF while fifo reloaded
                    // clear our FREQ_SPI request
                    spi_arb_request_i <= spi_arb_request_i & (~`FREQ_SPI); // Done, clear our request
                    arty_interval4 <= arty_interval3 + `MS500;
                end
            end
        end
    end // posedge clk50

    //////////////////////////////////////////////////////
    // SPI module, all SPI I/O uses this instance
    // We'll run at 12.5MHz (100MHz/8), CPOL=0, CPHA=0
    //////////////////////////////////////////////////////
    reg         spi_run = 0;
    reg  [7:0]  spi_write;
    wire [7:0]  spi_read;
    wire        spi_busy;
    wire        spi_done_byte;  // 1=done with a byte, data is valid
    spi #(.CLK_DIV(3)) spirw 
    (
        .clk(clk100),
        .rst(rst),
        .miso(SYN_MISO),
        .mosi(SYN_MOSI),
        .sck(SYN_SCLK),
        .start(spi_run),
        .data_in(spi_write),
        .data_out(spi_read),
        .busy(spi_busy),
        .new_data(spi_done_byte)     // 1=signal, data_out is valid
    );

    // SPI Processor
`ifdef XILINX_SIMULATOR
    integer     filespi = 0;
    reg [7:0]   dbgdata;
`endif
    always @(posedge clk100) begin

        if(rst) begin
            DDS_SSN = 1;
            RSYN_SSN = 1;
            MSYN_SSN = 1;
            FR_SSN = 1;
            MBW_SSN = 1;
        end
        else begin
            // Start SPI write if the spiqueue is not empty
            if(spi_state == `SPI_IDLE && !spiqueue_empty) begin
                spiqueue_rd_en <= 1;
                spi_state <= `SPI_FETCH_DEVICE;
                spibytes <= 0;   // init
            end
            
            // must continue each device until its fifo is empty
            if(spi_state != `SPI_IDLE) begin            
                case(spi_state)
                `SPI_FETCH_DEVICE:
                begin
                    if(spiqueue_rd_valid) 
                    begin
                        spi_device <= spiqueue_data_out;
                        spiqueue_rd_en <= 0;
                        spi_state <= `SPI_FETCH_DATA;
                        spiindex <= 0;
                        spi_fifo_rd_en <= 1;
                        case(spiqueue_data_out)
                        `SPI_DDS: begin
                            DDS_SSN <= 0;
                        end
                        `SPI_RSYN: begin
                            RSYN_SSN <= 0;
                        end
                        `SPI_MSYN: begin
                            MSYN_SSN <= 0;
                        end
                        `SPI_FR: begin
                            FR_SSN <= 0;
                        end
                        `SPI_MBW: begin
                            MBW_SSN <= 0;
                        end
                        endcase
                    end
                end
                `SPI_FETCH_WAIT: begin
                    if(spi_read_latency <= 2)   // 1 clock here & 1 back
                        spi_state <= `SPI_FETCH_DATA;
                    spi_read_latency <= spi_read_latency - 1;
                end
                `SPI_FETCH_DATA:
                // fetch all the bytes into an array.
                begin
                    if(spi_fifo_rd_valid) 
                    begin
                        spidata[spibytes] <= spi_fifo_data_out;
                        // first time after VALID need 1 additional clock???
                        if(!spi_fifo_empty) begin
                            if(spibytes == 0)
                                spi_read_latency <= `SPI_RD_LATENCY+1;
                            else
                                spi_read_latency <= `SPI_RD_LATENCY;
                        end
                        spibytes <= spibytes + 1;
                        if(spi_fifo_empty) begin
                            spi_fifo_rd_en <= 0;
                            spi_run <= 1;
                            spi_state <= `SPI_WRITING;
                            spiindex <= 0;;
                            spi_write <= spidata[0];
                        end
                        else
                            spi_state <= `SPI_FETCH_WAIT;
                    `ifdef XILINX_SIMULATOR
                        if(filespi == 0) begin
                            filespi = $fopen("../../../project_1.srcs/sources_1/spi_out.txt", "a");
                            //$fdisplay (filespi, "\nReading %d hex SPI bytes from fifo, sending to DDS:", spi_fifo_count);
                        end
                        $fdisplay (filespi, "%02h", spi_fifo_data_out);
                    `endif
                    end
                end
                `SPI_WRITING:
                begin
                    // Wait for spi_done_byte
                    if(spi_done_byte) begin
                        spiindex = spiindex + 1;
                        if(spiindex == spibytes) begin
                            spi_run = 0;   // SPI write off
                            spi_state <= `SPI_IDLE;
                            spi_device <= `SPI_NONE;
                        `ifdef XILINX_SIMULATOR
                            $fdisplay (filespi, "   "); // spacer line for debugging, matches input file
//                            $fdisplay (filespi, "   "); Wrote %d bytes, expected %d", 
//                                                spiindex, spibytes);  // spacer line for debugging, matches input file
                            $fclose(filespi);
                            filespi = 0;
                        `endif
                            case(spi_device)
                            `SPI_DDS: begin
                                DDS_SSN <= 1;
                            end
                            `SPI_RSYN: begin
                                RSYN_SSN <= 1;
                            end
                            `SPI_MSYN: begin
                                MSYN_SSN <= 1;
                            end
                            `SPI_FR: begin
                                FR_SSN <= 1;
                            end
                            `SPI_MBW: begin
                                MBW_SSN <= 1;
                            end
                            endcase
                        end
                        else begin
                            spi_write <= spidata[spiindex];
                        end
                    end
                end
                default:
                begin
                    spi_state <= `SPI_IDLE;
                    spi_device <= `SPI_NONE;
                    spi_status <= `ERR_UNKNOWN_SPI_STATE;
                end
                endcase
            end
        end
    end

    // Debugging UART variables
    wire [15:0]         ctlinw;
    wire [15:0]         statoutw;
    wire [3:0]          ledsw;
    wire [3:0]          ledsgw;
    wire                refclkw;
    wire                TxD_From_Termw;
    wire                RxD_To_Termw;
    wire [6:0]          dbgw;
    // UART Command Processor (includes rcvr.v and xmtr.v).
    uart uart1
    (// diag/debug control signal outputs
     .UART1_CTL(ctlinw),
     .LED(ledsw),
     .LEDG(ledsgw),
 
     // diag/debug status  signal inputs
     .UART1_STAT(statoutw),
     .SW(SW),
     .BTN(btn[2:0]),

     .OPCODES(opcodes_processed),
     .PTN_OPCODES(ptn_opcodes_processed),
     .ARG16(system_state),
     
     // infrastructure, etc.
     .CLK(clk50),                             // Arty 100MHz clock input on E3.
     .RST(RST),                            // Using SW3 as a reset button for now.
     .REFCLK_O(refclkw),                      // temporary test output
     .DBG_UART_TXO(TxD_From_Termw),           // "TX" from USB-SerialBridge to FPGA
     .DBG_UART_RXI(RxD_To_Termw),             // "RX" from FPGA             to USB-SerialBridge
     .DBG_STATE(dbgw) 
     );
 
    assign  JD_GPIO7         = refclkw;
    assign  RGB_GRN[3:0]     = ledsw;
    //assign  {RGB3_Green, RGB2_Green, RGB1_Green, RGB0_Green} = ledsgw & {4{refclkw}};
    assign  TxD_From_Termw   = UART_TXD;
    assign  UART_RXD         = RxD_To_Termw;
    assign  statoutw         = ~ctlinw;
    assign  {JD_GPIO6, JD_GPIO5, JD_GPIO4, JD_GPIO3, JD_GPIO2, JD_GPIO1, JD_GPIO0} = dbgw;
        
endmodule
