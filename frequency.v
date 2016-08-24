//////////////////////////////////////////////////////////////////////////////////
// Company: Ampleon 
// Engineer: Rick Rigby
// 
// Create Date: 03/28/2016 06:13:10 PM
// Design Name: Frequency module, Opcode provessor
// Module Name: frequency
// Project Name: Sango family
// Target Devices: ARTIX-7
// Tool Versions: 
// Description: Process fifo of frequencies, populate the SPI fifo
//              for caller to write to SPI
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments: Code ported from Roger's perl script 
// 
//////////////////////////////////////////////////////////////////////////////////

/*
 * Programming notes:
 * Calculations ported from original perl script
 * On the main board, frequency is the only subsystem programming SPI.
 * Frequency can be set by opcode, or by the pattern generator.
 *
 * -On the X7, changing frequency while a pattern is running is illegal.
 * -On the S4, changing frequency while a pattern is running is supported.
 * We'll use either two frequency registers, or a flag, to control
 * overriding the frequency on the S4.
 *
 * The 'mode' opcode/register is a bitmap to set certain items used in the
 * frequency calculations (hi-speed versus low-noise modes)
 */

`include "timescale.v"
`include "version.v"

`include "status.h"
`include "opcodes.h"
`include "queue_spi.h"

module frequency(
    input               clk,
    input               rst,
    
    input               freq_en,
    input               spi_processor_idle, // Only queue SPI data when it's idle

    input               x7_mode,            // S4 is a limited version of X7, true if X7, false=S4
    input               high_speed_syn,     // synthesiser mode, true=high speed syn mode, false=high accuracy mode

    // Frequency(ies) are in Hz in input fifo
    input [31:0]        freq_fifo_i,        // frequency fifo
    output reg          freq_fifo_rd_en_o,  // fifo read line
    input               freq_fifo_empty_i,  // fifo empty flag
    input [9:0]         freq_fifo_count_i,  // fifo count, for debug message only

    // SPI data is written to dual-clock fifo, then SPI write request is queued.
    // spi_processor_idle is asserted when write is finished by top level.
    output reg [7:0]    spi_o,              // spi DDS fifo data
    output reg          spi_wr_en_o,        // spi DDS fifo write enable
    input               spi_fifo_empty_i,   // spi DDS fifo empty flag
    input               spi_fifo_full_i,    // spi DDS fifo full flag
    input               spi_wr_ack_i,       // spi DDS fifo write acknowledge
    //input [8:0]         spi_fifo_count_i,   // spi DDS fifo counter

    // The fifo to request an SPI write from the top level
    output reg [7:0]    spiwr_queue_data_o,       // queue request for DDS write
    output reg          spiwr_queue_wr_en_o,      // spi DDS fifo write enable
    input               spiwr_queue_fifo_empty_i, // spi DDS fifo empty flag
    input               spiwr_queue_fifo_full_i,  // spi DDS fifo full flag
    input               spiwr_queue_wr_ack_i,     // fifo write acknowledge
    //input [4:0]         spiwr_queue_fifo_count_i, // spi DDS fifo counter

    output reg [7:0]    status_o,               // SUCCESS when done, or an error code
    output reg          busy_o                  // State of this module
    );

///// Hack...until SPI bus arbiter in place
//    // SPI data is written to dual-clock fifo, then SPI write request is queued.
//    // spi_processor_idle is asserted when write is finished by top level.
//    reg [7:0]    spi_o;              // spi DDS fifo data
//    reg          spi_wr_en_o;        // spi DDS fifo write enable

//    // The fifo to request an SPI write from the top level
//    reg [7:0]    spiwr_queue_data_o;       // queue request for DDS write
//    reg          spiwr_queue_wr_en_o;      // spi DDS fifo write enable
///// End Hack

    // Main Globals
    reg [6:0]       state = 0;
    reg [6:0]       next_state;         // saved while waiting for multiply/divide in FRQ_WAIT state
    reg [6:0]       next_spiwr_state;   // saved while waiting for SPI writes to finish before next request

    reg [15:0]      frequency = 0;
    reg [31:0]      tmp32;      // for FR, MSYN, MBW queueing, other tmp use
    reg [3:0]       byte_idx;   // countdown when writing bytes to fifo
    reg [5:0]       shift;      // up to 63 bits
    // Latency for math operations, Xilinx multiplier & divrem divider have no reliable "done" line???
    `define MULTIPLIER_CLOCKS 4
    `define DIVIDER_CLOCKS 42
    reg [5:0]       latency_counter;    // wait for multiplier & divider 

    // Setup rst_n & freq_clk
    wire        rst_n;  // Need hi-true RST, synchronous TBD
    //wire        freq_clk;
    
    assign rst_n = ~rst;
    //assign freq_clk = (clk & freq_en);

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

    // Divider for low-noise & high-speed calculations will
    // need remainder info, use Xilinx divider:
    // Configured with 48-bit dividend, 24-bit divisor, High-Radix mode.
    // (need 40 bits to divide NDDS)
    // Fractional width 16-bits. 
    // Result is (48-bit Quotient) | (16-bit Fractional)
    reg         divrem_divisor_valid = 0;   // assert when ready
    wire        divrem_divisor_ready;       // asserted by core
    reg  [47:0] divrem_divisor_data;        // Have to divide by NDDS

    reg         divrem_dividend_valid = 0; // assert when ready
    wire        divrem_dividend_ready;     // core asserts
    reg  [63:0] divrem_dividend_data;

    wire        divrem_result_valid;
    wire [79:0] divrem_result;             // quotient 55:16, remainder [15:0]
    divider32 divrem (
        .aclk(clk),
        .s_axis_divisor_tvalid(divrem_divisor_valid),  // assert when ready
        .s_axis_divisor_tready(divrem_divisor_ready),
        .s_axis_divisor_tdata(divrem_divisor_data),

        .s_axis_dividend_tvalid(divrem_dividend_valid),
        .s_axis_dividend_tready(divrem_dividend_ready),
        .s_axis_dividend_tdata(divrem_dividend_data),
        // valid line goes ON after first divide done & asserts & deasserts oddly,
        // must be doing something wrongly????        
        .m_axis_dout_tvalid(divrem_result_valid),
        .m_axis_dout_tdata(divrem_result)
      );

    parameter B = 47;
    parameter FRNOM = 1000;
    parameter FRTUNE = 5000;            // +/- PPM tuning range of FR3
    parameter PDMIN = 20;               // min MSYN phase detector frequency
    parameter PDMAX = 40;		        // max MSYN phase detector frequency
    // don't perform multiplication by 1 parameter FERRMAX = 1;              // 1Hz accuracy spec
    
    reg [55:0] multA;                   // A multiplier input, used for NDDS, etc. 56 bits should handle d*n*B
    reg [23:0] multB;                   // B multiplier input, used for frequency, etc
    reg [47:0] NDDS = 48'h00A3D70A3D71; // 48-bit tuning word, 2**48, /400
    reg [47:0] fout, ferr;
    reg [63:0] dds;
    wire [63:0] multiplier_result;
    reg [31:0] msyn_a = 0;
    reg [31:0] msyn_b = 0;
    reg [31:0] msyn_n = 0;
    reg [31:0] msyn_r = 0;

    // Low noise, Hi Speed calculation variables
    reg [15:0] mdiv;
    reg [31:0] ferrmin;
    reg [31:0] freqo;
    reg [31:0] nmin, nmax;
    reg [31:0] atry;
    reg [31:0] btry;
    reg [47:0] dtry;
    reg [31:0] ftry;
    reg [31:0] ntry;
    reg [31:0] rtry;
    reg [31:0] f_over_n;
    reg [47:0] half;        // used for half NDDS too
    reg [31:0] error;
    reg [31:0] err_ppm;
    reg [7:0]  rc;     // result (converges?) 1=success, 0=failed

    // Xilinx multiplier to perform dds = NDDS * frequency.
    // A input is 56 bits, NDDS. B input is 24 bits, frequency
    // in MHz. Output is 64 bits, 60 would be sufficient for
    // 3200 * NDDS.
    mult48 ddsMultiply (
       .CLK(clk),
       .A(multA),
       .B(multB),
       .CE(freq_en),
       .P(multiplier_result)
     );      
    
    /////////////////////////////////
    // Frequency state definitions //
    /////////////////////////////////
    `define FRQ_IDLE        0
    `define FRQ_READ        1
    `define FRQ_TOMHZ       2
    `define FRQ_DDS_MULT    3
    `define FRQ_DDS_CALC    4
    
    `define FRQ_COMMON_1    5
    `define FRQ_COMMON_2    6
    `define FRQ_COMMON_3    7
    `define FRQ_COMMON_4    8
    `define FRQ_LOWNOISE_5  9
    `define FRQ_LOWNOISE_6  10
    `define FRQ_LOWNOISE_7  11
    `define FRQ_LOWNOISE_8  12
    `define FRQ_LOWNOISE_9  13
    `define FRQ_LOWNOISE_10 14
    `define FRQ_LOWNOISE_11 15
    `define FRQ_LOWNOISE_12 16
    `define FRQ_LOWNOISE_13 17
    `define FRQ_LOWNOISE_14 18
    `define FRQ_LOWNOISE_15 19
    `define FRQ_LOWNOISE_16 20
    `define FRQ_LOWNOISE_17 21
    `define FRQ_LOWNOISE_18 22
    `define FRQ_LOWNOISE_19 23
    `define FRQ_LOWNOISE_20 24
    `define FRQ_LOWNOISE_21 25
    `define FRQ_LOWNOISE_22 26
    `define FRQ_LOWNOISE_23 27
    `define FRQ_FINAL_1     28
    `define FRQ_FINAL_2     29

    `define FRQ_HISPEED_1   30
    `define FRQ_HISPEED_2   31
    `define FRQ_HISPEED_3   32
    `define FRQ_HISPEED_4   33
    `define FRQ_HISPEED_5   34
    `define FRQ_HISPEED_6   35
    `define FRQ_HISPEED_7   36
    `define FRQ_HISPEED_8   37
    `define FRQ_HISPEED_9   38
    `define FRQ_HISPEED_10  39
    `define FRQ_COMMON_FERR 40
    `define FRQ_COMMON_FOUT 41
    `define FRQ_SPIWRDATA_WAIT      42  // Dual clock fifo needs an extra clock at begin & end
    `define FRQ_SPIWRDATA_FINISH    43
    `define FRQ_SPIWRQUE_WAIT       44
    `define FRQ_SPIWRQUE_FINISH     45
    `define FRQ_SPI_PROC_WAIT       46  // Wait for SPI processor to finish
    
    // done calculations, queuing data for SPI states
    `define FRQ_DDS_QUEUE       60
    `define FRQ_DDS_QUEUE_CMD   61
    `define FRQ_FR_QUEUE        62
    `define FRQ_FR_QUEUE_CMD    63
    `define FRQ_MSYN_QUEUE      64
    `define FRQ_MSYN_QUEUE_CMD  65
    `define FRQ_MBW_QUEUE       66
    `define FRQ_MBW_QUEUE_CMD   67

    // Waiting for multiply/divide state, 7 bits available 
    `define FRQ_WAIT        127
    ////////////////////////////////////////
    // End of frequency state definitions //
    ////////////////////////////////////////
    
`ifdef XILINX_SIMULATOR
    integer         filedds = 0;
    integer         filefr = 0;
    integer         filemsyn = 0;
    reg [7:0]       dbgdata;
