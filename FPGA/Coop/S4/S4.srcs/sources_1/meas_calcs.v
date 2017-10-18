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

module meas_calcs(

    input  wire         sys_clk,
    input  wire         sys_rst_n,
  
    input  wire         cal_i,              // do calibration
    input  wire         pwr_i,              // do power calculation
    output wire         done_o,             // calculation done

    input  wire [31:0]  adcf_dat_i,         // [xx][FWDQ][xx][FWDI]
    input  wire [31:0]  adcr_dat_i,         // [xx][RFLQ][xx][RFLI]

    output reg  [31:0]  adcf_dat_o,         // [16 bits calibrated FWDQ][16 bits calibrated FWDI]
    output reg  [31:0]  adcr_dat_o,         // [16 bits calibrated RFLQ][16 bits calibrated RFLI]

    // ZMON cal data registers
    input  wire [31:0]  zm_fi_gain_i,       // zmon fwd "I" ADC gain, Q15.16 float
    input  wire [15:0]  zm_fi_offset_i,     // zmon fwd "I" ADC offset, signed int
    input  wire [31:0]  zm_fq_gain_i,       // zmon fwd "Q" ADC gain, Q15.16 float
    input  wire [15:0]  zm_fq_offset_i,     // zmon fwd "Q" ADC offset, signed int
    input  wire [31:0]  zm_ri_gain_i,       // zmon refl "I" ADC gain, Q15.16 float
    input  wire [15:0]  zm_ri_offset_i,     // zmon refl "I" ADC offset, signed int
    input  wire [31:0]  zm_rq_gain_i,       // zmon refl "Q" ADC gain, Q15.16 float
    input  wire [15:0]  zm_rq_offset_i,     // zmon refl "Q" ADC offset, signed int
    );

    // Calibration definitions, registers
    localparam CAL1     = 3'd1; // idle state
    localparam CAL2     = 3'd2;
    localparam CAL3     = 3'd3;
    localparam CAL4     = 3'd4;    
    localparam CAL5     = 3'd5;    
    localparam CAL6     = 3'd6;    
    localparam CAL7     = 3'd7;    
    localparam CAL8     = 3'd8;    
    localparam CAL_MULT = 3'd9;    
    reg  [3:0]      cal_state;
    reg  [3:0]      next_state;
    reg  [15:0]     cal_tmp1;
    reg  [15:0]     cal_tmp2;
    reg  [15:0]     cal_tmp3;
    reg  [15:0]     cal_tmp4;
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
        .A({16'd0, cal_tmp1}),
        .B(zm_fi_gain_i),
        .CE(multiply),
        .P(adc1_cald)
    );      
    ftw_mult adc2_multiplier (
        .CLK(sys_clk),
        .A({16'd0, cal_tmp2}),
        .B(zm_fq_gain_i),
        .CE(multiply),
        .P(adc2_cald)
    );      
    ftw_mult adc3_multiplier (
        .CLK(sys_clk),
        .A({16'd0, cal_tmp3}),
        .B(zm_ri_gain_i),
        .CE(multiply),
        .P(adc3_cald)
    );      
    ftw_mult adc4_multiplier (
        .CLK(sys_clk),
        .A({16'd0, cal_tmp4}),
        .B(zm_rq_gain_i),
        .CE(multiply),
        .P(adc4_cald)
    );      

    // Do calibration
    // V = gain * (offset + Vadc)
    // Gain is Q15.16 floating point
    // Offset is 16-bit signed int
    always @(posedge sys_clk) begin
        if(!sys_rst_n) begin
            cal_state <= CAL1;
        end
        else begin
            case(cal_state)
            CAL1: begin
                // registers always loaded, state=>CAL2 to start
                cal_tmp1 <= { 2'b00, adcf_dat[31:18]};
                cal_tmp2 <= { 2'b00, adcf_dat[15:2] };
                cal_tmp3 <= { 2'b00, adcr_dat[31:18]};
                cal_tmp4 <= { 2'b00, adcr_dat[15:2] };
            end
            CAL2: begin
                // cal_tmp => [XX][14 bits ADC]
                // sign extend bipolar values            
                if(cal_tmp1[13] == 1'b1)             
                    cal_tmp1 <= {2'b11, cal_tmp1[13:0]};
                if(cal_tmp2[13] == 1'b1)             
                    cal_tmp2 <= {2'b11, cal_tmp2[13:0]};
                if(cal_tmp3[13] == 1'b1)             
                    cal_tmp3 <= {2'b11, cal_tmp3[13:0]};
                if(cal_tmp4[13] == 1'b1)             
                    cal_tmp4 <= {2'b11, cal_tmp4[13:0]};
                cal_state <= CAL3;
            end
            CAL3: begin
                cal_tmp1 <= cal_tmp1 + zm_fi_offset_i;            
                cal_tmp2 <= cal_tmp2 + zm_fq_offset_i;            
                cal_tmp3 <= cal_tmp3 + zm_ri_offset_i;            
                cal_tmp4 <= cal_tmp4 + zm_rq_offset_i;            
                cal_state <= CAL4;
            end
            CAL4: begin
                latency_counter <= MULTIPLIER_CLOCKS;
                multiply <= 1'b1;
                next_state <= CAL5;
                cal_state <= CAL_MULT;
            end
            CAL5: begin
                if(adc1_cald[31] == 1'b1)
                    cal_tmp1 <= adc1_cald[63:32] + 32'd1;
                else             
                    cal_tmp1 <= adc1_cald[63:32];
                //
                if(adc2_cald[31] == 1'b1)
                    cal_tmp2 <= adc2_cald[63:32] + 32'd1;
                else             
                    cal_tmp2 <= adc2_cald[63:32];
                //
                if(adc3_cald[31] == 1'b1)
                    cal_tmp3 <= adc3_cald[63:32] + 32'd1;
                else             
                    cal_tmp3 <= adc3_cald[63:32];
                //
                if(adc4_cald[31] == 1'b1)
                    cal_tmp4 <= adc4_cald[63:32] + 32'd1;
                else             
                    cal_tmp4 <= adc1_cald[63:32];
                cal_state <= CAL6;
            end
            CAL6: begin
                // done, write results to output fifo.
                adc_fifo_dat_o <= {cal_tmp2, cal_tmp1};
                adc_fifo_wen_o <= 1'b1;                // write ADCF data
                cal_state <= CAL7;
            end
            CAL7: begin                
                adc_fifo_dat_o <= {cal_tmp4, cal_tmp3};
                adc_fifo_wen_o <= 1'b1;                // write ADCF data                
                cal_state <= CAL8;
            end
            CAL8: begin
                // done
                adc_fifo_wen_o <= 1'b0;          
                cal_state <= CAL1;
            end
            CAL_MULT: begin           
                if(latency_counter == 0) begin
                    state <= next_state;
                    multiply <= 1'b0;
                end
                else
                    latency_counter <= latency_counter - 1;
            end
            endcase
        end    
    end

endmodule
