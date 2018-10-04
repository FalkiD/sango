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

    input  wire [31:0]  adcf_dat_i,         // Raw MEAS ADC fifo data, [FWDI][00][FWDQ][00]
    input  wire [31:0]  adcr_dat_i,         // Raw MEAS ADC fifo data, [RFLI][00][RFLQ][00]

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

    // Pfwd = (VimF^2 + VreF^2)/50
    // PRfl = (VimR^2 + VreR^2)/50
    // re=I, im=Q

    reg  [31:0]     adcf_dat;               // [16 bits calibrated FWDQ][16 bits calibrated FWDI] (re=I, im=Q)
    reg  [31:0]     adcr_dat;               // [16 bits calibrated RFLQ][16 bits calibrated RFLI] 
    reg  [31:0]     adcfq_volts;            
    reg  [31:0]     adcrq_volts;            
    assign adcf_dat_o = adcf_dat;           // [16 bits calibrated FWDQ][16 bits calibrated FWDI]
    assign adcr_dat_o = adcr_dat;           // [16 bits calibrated RFLQ][16 bits calibrated RFLI]
    assign adcfq_volts_o = adcfq_volts;     // FWDQ Q15.16 volts
    assign adcrq_volts_o = adcrq_volts;     // RFLQ Q15.16 volts

    wire [31:0]     zm_fi_offset;           // 32-bit signed versions of cal inputs
    wire [31:0]     zm_fq_offset;           // 32-bit signed versions of cal inputs
    wire [31:0]     zm_ri_offset;           // 32-bit signed versions of cal inputs
    wire [31:0]     zm_rq_offset;           // 32-bit signed versions of cal inputs
    assign zm_fi_offset = zm_fi_offset_i[15] ? {16'hffff, zm_fi_offset_i} : {16'h0000, zm_fi_offset_i};
    assign zm_fq_offset = zm_fq_offset_i[15] ? {16'hffff, zm_fq_offset_i} : {16'h0000, zm_fq_offset_i};
    assign zm_ri_offset = zm_ri_offset_i[15] ? {16'hffff, zm_ri_offset_i} : {16'h0000, zm_ri_offset_i};
    assign zm_rq_offset = zm_rq_offset_i[15] ? {16'hffff, zm_rq_offset_i} : {16'h0000, zm_rq_offset_i};
    
    reg             runr;                   // Run on rising edge of run_i

    // Build a table of power in watts entries at 0.1dBm steps between 50.0 and 61.0
    reg  [31:0]     volts_to_dbm [0:110];   // 111 entries, voltage value for each 0.1dBm step into 50 ohm load
    reg  [15:0]     dbm [0:110];            // 111 entries, Q7.8 dBm value for each 0.1dBm step
    reg  [6:0]      ptbl_idx;               // power table index
    localparam  CAL_TBL_MAX = 7'd110;

    // Calibration definitions, registers
    localparam CAL_IDLE = 4'd0; // idle state
    localparam CAL1     = 4'd1;
    localparam CAL2     = 4'd2;
    localparam CAL3     = 4'd3;
    localparam CAL4     = 4'd4;    
    localparam CAL5     = 4'd5;    
    localparam CAL6     = 4'd6;    
    localparam CAL7     = 4'd7;    
    localparam CAL8     = 4'd8;
    localparam CAL9     = 4'd9;    
    localparam CAL_MULT = 4'd10;    
    localparam CAL_DBM  = 4'd11;
    localparam CAL_INIT = 4'd12;
    localparam CAL_DONE = 4'd13;
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
//    reg  [63:0]     sumvsquared_f;          // fwd sum of squared voltages
//    reg  [63:0]     sumvsquared_r;          // rfl sum of squared voltages    
    reg             multiply;