`endif

`ifdef X7_CORE
    always @( posedge clk)
    begin
        if( rst )
        begin
            state = `FRQ_IDLE;            
            freq_fifo_rd_en_o <= 0;
        end
        else if(freq_en == 1)
        begin
            case(state)
            `FRQ_WAIT: begin
                if(latency_counter == 0)
                    state <= next_state;
                else
                    latency_counter <= latency_counter - 1;
            end
            // Wait for SPI processor to finish before
            // starting next SPI request
            `FRQ_SPI_PROC_WAIT: begin
                if(spi_processor_idle) begin
                    state <= next_spiwr_state;
                end
            end
            `FRQ_IDLE: begin
                if(!freq_fifo_empty_i && spi_processor_idle) begin
                    freq_fifo_rd_en_o <= 1;   // read next value
                    state <= `FRQ_READ;
                    busy_o <= 1'b1;
                end
                else
                    busy_o <= 1'b0;
            end             
            `FRQ_READ: begin
                // read frequency in Hz, setup convert to MHz
                dividend <= freq_fifo_i;
                freq_fifo_rd_en_o <= 0;
                divisor <= 32'd1000000;      // Hz to MHz
                div_enable <= 1;
                state <= `FRQ_TOMHZ;            // Wait for result
            end
            `FRQ_TOMHZ: begin
                if(divide_done) begin
                    frequency <= quotient[15:0];
                    multB <= quotient[15:0];
                    multA <= NDDS;
                    div_enable <= 0;
                    latency_counter <= `MULTIPLIER_CLOCKS;
                    next_state <= `FRQ_DDS_MULT;
                    state <= `FRQ_WAIT;
                end
            end
            `FRQ_DDS_MULT: begin
                rc <= 0;    // Clear calculations converge flag
                state <= `FRQ_DDS_CALC;
            end
            `FRQ_DDS_CALC: begin
                // Calculations & queue SPI data write
                dds <= multiplier_result; // multiplier_result updated during FRQ_DDS_MULT state, save it
                // Careful, use multiplier_result duiring this clock cycle
                if (frequency <= 100) begin         // DDS only <= 100MHz
                    byte_idx <= `DDS_PCR_BYTES + 1;     // Setup for 1 additional byte for processing loop                    
//                  Do not start writing here, must be sure all SPI writes are done
//                    spi_o <= multiplier_result[7:0];
//                    spi_wr_en_o <= 1;
                    next_spiwr_state <= `FRQ_DDS_QUEUE;
                    state <= `FRQ_SPI_PROC_WAIT;        // wait for all SPI writes
                `ifdef XILINX_SIMULATOR
                    if(filedds == 0)
                        filedds = $fopen("../../../project_1.srcs/sources_1/spi_in.txt", "a");
                `endif
                end
                else begin
                    if (high_speed_syn) begin       // high-speed syn mode
                    `ifdef XILINX_SIMULATOR
                        if(filefr == 0)
                            filefr = $fopen ("../../../project_1.srcs/sources_1/fr_calcs.txt", "a");
                        $fdisplay (filefr, "Freq calcs, hi-speed mode, %d MHz", frequency);
                    `endif
                    end
                    else begin                    // low-noise syn mode
                    `ifdef XILINX_SIMULATOR
                        if(filefr == 0)
                            filefr = $fopen ("../../../project_1.srcs/sources_1/fr_calcs.txt", "a");
                        $fdisplay (filefr, "Freq calcs, low-noise mode, %d MHz", frequency);
                        $fdisplay (filefr, "msyn_r", frequency);
                    `endif
                    end
                    // Start calculations
                    // Second state: FR2 -> xB PLL-> FR3 -> RDIV -> FR4
                    // DIV divides by integer from 25-50
                    // Third stage: FR4 = top octave PLL -> MDIV -> F
                    if (frequency > 1600)
                        mdiv <= 1;
                    else if (frequency > 800)
                        mdiv <= 2;
                    else if (frequency > 400)
                        mdiv <= 4;
                    else if (frequency > 200)
                        mdiv <= 8;
                    else
                        mdiv <= 16;
                    state <= `FRQ_COMMON_1;
                end
            end

            // Calculations, first 4 or so are common for low-noise & hi-speed modes
            `FRQ_COMMON_1: begin            
                multA <= frequency;
                multB <= mdiv;
                ferrmin <= mdiv;     // FERRMAX is 1, FERRMAX * mdiv;           // 1Hz output accuracy spec
                latency_counter <= `MULTIPLIER_CLOCKS;
                next_state <= `FRQ_COMMON_2;
                state <= `FRQ_WAIT;
            end
            `FRQ_COMMON_2: begin
                freqo <= multiplier_result[31:0];
                // setup limit divisions
                divrem_dividend_data <= multiplier_result[31:0];
                divrem_dividend_valid <= 1;
                divrem_divisor_data <= PDMAX;
                divrem_divisor_valid <= 1;
                half <= PDMAX >> 1;
                latency_counter <= `DIVIDER_CLOCKS;
                dividend <= multiplier_result[31:0];
                divisor <= PDMIN;
                div_enable <= 1;
                next_state <= `FRQ_COMMON_3;
                state <= `FRQ_WAIT;
            end
            `FRQ_COMMON_3: begin
                // begin unrolled loop, set loop control variables
                if(divrem_result_valid == 1) begin
                    nmin = divrem_result[47:16];
                    if(divrem_result[15:0] > half)
                        nmin = nmin + 1;
                    ntry <= nmin;
                    nmax <= quotient[31:0];
                    state <= `FRQ_COMMON_4;
                end
            end
            `FRQ_COMMON_4: begin  // begin loop processing
                if(ntry >= nmax) begin
                    if(rc == 0) begin
                        //warn "Can't find acceptable hardware values for specified frequency.\n" if ($rc == 0);
                    `ifdef XILINX_SIMULATOR
                        $fdisplay (filefr, "Can't find acceptable hardware values for specified frequency.");
                    `endif
                        status_o = `ERR_FREQ_CONVERGE;
                        state = `FRQ_IDLE;
                    end
                    else
                        state = `FRQ_FINAL_1;  // final calcs
                end
                else if(high_speed_syn) begin       // high-speed syn mode
