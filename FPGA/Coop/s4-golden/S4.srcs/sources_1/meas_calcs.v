`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: Ampleon USA
// Engineer: Rick Rigby
// 
// Create Date: 10/18/2017 04:40:22 PM
// Design Name: 
// Module Name: meas_calcs
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: Perform calculations/calibration on ADC results
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

module meas_calcs(

    input  wire         sys_clk,
    input  wire         sys_rst_n,
  
    input  wire [7:0]   ops_i,              // which operation(s)
    input  wire         run_i,              // do it
    output reg          done_o,             // calculation done

    input  wire [31:0]  adcf_dat_i,         // Raw MEAS ADC fifo data, [xx][FWDQ][xx][FWDI]
    input  wire [31:0]  adcr_dat_i,         // Raw MEAS ADC fifo data, [xx][RFLQ][xx][RFLI]

    output wire [31:0]  adcf_dat_o,         // [16 bits calibrated FWDQ][16 bits calibrated FWDI] (ops_i[M_ADC])
                                            // [Q15.16 format calibrated FWDI voltage] (ops_i[M_VOLTS])
    output wire [31:0]  adcr_dat_o,         // [16 bits calibrated RFLQ][16 bits calibrated RFLI] (ops_i[M_ADC])
                                            // [Q15.16 format calibrated RFLI voltage] (ops_i[M_VOLTS])
    output wire [31:0]  adcfq_volts_o,      // [Q15.16 format calibrated FWDQ voltage] (ops_i[M_VOLTS])
    output wire [31:0]  adcrq_volts_o,      // [Q15.16 format calibrated RFLQ voltage] (ops_i[M_VOLTS])

    // ZMON cal data registers
    input  wire [31:0]  zm_fi_gain_i,       // zmon fwd "I" ADC gain, Q15.16 float
    input  wire [15:0]  zm_fi_offset_i,     // zmon fwd "I" ADC offset, signed int
    input  wire [31:0]  zm_fq_gain_i,       // zmon fwd "Q" ADC gain, Q15.16 float
    input  wire [15:0]  zm_fq_offset_i,     // zmon fwd "Q" ADC offset, signed int
    input  wire [31:0]  zm_ri_gain_i,       // zmon refl "I" ADC gain, Q15.16 float
    input  wire [15:0]  zm_ri_offset_i,     // zmon refl "I" ADC offset, signed int
    input  wire [31:0]  zm_rq_gain_i,       // zmon refl "Q" ADC gain, Q15.16 float
    input  wire [15:0]  zm_rq_offset_i      // zmon refl "Q" ADC offset, signed int
    );

    reg  [31:0]     adcf_dat;               // [16 bits calibrated FWDQ][16 bits calibrated FWDI]
    reg  [31:0]     adcr_dat;               // [16 bits calibrated RFLQ][16 bits calibrated RFLI]
    reg  [31:0]     adcfq_volts;            
    reg  [31:0]     adcrq_volts;            
    assign adcf_dat_o = adcf_dat;           // [16 bits calibrated FWDQ][16 bits calibrated FWDI]
    assign adcr_dat_o = adcr_dat;           // [16 bits calibrated RFLQ][16 bits calibrated RFLI]
    assign adcfq_volts_o = adcfq_volts;     // FWDQ Q15.16 volts
    assign adcrq_volts_o = adcrq_volts;     // RFLQ Q15.16 volts
    
    reg             runr;                   // Run on rising edge of run_i

    // Calibration definitions, registers
    localparam CAL_IDLE = 4'd0; // idle state
    localparam CAL1     = 4'd1;
    localparam CAL2     = 4'd2;
    localparam CAL3     = 4'd3;
    localparam CAL4     = 4'd4;    
    localparam CAL5     = 4'd5;    
    localparam CAL_DONE = 4'd6;    
    localparam CAL7     = 4'd7;    
    localparam CAL8     = 4'd8;    
    localparam CAL_MULT = 4'd9;    
    localparam VOLTS1   = 4'd10;
    localparam VOLTS2   = 4'd11;
    reg  [3:0]      cal_state;
    reg  [3:0]      next_state;
    reg  [31:0]     cal_tmp1;
    reg  [31:0]     cal_mult1;
    reg  [31:0]     cal_tmp2;
    reg  [31:0]     cal_mult2;
    reg  [31:0]     cal_tmp3;
    reg  [31:0]     cal_mult3;
    reg  [31:0]     cal_tmp4;
    reg  [31:0]     cal_mult4;
    // Multiplier for calibration, do 4 adc's in parallel
    wire [63:0]     adc1_cald;              // calibrated adc1 output
    wire [63:0]     adc2_cald;              // calibrated adc2 output
    wire [63:0]     adc3_cald;              // calibrated adc3 output
    wire [63:0]     adc4_cald;              // calibrated adc4 output
    reg             multiply;
  // Latency for multiply operation, Xilinx multiplier
    localparam MULTIPLIER_CLOCKS = 6'd6;
    reg  [5:0]      latency_counter;        // wait for multiplier 
    // Xilinx multiplier to perform 32 bit multiplication, output is 64 bits
    ftw_mult adc1_multiplier (
        .CLK(sys_clk),
        .A(cal_tmp1),
        .B(cal_mult1),
        .CE(multiply),
        .P(adc1_cald)
    );      
    ftw_mult adc2_multiplier (
        .CLK(sys_clk),
        .A(cal_tmp2),
        .B(cal_mult2),
        .CE(multiply),
        .P(adc2_cald)
    );      
    ftw_mult adc3_multiplier (
        .CLK(sys_clk),
        .A(cal_tmp3),
        .B(cal_mult3),
        .CE(multiply),
        .P(adc3_cald)
    );      
    ftw_mult adc4_multiplier (
        .CLK(sys_clk),
        .A(cal_tmp4),
        .B(cal_mult4),
        .CE(multiply),
        .P(adc4_cald)
    );      

    // Multiplier for voltage conversion
    //localparam LTC_OFFSET = 32'd81920;  // 65536 * 1.25
    localparam LSB_K      = 32'd10;     // 2.5 * 2^16 / 16384 => 10.0 (Q15.16 format LSB)
    
    //
    // Do calibration of raw adc values
    // AdcLsbs = gain * (offset(Lsbs) + AdcRaw)
    // Gain is Q15.16 floating point
    // Offset is 16-bit signed int in 152uV LSB's
    //
    always @(posedge sys_clk) begin    
        if(!sys_rst_n) begin
            cal_state <= CAL_IDLE;
            done_o <= 1'b0;
            runr <= 1'b0;
        end
        else begin        
            runr <= run_i;
            if(run_i && !runr)
                cal_state <= CAL1;  // start on rising edge of run_i signal
            else if(!run_i) begin
                cal_state <= CAL_IDLE;
                done_o <= 1'b0;
            end
            
            case(cal_state)
//                CAL_IDLE: begin
//                    cal_state <= CAL1;
//                end
            CAL1: begin
                cal_tmp1 <= {16'd0, adcf_dat_i[15:0]};
                cal_mult1 <= zm_fi_gain_i;
                cal_tmp2 <= {16'd0, adcf_dat_i[31:16]};
                cal_mult2 <= zm_fq_gain_i;
                cal_tmp3 <= {16'd0, adcr_dat_i[15:0]};
                cal_mult3 <= zm_ri_gain_i;
                cal_tmp4 <= {16'd0, adcr_dat_i[31:16]};
                cal_mult4 <= zm_rq_gain_i;
                cal_state <= CAL2;
            end
            CAL2: begin
                // cal_tmp => [XX][14 bits ADC]
                // sign extend bipolar values            
                if(cal_tmp1[13])             
                    cal_tmp1 <= {18'b1111_1111_1111_1111_11, cal_tmp1[13:0]};
                if(cal_tmp2[13])             
                    cal_tmp2 <= {18'b1111_1111_1111_1111_11, cal_tmp2[13:0]};
                if(cal_tmp3[13])             
                    cal_tmp3 <= {18'b1111_1111_1111_1111_11, cal_tmp3[13:0]};
                if(cal_tmp4[13])             
                    cal_tmp4 <= {18'b1111_1111_1111_1111_11, cal_tmp4[13:0]};
                cal_state <= CAL3;
            end
            CAL3: begin
                if(!ops_i[0])
                    cal_state <= CAL_DONE;      // just copy signed int's to output
                else begin
                    if(zm_fi_offset_i[15])
                        cal_tmp1 <= cal_tmp1 + {16'hffff,zm_fi_offset_i};
                    else
                        cal_tmp1 <= cal_tmp1 + {16'd0,zm_fi_offset_i};
                    if(zm_fq_offset_i[15])
                        cal_tmp2 <= cal_tmp2 + {16'hffff,zm_fq_offset_i};            
                    else
                        cal_tmp2 <= cal_tmp2 + {16'd0,zm_fq_offset_i};            
                    if(zm_ri_offset_i[15])
                        cal_tmp3 <= cal_tmp3 + {16'hffff,zm_ri_offset_i};            
                    else
                        cal_tmp3 <= cal_tmp3 + {16'd0,zm_ri_offset_i};
                    if(zm_rq_offset_i[15])            
                        cal_tmp4 <= cal_tmp4 + {16'hffff,zm_rq_offset_i};            
                    else
                        cal_tmp4 <= cal_tmp4 + {16'd0,zm_rq_offset_i};
                    cal_state <= CAL4;
                end
            end
            CAL4: begin
                latency_counter <= MULTIPLIER_CLOCKS;
                multiply <= 1'b1;
                next_state <= CAL5;
                cal_state <= CAL_MULT;
            end
            CAL5: begin
                if(adc1_cald[15])
                    cal_tmp1 <= adc1_cald[47:16] + 32'd1;
                else             
                    cal_tmp1 <= adc1_cald[47:16];
                //
                if(adc2_cald[15])
                    cal_tmp2 <= adc2_cald[47:16] + 32'd1;
                else             
                    cal_tmp2 <= adc2_cald[47:16];
                //
                if(adc3_cald[15])
                    cal_tmp3 <= adc3_cald[47:16] + 32'd1;
                else           
                    cal_tmp3 <= adc3_cald[47:16];
                //
                if(adc4_cald[15])
                    cal_tmp4 <= adc4_cald[47:16] + 32'd1;
                else             
                    cal_tmp4 <= adc4_cald[47:16];
                cal_state <= CAL_DONE;
            end
            CAL_DONE: begin
                // done cal, format output as needed
                if(ops_i[1]) begin
                    adcf_dat <= {cal_tmp2[15:0], cal_tmp1[15:0]};
                    adcr_dat <= {cal_tmp4[15:0], cal_tmp3[15:0]};
                    done_o <= 1'b1;
                    cal_state <= CAL_IDLE;
                end
                else if(ops_i[2]) begin
                    cal_state <= VOLTS1;
                end
                else if(ops_i[3]) begin
                
    
                    // not done yet
                    cal_state <= CAL_IDLE;
    
                end
                else // ? error of some sort
                    cal_state <= CAL_IDLE;
            end
            CAL_MULT: begin           
                if(latency_counter == 0) begin
                    cal_state <= next_state;
                    multiply <= 1'b0;
                end
                else
                    latency_counter <= latency_counter - 1;
            end
    
            // Convert adc values into volts
            // AdcLsbs = gain * (offset(Lsbs) + AdcRaw)
            // V = (AdcLsbs * 153uV) 
            //
            // ADC's have 153uv resolution (2.5v reference, 14 bits)
            // Input/result is between -1.25 & +1.25v
            // 
            // Part 1:
            // V = Adc * 2.5/16384 ==> (Adc * (2.5/16384) * 2^16) / 2^16
            // 2.5 * 2^16 / 16384 = 10.0
            // Part 2: V[Q15.16] - 1.25[Q15.16] should give valid result.
            VOLTS1: begin
                cal_mult1 <= LSB_K;             
                cal_mult2 <= LSB_K;             
                cal_mult3 <= LSB_K;             
                cal_mult4 <= LSB_K;
                latency_counter <= MULTIPLIER_CLOCKS;
                multiply <= 1'b1;             
                next_state <= VOLTS2;
                cal_state <= CAL_MULT;
            end
            VOLTS2: begin
                adcf_dat[31:0]     <= adc1_cald[31:0]; // - LTC_OFFSET;            
                adcfq_volts[31:0]  <= adc2_cald[31:0]; // - LTC_OFFSET;            
                adcr_dat[31:0]     <= adc3_cald[31:0]; // - LTC_OFFSET;            
                adcrq_volts[31:0]  <= adc4_cald[31:0]; // - LTC_OFFSET;            
                done_o <= 1'b1;
                cal_state <= CAL_IDLE;
            end
            endcase
        end
//        else begin
//                cal_state <= CAL_IDLE;
//                done_o <= 1'b0;
//            end    
    end

endmodule