//    reg  [7:0]      dbm_index;              // index to lookup matching sumsquared<<16 value
//    reg  [7:0]      dbm_fwd_idx;
//    reg  [7:0]      dbm_rfl_idx;
//    reg             dbm_f_done;
//    reg             dbm_r_done;
    // Latency for multiply operation, Xilinx multiplier
    localparam MULTIPLIER_CLOCKS = 6'd6;
    reg  [5:0]      latency_counter;        // wait for multiplier 
    // Xilinx multiplier to perform 32 bit multiplication, output is 64 bits
    interp_mult adc1_multiplier (
        .CLK(sys_clk),
        .A(cal_tmp1),
        .B(cal_mult1),
        .CE(multiply),
        .P(adc1_cald)
    );      
    interp_mult adc2_multiplier (
        .CLK(sys_clk),
        .A(cal_tmp2),
        .B(cal_mult2),
        .CE(multiply),
        .P(adc2_cald)
    );      
    interp_mult adc3_multiplier (
        .CLK(sys_clk),
        .A(cal_tmp3),
        .B(cal_mult3),
        .CE(multiply),
        .P(adc3_cald)
    );      
    interp_mult adc4_multiplier (
        .CLK(sys_clk),
        .A(cal_tmp4),
        .B(cal_mult4),
        .CE(multiply),
        .P(adc4_cald)
    );      

    //
    // Do calibration of raw adc values
    // AdcLsbs = gain * (offset(Lsbs) + AdcRaw)
    // Gain is Q15.16 floating point
    // Offset is 16-bit signed int
    // ADC is bipolar, used signed multiplier (05-Sep-2018)
    //
    always @(posedge sys_clk) begin    
        if(!sys_rst_n) begin
            cal_state <= CAL_INIT;
            done_o <= 1'b0;
            runr <= 1'b0;
            //ptbl_idx <= 7'b000_0000;
        end
        else begin        
            runr <= run_i;
            if(run_i && !runr)
                cal_state <= CAL1;  // start on rising edge of run_i signal
            else if(!run_i) begin
                //cal_state <= CAL_IDLE;
                done_o <= 1'b0;
            end
            
            case(cal_state)
            CAL_INIT: begin