//                $d = int($fo * $NDDS / $n + 0.5);
                    multA <= freqo;
                    multB <= NDDS;
                    latency_counter <= `MULTIPLIER_CLOCKS;
                    next_state <= `FRQ_HISPEED_1;
                    state <= `FRQ_WAIT;
                end
                else begin  // low-noise calculation
    //            for(n = nmin; n < nmax; )  // try all values of N for which phase det freq is OK
    //            begin
    //                r = (int)(FRNOM / (fo / n) + 0.5);        // compute closest R for value of N
                    divrem_dividend_data <= freqo;
                    divrem_dividend_valid <= 1;
                    divrem_divisor_data <= ntry;
                    divrem_divisor_valid <= 1;
                    half <= ntry >> 1;
                    latency_counter <= `DIVIDER_CLOCKS;
                    next_state <= `FRQ_LOWNOISE_5;
                    state <= `FRQ_WAIT;
                end
            end

            `FRQ_LOWNOISE_5: begin
                if(divrem_result_valid == 1) begin
                    f_over_n = divrem_result[47:16];
                    if(divrem_result[15:0] > half) 
                        f_over_n = f_over_n + 1;
//                r = (int)(FRNOM / (fo / n) + 0.5);        // compute closest R for value of N
                    divrem_dividend_data <= FRNOM;
                    divrem_divisor_data <= f_over_n;
                    half <= f_over_n >> 1;
                    latency_counter <= `DIVIDER_CLOCKS;
                    divrem_dividend_valid <= 1;
                    divrem_divisor_valid <= 1;
                    next_state <= `FRQ_LOWNOISE_6;
                    state <= `FRQ_WAIT;
                end
            end
            
            `FRQ_LOWNOISE_6: begin
                if(divrem_result_valid == 1) begin
                    // R is in quotient
                    rtry = divrem_result[47:16];   // save R
                    if(divrem_result[15:0] > half)
                        rtry = rtry + 1;
                        
                //	$err = $FRNOM * $n / $r - $fo;
                    multA <= FRNOM;
                    multB <= ntry;
                    latency_counter <= `MULTIPLIER_CLOCKS;
                    next_state <= `FRQ_LOWNOISE_7;
                    state <= `FRQ_WAIT;
                end
            end

            `FRQ_LOWNOISE_7: begin
                // err = abs(FRNOM * n / r - fo);
                divrem_dividend_data <= multiplier_result[31:0];
                divrem_divisor_data <= rtry;
                divrem_dividend_valid <= 1;
                divrem_divisor_valid <= 1;
                half <= rtry >> 1;
                latency_counter <= `DIVIDER_CLOCKS;
                next_state <= `FRQ_LOWNOISE_8;
                state <= `FRQ_WAIT;
            end
            
            `FRQ_LOWNOISE_8: begin
                if(divrem_result_valid == 1) begin
            // err = abs(FRNOM * n / r - fo);
                    tmp32 = divrem_result[47:16];
                    if(divrem_result[15:0] > half)
                        tmp32 = tmp32 + 1;
                    if(tmp32 > freqo)
                        error <= tmp32 - freqo;
                    else
                        error <= freqo - tmp32;
                    state <= `FRQ_LOWNOISE_9;
                end
            end

            `FRQ_LOWNOISE_9: begin
                // tmp32 = 1000000 * err / fo;
                multA <= 1000000;
                multB <= error;
                latency_counter <= `MULTIPLIER_CLOCKS;
                next_state <= `FRQ_LOWNOISE_10;
                state <= `FRQ_WAIT;
            end

            `FRQ_LOWNOISE_10: begin
                // tmp32 = 1000000 * err / fo;
                divrem_dividend_data <= multiplier_result[31:0];
                divrem_divisor_data <= freqo;
                divrem_dividend_valid <= 1;
                divrem_divisor_valid <= 1;
                half <= freqo >> 1;
                latency_counter <= `DIVIDER_CLOCKS;
                next_state <= `FRQ_LOWNOISE_11;
                state <= `FRQ_WAIT;
            end

            `FRQ_LOWNOISE_11: begin
                if(divrem_result_valid) begin
                // if ( tmp32 <= FRTUNE)     // in Rsyn range, so let's see how close it is
                    tmp32 = divrem_result[47:16];
                    if(divrem_result[15:0] > half)
                        tmp32 = tmp32 + 1;
                    if(tmp32 <= FRTUNE) begin
                // d = $rtoi(fo * r * NDDS / B / n + 0.5);
                        multA <= freqo;
                        multB <= rtry;
                        latency_counter <= `MULTIPLIER_CLOCKS;
                        next_state <= `FRQ_LOWNOISE_12;
                        state <= `FRQ_WAIT;
                    end
                    else begin
                        // back to top of calculation loop
                        ntry <= ntry + 1;                
                        state <= `FRQ_COMMON_4;
                    end
                end
            end

            // calculating d
            `FRQ_LOWNOISE_12: begin
                // d = $rtoi(fo * r * NDDS / B / n + 0.5);
                multA <= NDDS;
                multB <= multiplier_result[31:0];
                latency_counter <= `MULTIPLIER_CLOCKS;
                next_state <= `FRQ_LOWNOISE_14;
                state <= `FRQ_WAIT;
            end
// Oops...
//            `FRQ_LOWNOISE_13: begin
//            // d = $rtoi(fo * r * NDDS / B / n + 0.5);
//                multA <= multiplier_result[31:0];
//                multB <= NDDS;
//                state <= `FRQ_LOWNOISE_14;
//            end
            `FRQ_LOWNOISE_14: begin
                // d = $rtoi(fo * r * NDDS / B / n + 0.5);
                divrem_dividend_data <= multiplier_result;
                divrem_dividend_valid <= 1;
                divrem_divisor_data <= B;
                divrem_divisor_valid <= 1;
                half <= B >> 1; 
                latency_counter <= `DIVIDER_CLOCKS;
                next_state <= `FRQ_LOWNOISE_15;
                state <= `FRQ_WAIT;
            end
            `FRQ_LOWNOISE_15: begin
                if(divrem_result_valid) begin
                // d = $rtoi(fo * r * NDDS / B / n + 0.5);
                    divrem_dividend_data = divrem_result[79:16];
                    if(divrem_result[15:0] > half) 
                        divrem_dividend_data = divrem_dividend_data + 1;
                    divrem_dividend_valid <= 1;
                    divrem_divisor_data <= ntry;
                    divrem_divisor_valid <= 1;
                    half <= ntry >> 1; 
                    latency_counter <= `DIVIDER_CLOCKS;
                    next_state <= `FRQ_LOWNOISE_16;
                    state <= `FRQ_WAIT;
                end
            end
            `FRQ_LOWNOISE_16: begin
                if(divrem_result_valid) begin
                // d = $rtoi(fo * r * NDDS / B / n + 0.5);
                    dtry = divrem_result[63:16];
                    if(divrem_result[15:0] > half) 
                        dtry <= dtry + 1;
                    state <= `FRQ_LOWNOISE_17;
                end
            end

            // calculating f
            `FRQ_LOWNOISE_17: begin
            // f = d * n * B / r / NDDS; Should fit in 64 bit multiply register
                multA <= dtry;
                multB <= ntry;
                latency_counter <= `MULTIPLIER_CLOCKS;
                next_state <= `FRQ_LOWNOISE_18;
                state <= `FRQ_WAIT;
            end
            `FRQ_LOWNOISE_18: begin
                // f = d * n * B / r / NDDS;
                multA <= multiplier_result[55:0];
                multB <= B;
                latency_counter <= `MULTIPLIER_CLOCKS;
                next_state <= `FRQ_LOWNOISE_19;
                state <= `FRQ_WAIT;
            end
            `FRQ_LOWNOISE_19: begin
                // f = d * n * B / r / NDDS;
                divrem_dividend_data <= multiplier_result;
                divrem_divisor_data <= rtry;
                divrem_dividend_valid <= 1;
                divrem_divisor_valid <= 1;
                half <= rtry >> 1;
                latency_counter <= `DIVIDER_CLOCKS;
                next_state <= `FRQ_LOWNOISE_20;
                state <= `FRQ_WAIT;
            end
            `FRQ_LOWNOISE_20: begin
                if(divrem_result_valid) begin
                // f = d * n * B / r / NDDS;
                    divrem_dividend_data = divrem_result[79:16];
                    if(divrem_result[15:0] > half) 
                        divrem_dividend_data <= divrem_dividend_data + 1;
                    divrem_divisor_data <= NDDS;
                    divrem_dividend_valid <= 1;
                    divrem_divisor_valid <= 1;
                    half <= NDDS >> 1;
                    latency_counter <= `DIVIDER_CLOCKS;
                    next_state <= `FRQ_LOWNOISE_21;
                    state <= `FRQ_WAIT;
                end
            end
            `FRQ_LOWNOISE_21: begin
                if(divrem_result_valid) begin
                    ftry = divrem_result[47:16];
                    if(divrem_result[15:0] > half) 
                        ftry = ftry + 1;
                    if(ftry > freqo)
                            tmp32 = ftry - freqo;
                        else
                            tmp32 = freqo - ftry;

                    divrem_dividend_valid <= 0;
                    divrem_divisor_valid <= 0;

                    multA <= 1000000;
                    multB <= tmp32;
                    latency_counter <= `MULTIPLIER_CLOCKS;
                    next_state <= `FRQ_LOWNOISE_22;
                    state <= `FRQ_WAIT;
                end
            end
            `FRQ_LOWNOISE_22: begin
                // err_ppm = 1000000 * (f - fo);
                err_ppm <= multiplier_result[31:0];
            // b = n / 8;
            // a = n % 8;
                divrem_dividend_data <= ntry;
                divrem_dividend_valid <= 1;
                divrem_divisor_data <= 8;
                divrem_divisor_valid <= 1;
                half <= 4; 
                latency_counter <= `DIVIDER_CLOCKS;
                next_state <= `FRQ_LOWNOISE_23;
                state <= `FRQ_WAIT;
            end
            `FRQ_LOWNOISE_23: begin // final check in for loop
                if(divrem_result_valid) begin
                    btry = divrem_result[47:16];
                    atry = divrem_result[15:0];
                    if(btry > atry && err_ppm < ferrmin) begin
                        // Good result, set global variables, loop again
                        ferrmin = err_ppm;
                        dds = dtry;
                        msyn_r = rtry;
                        msyn_n = ntry;
                        state <= `FRQ_COMMON_FERR;
                    end
                    else begin
                        // end of low noise calculation loop
                        ntry = ntry + 1;                
                        state = `FRQ_COMMON_4;      // to beginning of calculation loop
                    end
                end
            end

            // hi-speed loop calculations
            `FRQ_HISPEED_1: begin
                // $d = int($fo * $NDDS / $n + 0.5);
                divrem_dividend_data <= multiplier_result[31:0];
                divrem_divisor_data <= ntry;
                divrem_dividend_valid <= 1;
                divrem_divisor_valid <= 1;
                half <= ntry >> 1;
                latency_counter <= `DIVIDER_CLOCKS;
                next_state <= `FRQ_HISPEED_2;
                state <= `FRQ_WAIT;
            end
            `FRQ_HISPEED_2: begin
                if(divrem_result_valid) begin
                    //$d = int($fo * $NDDS / $n + 0.5);
                    dtry = divrem_result[47:16];
                    if(divrem_result[15:0] > half)
                        dtry = dtry + 1;
                    // got d, do f
                    multA <= dtry;
                    multB <= ntry;                    
                    latency_counter <= `MULTIPLIER_CLOCKS;
                    next_state <= `FRQ_HISPEED_3;
                    state <= `FRQ_WAIT;
                end
            end
            `FRQ_HISPEED_3: begin
                //$f = $d * $n / $NDDS;
                divrem_dividend_data <= multiplier_result[15:0];
                divrem_divisor_data <= NDDS;
                divrem_dividend_valid <= 1;
                divrem_divisor_valid <= 1;
                half <= NDDS >> 1;
                latency_counter <= `DIVIDER_CLOCKS;
                next_state <= `FRQ_HISPEED_4;
                state <= `FRQ_WAIT;
            end            
            `FRQ_HISPEED_4: begin
                if(divrem_result_valid) begin
                    ftry = divrem_result[47:16];
                    if(divrem_result[15:0] > half)
                        ftry = ftry + 1;
                    // done $f = $d * $n / $NDDS;
                    // next $err = 1e6 * ($f - $fo);  (err_ppm)
                    if(ftry > freqo)
                        tmp32 = ftry - freqo;
                    else
                        tmp32 = freqo - ftry;
                    multA <= tmp32;
                    multB <= 1000000;
                    latency_counter <= `MULTIPLIER_CLOCKS;
                    next_state <= `FRQ_HISPEED_5;
                    state <= `FRQ_WAIT;
                end
            end
            `FRQ_HISPEED_5: begin
                err_ppm <= multiplier_result[31:0];
                divrem_dividend_data <= ntry;
                divrem_divisor_data <= 8;
                divrem_dividend_valid <= 1;
                divrem_divisor_valid <= 1;
                latency_counter <= `DIVIDER_CLOCKS;
                next_state <= `FRQ_HISPEED_6;
                state <= `FRQ_WAIT;
            end
            `FRQ_HISPEED_6: begin
                if(divrem_result_valid) begin
                    btry <= divrem_result[47:16];
                    atry <= divrem_result[15:0];
                    state <= `FRQ_HISPEED_7;
                end
            end
            `FRQ_HISPEED_7: begin
                if(btry > atry && err_ppm < ferrmin) begin
                    // set globals
                    ferrmin <= err_ppm;
                    dds <= dtry;
                    msyn_n <= ntry;
                    divrem_dividend_data <= error;
                    divrem_divisor_data <= mdiv;
                    divrem_dividend_valid <= 1;
                    divrem_divisor_valid <= 1;
                    half <= mdiv >> 1;
                    latency_counter <= `DIVIDER_CLOCKS;
                    next_state <= `FRQ_COMMON_FERR;
                    state <= `FRQ_WAIT;
                end
                else begin
                    // back to top of calculation loop
                    ntry <= ntry + 1;                
                    state <= `FRQ_COMMON_4;  // to beginning of calculation loop
                end
            end

            // common end to both calculation loops, calc ferr, fout
            `FRQ_COMMON_FERR: begin
                if(divrem_result_valid) begin
                    ferr = divrem_result[47:16];
                    if(divrem_result[15:0] > half)
                        ferr = ferr + 1;
                    divrem_dividend_data <= freqo;
                    divrem_divisor_data <= mdiv;
                    divrem_dividend_valid <= 1;
                    divrem_divisor_valid <= 1;
                    latency_counter <= `DIVIDER_CLOCKS;
                    next_state <= `FRQ_COMMON_FOUT;
                    state <= `FRQ_WAIT;
                end
            end
            `FRQ_COMMON_FOUT: begin
                if(divrem_result_valid) begin
                    fout = divrem_result[47:0];
                    if(divrem_result[15:0] > half)
                        fout <= fout + 1;

                    // back to top of loop
                    ntry <= ntry + 1;                
                    rc <= 1;    // within spec, but keep looking for best match
                    state <= `FRQ_COMMON_4;      // to beginning of calculation loop
                end
            end

            // RC=1, Final calcs
            `FRQ_FINAL_1: begin
                //msyn_b = (int)(msyn_n / 8);
                //msyn_a = msyn_n % 8;
                divrem_dividend_data <= msyn_n;
                divrem_dividend_valid <= 1;
                divrem_divisor_data <= 8;
                divrem_divisor_valid <= 1;
                half <= 4; 
                latency_counter <= `DIVIDER_CLOCKS;
                next_state <= `FRQ_FINAL_2;
                state <= `FRQ_WAIT;
            end
            `FRQ_FINAL_2: begin
                if(divrem_result_valid) begin
                    //msyn_b = (int)(msyn_n / 8);
                    //msyn_a = msyn_n % 8;
                    msyn_b = divrem_result[47:16];
                    msyn_a = divrem_result[15:0];
                    // Low noise calculations done, write R to fr_div0 register
                    tmp32 = 24'h001500 + msyn_r - 1;
                    byte_idx <= `FR_BYTES + 1;
                    next_spiwr_state <= `FRQ_FR_QUEUE;  // FR_DIV0 SPI write
                    state <= `FRQ_SPI_PROC_WAIT;        // wait for all SPI writes
                `ifdef XILINX_SIMULATOR
                    $fdisplay (filefr, "DDS=%012h, N=%d, B=%d, A=%d, MDIV=%d", dds, ntry, btry, atry, mdiv);
                    $fdisplay (filefr, "Fout=%d MHz (Err=%d Hz)", freqo, error);
                `endif
                end
            end

            `FRQ_SPIWRDATA_WAIT: begin
                // Write ACK takes one extra clock at the beginning & end
                if(spi_wr_ack_i == 1)
                    state <= next_state;
            end
            `FRQ_SPIWRDATA_FINISH: begin
                // need to wait for spi_fifo_empty_i flag to go OFF
                // when it does, queue the SPI write command
                if(!spi_fifo_empty_i)
                    state <= next_state;
            end
            `FRQ_SPIWRQUE_WAIT: begin
                // Write ACK takes one extra clock at the beginning & end
                // need to wait for spiwr_queue_fifo_empty_i flag to go OFF
                if(spiwr_queue_wr_en_o && spiwr_queue_wr_ack_i)
                    spiwr_queue_wr_en_o <= 0;
                if(!spiwr_queue_fifo_empty_i)
                    state <= next_state;
            end

            // Queue SPI bytes for writing by top level SPI processor
            `FRQ_DDS_QUEUE: begin
                //
                // All frequencies and modes use this state to write DDS
                //
                // When queueing has finished, byte_idx will be 0,
                // waiting for top level to write DDS at this point,
                // When SPI write is finished, go back to idle
                if(byte_idx == 0) begin
                    // wait in this state (FRQ_DDS_QUEUE, byte_idx=0) until SPI fifo is empty (write has finished)
                    if(spi_processor_idle) begin
                        // done with write SPI, continue calculations if necessary
                        if(frequency <= 100) begin
                            state = `FRQ_IDLE;  // Done
                            status_o = `SUCCESS;
                        end
                        else begin
                            tmp32 = 24'h000001 + (msyn_b << 8) + (msyn_a << 2);
                            byte_idx <= `MSYN_BYTES + 1;
                            state <= `FRQ_MSYN_QUEUE;    // continue w/MSYN, MBW
                        `ifdef XILINX_SIMULATOR
                            $fdisplay (filefr, "DDS done, MSYN_DIV next");
                        `endif
                        end
                    end
                end
                else begin
                    byte_idx = byte_idx - 1;
                    // 2 is the last byte index to be shifted (56 bits)
                    if(byte_idx == 1) begin
                        spi_o <= 8'h06; // final byte into the fifo
                        next_state <= `FRQ_DDS_QUEUE;
                        state <= `FRQ_SPIWRDATA_WAIT;
                    `ifdef XILINX_SIMULATOR
                        $fdisplay (filedds, "06");
                    `endif
                    end
                    else if(byte_idx == 0) begin
                        // 9 bytes are in SPI fifo at top level, queue request to write.
                        // But first, wait for fifo_empty to turn OFF
                        spi_wr_en_o <= 0;   // Turn OFF writes!
                        next_state <= `FRQ_DDS_QUEUE_CMD;  // after fifo empty turns OFF
                        state <= `FRQ_SPIWRDATA_FINISH;
                    end
                    else begin
                        shift = (`DDS_PCR_BYTES - byte_idx) << 3;
                        spi_wr_en_o <= 1;       // Enable writes, SPI processor is not busy
                        spi_o <= (dds >> shift);
                        next_state <= `FRQ_DDS_QUEUE;
                        state <= `FRQ_SPIWRDATA_WAIT;
                    `ifdef XILINX_SIMULATOR
                        dbgdata = (dds >> shift);
                        $fdisplay (filedds, "%02h", dbgdata);
                    `endif
                    end
                end
            end
            `FRQ_DDS_QUEUE_CMD: begin
                // SPI data written to fifo, fifo empty OFF, write SPI processor request
                spiwr_queue_data_o <= `SPI_DDS;     // queue request for DDS write
                spiwr_queue_wr_en_o <= 1;           // spi queue fifo write enable
                next_state <= `FRQ_DDS_QUEUE;       // after queueing cmd, wait in FRQ_DDS_QUEUE state
                state <= `FRQ_SPIWRQUE_WAIT;
            `ifdef XILINX_SIMULATOR
                $fdisplay (filedds, "  ");   // spacer line
                //$fdisplay (filedds, "Done with %d MHz, next...\n", frequency);
                $fclose (filedds);
                filedds = 0;
            `endif
            end
            `FRQ_FR_QUEUE: begin
                // When queueing has finished, byte_idx will be 0,
                // waiting for top level to write FR_DIV0 at this point
                if(byte_idx == 0) begin
                    if(spi_processor_idle) begin
                        // done with write FR, continue, write dds
                        byte_idx <= `DDS_PCR_BYTES + 1;                    
                        state = `FRQ_DDS_QUEUE; // `FRQ_FR_QUEUE only occurs when > 100MHz, low noise mode
                    `ifdef XILINX_SIMULATOR
                        $fdisplay (filefr, "MSYN_R, DDS next...");
                    `endif
                    end
                end
                else begin
                    byte_idx = byte_idx - 1;
                    if(byte_idx == 0) begin
                        // 3 bytes are in SPI fifo at top level, queue request to write
                        spi_wr_en_o <= 0;
                        next_state <= `FRQ_FR_QUEUE_CMD;    // queue request for SPI write FR
                        state <= `FRQ_SPIWRDATA_FINISH;
                    end
                    else begin
                        shift = (`FR_BYTES - byte_idx) << 3;
                        spi_wr_en_o <= 1;               // Enable writes, SPI processor is not busy
                        spi_o <= (tmp32 >> shift);
                        next_state <= `FRQ_FR_QUEUE;
                        state <= `FRQ_SPIWRDATA_WAIT;
                    `ifdef XILINX_SIMULATOR
                        dbgdata = (tmp32 >> shift);
                        $fdisplay (filefr, "%02h", dbgdata);
                    `endif
                    end
                end
            end
            `FRQ_FR_QUEUE_CMD: begin
                // SPI data written to fifo, fifo empty OFF, write SPI processor request
                spiwr_queue_data_o <= `SPI_FR;      // queue request for write
                spiwr_queue_wr_en_o <= 1;           // spi queue fifo write enable
                next_state <= `FRQ_FR_QUEUE;        // after queueing cmd, wait in FRQ_DDS_QUEUE state
                state <= `FRQ_SPIWRQUE_WAIT;
            `ifdef XILINX_SIMULATOR
                $fdisplay (filedds, "  ");   // spacer line
                $fclose (filedds);
                filedds = 0;
            `endif
            end
            `FRQ_MSYN_QUEUE: begin
                // When queueing has finished, byte_idx will be 0,
                // waiting for top level to write MSYN_DIV at this point
                if(byte_idx == 0) begin
                    if(spi_processor_idle) begin
                        // done with write MSYN, continue
                    `ifdef XILINX_SIMULATOR
                        $fdisplay (filefr, "MSYN_DIV done.");
                        $fclose (filefr);
                        filefr = 0;
                    `endif
                        state = `FRQ_MBW_QUEUE;
                    end
                end
                else begin
                    byte_idx = byte_idx - 1;
                    if(byte_idx == 0) begin
                        // 3 bytes are in SPI fifo at top level, queue request to write
                        spi_wr_en_o <= 0;
                        next_state <= `FRQ_MSYN_QUEUE_CMD;    // queue request for SPI write FR
                        state <= `FRQ_SPIWRDATA_FINISH;
                    end
                    else begin
                        shift = (`MSYN_BYTES - byte_idx) << 3;
                        spi_wr_en_o <= 1;
                        spi_o <= (tmp32 >> shift);
                        next_state <= `FRQ_MSYN_QUEUE;
                        state <= `FRQ_SPIWRDATA_WAIT;
                    `ifdef XILINX_SIMULATOR
                        dbgdata = (tmp32 >> shift);
                        $fdisplay (filefr, "%02h", dbgdata);
                    `endif
                    end
                end
            end
            `FRQ_MSYN_QUEUE_CMD: begin
                // SPI data written to fifo, fifo empty OFF, write SPI processor request
                spiwr_queue_data_o <= `SPI_MSYN;    // queue request for write
                spiwr_queue_wr_en_o <= 1;           // spi queue fifo write enable
                next_state <= `FRQ_MSYN_QUEUE;        // after queueing cmd, wait in FRQ_DDS_QUEUE state
                state <= `FRQ_SPIWRQUE_WAIT;
            end
            `FRQ_MBW_QUEUE: begin
//                // When queueing has finished, byte_idx will be 0,
//                // waiting for top level to write at this point
//                if(byte_idx == 0) begin
//                    spiwr_queue_wr_en_o <= 0;
//                    if(spi_fifo_empty_i) begin
//                        // done with write MBW, continue
                        state = `FRQ_IDLE;
//                    end
//                end
//                else begin
//                    byte_idx = byte_idx - 1;
//                    if(byte_idx == 0) begin
//                        // 3 bytes are in MBW fifo at top level, queue request to write
//                        spi_wr_en_o <= 0;
//                        spiwr_queue_data_o <= `MBW;    // queue request for MSYN write
//                        spiwr_queue_wr_en_o <= 1;       // spi queue fifo write enable
//                    end
//                    else begin
//                        shift = (`MBW_BYTES - byte_idx) << 3;
//                        spi_o <= (tmp32 >> shift);
//                    end
//                end
            end
            default:
                begin
                    status_o = `ERR_UNKNOWN_FRQ_STATE;
                    state = `FRQ_IDLE;
                end
            endcase
        end
    end
`else
    /*  S4 frequency processor
        fout = 229 * 100E6 * (DDS/2**32) ==> DDS * 5.3318 Hz ~ DDS * 5Hz
        
        fout = 2400MHz, DDS = (2400 * 2**32)/100E6/229 ==> 450.1275
        with truncation == 450.126, ~no diff! 
        
        
        AD9954 DDS ==> program N, output frequency is 100 * N/2**32
        Fs, system clock, = 100MHz. Page 14 of datasheet, "DDS Core"
        So Fout(DDS) = N * 100 / 2**32 (N = FTW)
    
    
    
    */
        


`endif    
endmodule