// 10-Sep-2018 dBm out not really needed
//                case(ptbl_idx)
//                0: begin            // 50.0dBm in Q15.16 volts across 50 ohm load
//                    volts_to_dbm[0] <= 32'h13880000;
//                    dbm[0] <= 16'd12800;    // 50.0 in Q7.8 format
//                end
//                1: begin
//                    volts_to_dbm[1] <= 32'h13fc7707;
//                    dbm[1] <= 16'd12825;
//                end
//                2: begin
//                    volts_to_dbm[2] <= 32'h1473a48a;
//                    dbm[2] <= 16'd12851;
//                end
//                3: begin
//                    volts_to_dbm[3] <= 32'h14ed98b5;
//                    dbm[3] <= 16'd12876;
//                end
//                4: begin
//                    volts_to_dbm[4] <= 32'h156a6417;
//                    dbm[4] <= 16'd12902;
//                end
//                5: begin
//                    volts_to_dbm[5] <= 32'h15ea179f;
//                    dbm[5] <= 16'd12928;
//                end
//                6: begin
//                    volts_to_dbm[6] <= 32'h166cc4a2;
//                    dbm[6] <= 16'd12953;
//                end
//                7: begin
//                    volts_to_dbm[7] <= 32'h16f27cde;
//                    dbm[7] <= 16'd12979;
//                end
//                8: begin
//                    volts_to_dbm[8] <= 32'h177b5279;
//                    dbm[8] <= 16'd13004;
//                end
//                9: begin
//                    volts_to_dbm[9] <= 32'h18075806;
//                    dbm[9] <= 16'd13030;
//                end
//                10: begin            // 51.0dBm in Q15.16 volts across 50 ohm load
//                    volts_to_dbm[10] <= 32'h1896a086;
//                    dbm[10] <= 16'd13056;
//                end
//                11: begin
//                    volts_to_dbm[11] <= 32'h19293f6d;
//                    dbm[11] <= 16'd13081;
//                end
//                12: begin
//                    volts_to_dbm[12] <= 32'h19bf48a0;
//                    dbm[12] <= 16'd13107;
//                end
//                13: begin
//                    volts_to_dbm[13] <= 32'h1a58d07d;
//                    dbm[13] <= 16'd13132;
//                end
//                14: begin
//                    volts_to_dbm[14] <= 32'h1af5ebdb;
//                    dbm[14] <= 16'd13158;
//                end
//                15: begin
//                    volts_to_dbm[15] <= 32'h1b96b00e;
//                    dbm[15] <= 16'd13184;
//                end
//                16: begin
//                    volts_to_dbm[16] <= 32'h1c3b32e8;
//                    dbm[16] <= 16'd13209;
//                end
//                17: begin
//                    volts_to_dbm[17] <= 32'h1ce38abc;
//                    dbm[17] <= 16'd13235;
//                end
//                18: begin
//                    volts_to_dbm[18] <= 32'h1d8fce65;
//                    dbm[18] <= 16'd13260;
//                end
//                19: begin
//                    volts_to_dbm[19] <= 32'h1e401545;
//                    dbm[19] <= 16'd13286;
//                end
//                20: begin            // 52.0dBm in Q15.16 volts across 50 ohm load
//                    volts_to_dbm[20] <= 32'h1ef47749;
//                    dbm[20] <= 16'd13312;
//                end
//                21: begin
//                    volts_to_dbm[21] <= 32'h1fad0cec;
//                    dbm[21] <= 16'd13337;
//                end
//                22: begin
//                    volts_to_dbm[22] <= 32'h2069ef3d;
//                    dbm[22] <= 16'd13363;
//                end
//                23: begin
//                    volts_to_dbm[23] <= 32'h212b37e0;
//                    dbm[23] <= 16'd13388;
//                end
//                24: begin
//                    volts_to_dbm[24] <= 32'h21f1010f;
//                    dbm[24] <= 16'd13414;
//                end
//                25: begin
//                    volts_to_dbm[25] <= 32'h22bb65a5;
//                    dbm[25] <= 16'd13440;
//                end
//                26: begin
//                    volts_to_dbm[26] <= 32'h238a8119;
//                    dbm[26] <= 16'd13465;
//                end
//                27: begin
//                    volts_to_dbm[27] <= 32'h245e6f88;
//                    dbm[27] <= 16'd13491;
//                end
//                28: begin
//                    volts_to_dbm[28] <= 32'h25374db8;
//                    dbm[28] <= 16'd13516;
//                end
//                29: begin
//                    volts_to_dbm[29] <= 32'h26153916;
//                    dbm[29] <= 16'd13542;
//                end
//                30: begin            // 53.0dBm in Q15.16 volts across 50 ohm load
//                    volts_to_dbm[30] <= 32'h26f84fc3;
//                    dbm[30] <= 16'd13568;
//                end
//                31: begin
//                    volts_to_dbm[31] <= 32'h27e0b091;
//                    dbm[31] <= 16'd13593;
//                end
//                32: begin
//                    volts_to_dbm[32] <= 32'h28ce7b0c;
//                    dbm[32] <= 16'd13619;
//                end
//                33: begin
//                    volts_to_dbm[33] <= 32'h29c1cf79;
//                    dbm[33] <= 16'd13644;
//                end
//                34: begin
//                    volts_to_dbm[34] <= 32'h2abacee0;
//                    dbm[34] <= 16'd13670;
//                end
//                35: begin
//                    volts_to_dbm[35] <= 32'h2bb99b0e;
//                    dbm[35] <= 16'd13696;
//                end
//                36: begin
//                    volts_to_dbm[36] <= 32'h2cbe5698;
//                    dbm[36] <= 16'd13721;
//                end
//                37: begin
//                    volts_to_dbm[37] <= 32'h2dc924e2;
//                    dbm[37] <= 16'd13747;
//                end
//                38: begin
//                    volts_to_dbm[38] <= 32'h2eda2a22;
//                    dbm[38] <= 16'd13772;
//                end
//                39: begin
//                    volts_to_dbm[39] <= 32'h2ff18b69;
//                    dbm[39] <= 16'd13798;
//                end
//                40: begin            // 54.0dBm in Q15.16 volts across 50 ohm load
//                    volts_to_dbm[40] <= 32'h310f6ea1;
//                    dbm[40] <= 16'd13824;
//                end
//                41: begin
//                    volts_to_dbm[41] <= 32'h3233fa9a;
//                    dbm[41] <= 16'd13849;
//                end
//                42: begin
//                    volts_to_dbm[42] <= 32'h335f5707;
//                    dbm[42] <= 16'd13875;
//                end
//                43: begin
//                    volts_to_dbm[43] <= 32'h3491ac8c;
//                    dbm[43] <= 16'd13900;
//                end
//                44: begin
//                    volts_to_dbm[44] <= 32'h35cb24bd;
//                    dbm[44] <= 16'd13926;
//                end
//                45: begin
//                    volts_to_dbm[45] <= 32'h370bea26;
//                    dbm[45] <= 16'd13952;
//                end
//                46: begin
//                    volts_to_dbm[46] <= 32'h38542852;
//                    dbm[46] <= 16'd13977;
//                end
//                47: begin
//                    volts_to_dbm[47] <= 32'h39a40bcf;
//                    dbm[47] <= 16'd14003;
//                end
//                48: begin
//                    volts_to_dbm[48] <= 32'h3afbc233;
//                    dbm[48] <= 16'd14028;
//                end
//                49: begin
//                    volts_to_dbm[49] <= 32'h3c5b7a27;
//                    dbm[49] <= 16'd14054;
//                end
//                50: begin            // 55.0dBm in Q15.16 volts across 50 ohm load
//                    volts_to_dbm[50] <= 32'h3dc36367;
//                    dbm[50] <= 16'd14080;
//                end
//                51: begin
//                    volts_to_dbm[51] <= 32'h3f33aecf;
//                    dbm[51] <= 16'd14105;
//                end
//                52: begin
//                    volts_to_dbm[52] <= 32'h40ac8e5a;
//                    dbm[52] <= 16'd14131;
//                end
//                53: begin
//                    volts_to_dbm[53] <= 32'h422e3532;
//                    dbm[53] <= 16'd14156;
//                end
//                54: begin
//                    volts_to_dbm[54] <= 32'h43b8d7af;
//                    dbm[54] <= 16'd14182;
//                end
//                55: begin
//                    volts_to_dbm[55] <= 32'h454cab61;
//                    dbm[55] <= 16'd14208;
//                end
//                56: begin
//                    volts_to_dbm[56] <= 32'h46e9e719;
//                    dbm[56] <= 16'd14233;
//                end
//                57: begin
//                    volts_to_dbm[57] <= 32'h4890c2ee;
//                    dbm[57] <= 16'd14259;
//                end
//                58: begin
//                    volts_to_dbm[58] <= 32'h4a417845;
//                    dbm[58] <= 16'd14284;
//                end
//                59: begin
//                    volts_to_dbm[59] <= 32'h4bfc41db;
//                    dbm[59] <= 16'd14310;
//                end
//                60: begin            // 56.0dBm in Q15.16 volts across 50 ohm load
//                    volts_to_dbm[60] <= 32'h4dc15bc8;
//                    dbm[60] <= 16'd14336;
//                end
//                61: begin
//                    volts_to_dbm[61] <= 32'h4f91038e;
//                    dbm[61] <= 16'd14361;
//                end
//                62: begin
//                    volts_to_dbm[62] <= 32'h516b781b;
//                    dbm[62] <= 16'd14387;
//                end
//                63: begin
//                    volts_to_dbm[63] <= 32'h5350f9d7;
//                    dbm[63] <= 16'd14412;
//                end
//                64: begin
//                    volts_to_dbm[64] <= 32'h5541caa7;
//                    dbm[64] <= 16'd14438;
//                end
//                65: begin
//                    volts_to_dbm[65] <= 32'h573e2dfa;
//                    dbm[65] <= 16'd14464;
//                end
//                66: begin
//                    volts_to_dbm[66] <= 32'h594668d3;
//                    dbm[66] <= 16'd14489;
//                end
//                67: begin
//                    volts_to_dbm[67] <= 32'h5b5ac1ce;
//                    dbm[67] <= 16'd14515;
//                end
//                68: begin
//                    volts_to_dbm[68] <= 32'h5d7b812e;
//                    dbm[68] <= 16'd14540;
//                end
//                69: begin
//                    volts_to_dbm[69] <= 32'h5fa8f0e3;
//                    dbm[69] <= 16'd14566;
//                end
//                70: begin            // 57.0dBm in Q15.16 volts across 50 ohm load
//                    volts_to_dbm[70] <= 32'h61e35c97;
//                    dbm[70] <= 16'd14592;
//                end
//                71: begin
//                    volts_to_dbm[71] <= 32'h642b11b7;
//                    dbm[71] <= 16'd14617;
//                end
//                72: begin
//                    volts_to_dbm[72] <= 32'h66805f7d;
//                    dbm[72] <= 16'd14643;
//                end
//                73: begin
//                    volts_to_dbm[73] <= 32'h68e396fe;
//                    dbm[73] <= 16'd14668;
//                end
//                74: begin
//                    volts_to_dbm[74] <= 32'h6b550b2f;
//                    dbm[74] <= 16'd14694;
//                end
//                75: begin
//                    volts_to_dbm[75] <= 32'h6dd510f6;
//                    dbm[75] <= 16'd14720;
//                end
//                76: begin
//                    volts_to_dbm[76] <= 32'h7063ff32;
//                    dbm[76] <= 16'd14745;
//                end
//                77: begin
//                    volts_to_dbm[77] <= 32'h73022ec9;
//                    dbm[77] <= 16'd14771;
//                end
//                78: begin
//                    volts_to_dbm[78] <= 32'h75affab3;
//                    dbm[78] <= 16'd14796;
//                end
//                79: begin
//                    volts_to_dbm[79] <= 32'h786dc006;
//                    dbm[79] <= 16'd14822;
//                end
//                80: begin            // 58.0dBm in Q15.16 volts across 50 ohm load
//                    volts_to_dbm[80] <= 32'h7b3bde02;
//                    dbm[80] <= 16'd14848;
//                end
//                81: begin
//                    volts_to_dbm[81] <= 32'h7e1ab621;
//                    dbm[81] <= 16'd14873;
//                end
//                82: begin
//                    volts_to_dbm[82] <= 32'h810aac22;
//                    dbm[82] <= 16'd14899;
//                end
//                83: begin
//                    volts_to_dbm[83] <= 32'h840c2615;
//                    dbm[83] <= 16'd14924;
//                end
//                84: begin
//                    volts_to_dbm[84] <= 32'h871f8c6d;
//                    dbm[84] <= 16'd14950;
//                end
//                85: begin
//                    volts_to_dbm[85] <= 32'h8a454a0a;
//                    dbm[85] <= 16'd14976;
//                end
//                86: begin
//                    volts_to_dbm[86] <= 32'h8d7dcc49;
//                    dbm[86] <= 16'd15001;
//                end
//                87: begin
//                    volts_to_dbm[87] <= 32'h90c98316;
//                    dbm[87] <= 16'd15027;
//                end
//                88: begin
//                    volts_to_dbm[88] <= 32'h9428e0f5;
//                    dbm[88] <= 16'd15052;
//                end
//                89: begin
//                    volts_to_dbm[89] <= 32'h979c5b17;
//                    dbm[89] <= 16'd15078;
//                end
//                90: begin            // 59.0dBm in Q15.16 volts across 50 ohm load
//                    volts_to_dbm[90] <= 32'h9b246967;
//                    dbm[90] <= 16'd15104;
//                end
//                91: begin
//                    volts_to_dbm[91] <= 32'h9ec1869b;
//                    dbm[91] <= 16'd15129;
//                end
//                92: begin
//                    volts_to_dbm[92] <= 32'ha2743045;
//                    dbm[92] <= 16'd15155;
//                end
//                93: begin
//                    volts_to_dbm[93] <= 32'ha63ce6e3;
//                    dbm[93] <= 16'd15180;
//                end
//                94: begin
//                    volts_to_dbm[94] <= 32'haa1c2df3;
//                    dbm[94] <= 16'd15206;
//                end
//                95: begin
//                    volts_to_dbm[95] <= 32'hae128c02;
//                    dbm[95] <= 16'd15232;
//                end
//                96: begin
//                    volts_to_dbm[96] <= 32'hb2208abe;
//                    dbm[96] <= 16'd15257;
//                end
//                97: begin
//                    volts_to_dbm[97] <= 32'hb646b70c;
//                    dbm[97] <= 16'd15283;
//                end
//                98: begin
//                    volts_to_dbm[98] <= 32'hba85a119;
//                    dbm[98] <= 16'd15308;
//                end
//                99: begin
//                    volts_to_dbm[99] <= 32'hbedddc6d;
//                    dbm[99] <= 16'd15334;
//                end
//                100: begin            // 60.0dBm in Q15.16 volts across 50 ohm load
//                    volts_to_dbm[100] <= 32'hc3500000;
//                    dbm[100] <= 16'd15360;
//                end
//                101: begin
//                    volts_to_dbm[101] <= 32'hc7dca64d;
//                    dbm[101] <= 16'd15385;
//                end
//                102: begin
//                    volts_to_dbm[102] <= 32'hcc846d6a;
//                    dbm[102] <= 16'd15411;
//                end
//                103: begin
//                    volts_to_dbm[103] <= 32'hd147f71b;
//                    dbm[103] <= 16'd15436;
//                end
//                104: begin
//                    volts_to_dbm[104] <= 32'hd627e8e9;
//                    dbm[104] <= 16'd15462;
//                end
//                105: begin
//                    volts_to_dbm[105] <= 32'hdb24ec37;
//                    dbm[105] <= 16'd15488;
//                end
//                106: begin
//                    volts_to_dbm[106] <= 32'he03fae5a;
//                    dbm[106] <= 16'd15513;
//                end
//                107: begin
//                    volts_to_dbm[107] <= 32'he578e0b4;
//                    dbm[107] <= 16'd15539;
//                end
//                108: begin
//                    volts_to_dbm[108] <= 32'head138c3;
//                    dbm[108] <= 16'd15564;
//                end
//                109: begin
//                    volts_to_dbm[109] <= 32'hf0497044;
//                    dbm[109] <= 16'd15590;
//                end
////                110: begin            // 61.0dBm in Q15.16 volts across 50 ohm load
////                    volts_to_dbm[110] <= 32'hf5e24545;
////                    dbm[110] <= 16'd15616;
////                end
//                CAL_TBL_MAX: begin      // 61.0
//                    volts_to_dbm[110] <= 32'hfb9c7a42;
//                    dbm[110] <= 16'd15616;
//                    cal_state <= CAL_IDLE;                
//                end
////                CAL_TBL_MAX: begin  // 61.1
////                    volts_to_dbm[111] <= 32'h00fdcbcf;
////                    cal_state <= CAL_IDLE;                
////                end
//                endcase
//                ptbl_idx <= ptbl_idx + 7'b000_0001;
                cal_state <= CAL_IDLE;                
            end
            CAL1: begin
                cal_tmp1 <= {16'h0000, adcf_dat_i[31:16]};      // FWDI
                // this works great but adds 50 mins to synthesis! Use extra clock tick (CAL2)
                //cal_tmp1[31:16] <= adcf_dat_i[31] ? 16'hffff : 16'h0000;    // sign extend
                cal_mult1 <= zm_fi_gain_i;
                
                cal_tmp2 <= {16'h0000, adcf_dat_i[15:0]};       // FWDQ
                //cal_tmp2[31:16] <= adcf_dat_i[15] ? 16'hffff : 16'h0000;    // sign extend
                cal_mult2 <= zm_fq_gain_i;
                
                cal_tmp3 <= {16'h0000, adcr_dat_i[31:16]};      // REFLI
                //cal_tmp3[31:16] <= adcr_dat_i[31] ? 16'hffff : 16'h0000;    // sign extend
                cal_mult3 <= zm_ri_gain_i;
                
                cal_tmp4 <= {16'h0000, adcr_dat_i[15:0]};      // REFLQ
                //cal_tmp4[31:16] <= adcr_dat_i[15] ? 16'hffff : 16'h0000;    // sign extend
                cal_mult4 <= zm_rq_gain_i;
                cal_state <= CAL2;
            end
            CAL2: begin
                // cal_tmpN => [14 bits ADC][00]
                // sign extend bipolar values for 32-bit multiplier input            
                if(cal_tmp1[15])             
                    cal_tmp1[31:16] <= 16'hffff;
                if(cal_tmp2[15])             
                    cal_tmp2[31:16] <= 16'hffff;
                if(cal_tmp3[15])             
                    cal_tmp3[31:16] <= 16'hffff;
                if(cal_tmp4[15])             
                    cal_tmp4[31:16] <= 16'hffff;
                cal_state <= CAL3;
            end
            CAL3: begin
                // d0=calibrated, d1=ADC, d2=volts, d3=dBm
                // calibrated ADC value is meaningless, ignore d0
                // output is either ADC, Volts, or dBm
                if(ops_i[1])
                    cal_state <= CAL5;      // just copy signed int's to output
                else begin
                    cal_tmp1 <= cal_tmp1 + zm_fi_offset;
                    cal_tmp2 <= cal_tmp2 + zm_fq_offset;            
                    cal_tmp3 <= cal_tmp3 + zm_ri_offset;            
                    cal_tmp4 <= cal_tmp4 + zm_rq_offset;            
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
                // result is Q15.16 volts across 50 ohm load
                // if returning volts, we're done.
                // output is volts across 50 ohm load (gain*(offset+raw adc))<<16
                // done raw or voltage cal, continue for power
                if(ops_i[1]) begin
                    adcf_dat <= {cal_tmp2[15:0], cal_tmp1[15:0]};   // [FWDQ, FWDI]
                    adcr_dat <= {cal_tmp4[15:0], cal_tmp3[15:0]};   // [REFLQ, REFLI]
                    done_o <= 1'b1;
                    cal_state <= CAL_IDLE;
                end
                else if(ops_i[2]) begin
                    // volts across 50 ohm load
                    adcf_dat[31:0]     <= adc1_cald[31:0];  // Q15.16 VfwdI 
                    adcfq_volts[31:0]  <= adc2_cald[31:0];  // Q15.16 VfwdQ
                    adcr_dat[31:0]     <= adc3_cald[31:0];  // Q15.16 VrefI
                    adcrq_volts[31:0]  <= adc4_cald[31:0];  // Q15.16 VrefQ          
                    done_o <= 1'b1;
                    cal_state <= CAL_IDLE;
                end
//                else if(ops_i[3]) begin
//                    // Pfwd = (VqFwd^2 + ViFwd^2)/50
//                    // (VqFwd*2^16) * (VqFwd*2^16) == VqFwd squared * 2**32)
//                    // Add the I & Q squared results, then extract middle 32 bits
//                    // as the unsigned Q16.16 value to lookup in the table for dBm
//                    cal_tmp1 <= adc1_cald[31:0];
//                    cal_mult1 <= adc1_cald[31:0];
//                    cal_tmp2 <= adc2_cald[31:0];
//                    cal_mult2 <= adc2_cald[31:0];
//                    // Prfl = (VqRfl^2 + ViRfl^2)/50
//                    cal_tmp3 <= adc3_cald[31:0];
//                    cal_mult3 <= adc3_cald[31:0];
//                    cal_tmp4 <= adc4_cald[31:0];
//                    cal_mult4 <= adc4_cald[31:0];
//                    // square all 4 voltages
//                    latency_counter <= MULTIPLIER_CLOCKS;
//                    multiply <= 1'b1;
//                    next_state <= CAL6;
//                    cal_state <= CAL_MULT;
//                end
                else begin// ? error of some sort
                    done_o <= 1'b1;                
                    cal_state <= CAL_IDLE;
                end
            end
//            CAL6: begin
//                sumvsquared_f <= 64'd213584428662784;  //  (223*65536)^2 for SIM test   adc1_cald + adc2_cald;        // fwd sum of squared voltages (*2^32)
//                sumvsquared_r <= 64'd180490492355625;  //  (205*65536)^2 for REFL SIM test  adc3_cald + adc4_cald;        // rfl sum of squared voltages (*2^32)   
//                dbm_index <= 8'h00;                            // start at bottom of dbm table
//                dbm_f_done <= 1'b0;
//                //dbm_fwd <= dbm[0];
//                dbm_fwd_idx <= 8'h00;
//                dbm_r_done <= 1'b0;
//                //dbm_rfl <= dbm[0];
//                dbm_rfl_idx <= 8'h00;
//                cal_state <= CAL7;
//            end
//            CAL7: begin
//                if(dbm_f_done && dbm_r_done) begin
//                    cal_state <= CAL8;
//                end
//                else if(dbm_index == CAL_TBL_MAX) begin
//                    // indicate error?
//                    cal_state <= CAL8;
//                end
//                else begin
//                    if(sumvsquared_f[47:16] <= volts_to_dbm[dbm_index]) begin
//                        dbm_fwd_idx <= dbm_index;
//                        dbm_f_done <= 1'b1;
//                    end
//                    if(sumvsquared_r[47:16] <= volts_to_dbm[dbm_index]) begin
//                        dbm_rfl_idx <= dbm_index;
//                        dbm_r_done <= 1'b1;
//                    end    
//                    dbm_index <= dbm_index + 8'h01;
//                end 
//            end
//            CAL8: begin
//                dbm_index <= dbm_index - 8'h01;
//                cal_state <= CAL9;
//            end
//            CAL9: begin
//                // dbm_fwd & dbm_rfl are set to something, write response
//                adcf_dat <= dbm[dbm_fwd_idx];   // Forward power in Q7.8 format dBm
//                adcr_dat <= dbm[dbm_rfl_idx];   // Reflected power in Q7.8 format dBm
//                done_o <= 1'b1;
//                cal_state <= CAL_IDLE;
//            end
            CAL_MULT: begin           
                if(latency_counter == 0) begin
                    cal_state <= next_state;
                    multiply <= 1'b0;
                end
                else
                    latency_counter <= latency_counter - 1;
            end    
            endcase
        end
    end

endmodule
