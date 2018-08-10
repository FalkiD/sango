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

    input  wire [31:0]  adcf_dat_i,         // Raw MEAS ADC fifo data, [FWDQ][00][FWDI][00]
    input  wire [31:0]  adcr_dat_i,         // Raw MEAS ADC fifo data, [RFLQ][00][RFLI][00]

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
    reg  [6:0]      ptbl_idx;               // power table index
    localparam  CAL_TBL_MAX = 7'd110;

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
    localparam CAL_DBM  = 4'd10;
    localparam CAL_INIT = 4'd11;
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

    //
    // Do calibration of raw adc values
    // AdcLsbs = gain * (offset(Lsbs) + AdcRaw)
    // Gain is Q15.16 floating point
    // Offset is 16-bit signed int
    //
    always @(posedge sys_clk) begin    
        if(!sys_rst_n) begin
            cal_state <= CAL_INIT;
            done_o <= 1'b0;
            runr <= 1'b0;
            ptbl_idx <= 7'b000_0000;
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
//            dBm, watts, volts RMS, vrms<<16(hex)
//            50.0,  100.0,  70.71, 0x0046b5ef
//            50.1,  102.3,  71.53, 0x0047878b
//            50.2,  104.7,  72.36, 0x00485b94
//            50.3,  107.2,  73.20, 0x00493213
//            50.4,  109.6,  74.04, 0x004a0b0d
//            50.5,  112.2,  74.90, 0x004ae68a
//            50.6,  114.8,  75.77, 0x004bc492
//            50.7,  117.5,  76.65, 0x004ca52c
//            50.8,  120.2,  77.53, 0x004d8860
//            50.9,  123.0,  78.43, 0x004e6e35
//            51.0,  125.9,  79.34, 0x004f56b4
//            51.1,  128.8,  80.26, 0x005041e3
//            51.2,  131.8,  81.19, 0x00512fcc
//            51.3,  134.9,  82.13, 0x00522077
//            51.4,  138.0,  83.08, 0x005313ea
//            51.5,  141.3,  84.04, 0x00540a30
//            51.6,  144.5,  85.01, 0x0055034f
//            51.7,  147.9,  86.00, 0x0055ff51
//            51.8,  151.4,  86.99, 0x0056fe3e
//            51.9,  154.9,  88.00, 0x0058001e
//            52.0,  158.5,  89.02, 0x005904fb
//            52.1,  162.2,  90.05, 0x005a0cde
//            52.2,  166.0,  91.09, 0x005b17ce
//            52.3,  169.8,  92.15, 0x005c25d6
//            52.4,  173.8,  93.21, 0x005d36fe
//            52.5,  177.8,  94.29, 0x005e4b51
//            52.6,  182.0,  95.39, 0x005f62d6
//            52.7,  186.2,  96.49, 0x00607d97
//            52.8,  190.5,  97.61, 0x00619b9f
//            52.9,  195.0,  98.74, 0x0062bcf7
//            53.0,  199.5,  99.88, 0x0063e1a9
//            53.1,  204.2, 101.04, 0x006509be
//            53.2,  208.9, 102.21, 0x00663541
//            53.3,  213.8, 103.39, 0x0067643b
//            53.4,  218.8, 104.59, 0x006896b8
//            53.5,  223.9, 105.80, 0x0069ccc2
//            53.6,  229.1, 107.02, 0x006b0662
//            53.7,  234.4, 108.26, 0x006c43a4
//            53.8,  239.9, 109.52, 0x006d8493
//            53.9,  245.5, 110.79, 0x006ec939
//            54.0,  251.2, 112.07, 0x007011a1
//            54.1,  257.0, 113.37, 0x00715dd7
//            54.2,  263.0, 114.68, 0x0072ade6
//            54.3,  269.2, 116.01, 0x007401d8
//            54.4,  275.4, 117.35, 0x007559bb
//            54.5,  281.8, 118.71, 0x0076b599
//            54.6,  288.4, 120.08, 0x0078157e
//            54.7,  295.1, 121.47, 0x00797976
//            54.8,  302.0, 122.88, 0x007ae18e
//            54.9,  309.0, 124.30, 0x007c4dd1
//            55.0,  316.2, 125.74, 0x007dbe4b
//            55.1,  323.6, 127.20, 0x007f330a
//            55.2,  331.1, 128.67, 0x0080ac1a
//            55.3,  338.8, 130.16, 0x00822988
//            55.4,  346.7, 131.67, 0x0083ab60
//            55.5,  354.8, 133.19, 0x008531b0
//            55.6,  363.1, 134.74, 0x0086bc85
//            55.7,  371.5, 136.30, 0x00884bed
//            55.8,  380.2, 137.87, 0x0089dff5
//            55.9,  389.0, 139.47, 0x008b78aa
//            56.0,  398.1, 141.09, 0x008d161b
//            56.1,  407.4, 142.72, 0x008eb855
//            56.2,  416.9, 144.37, 0x00905f67
//            56.3,  426.6, 146.04, 0x00920b5f
//            56.4,  436.5, 147.74, 0x0093bc4c
//            56.5,  446.7, 149.45, 0x0095723c
//            56.6,  457.1, 151.18, 0x00972d3f
//            56.7,  467.7, 152.93, 0x0098ed63
//            56.8,  478.6, 154.70, 0x009ab2b7
//            56.9,  489.8, 156.49, 0x009c7d4b
//            57.0,  501.2, 158.30, 0x009e4d2e
//            57.1,  512.9, 160.13, 0x00a02270
//            57.2,  524.8, 161.99, 0x00a1fd22
//            57.3,  537.0, 163.86, 0x00a3dd52
//            57.4,  549.5, 165.76, 0x00a5c313
//            57.5,  562.3, 167.68, 0x00a7ae73
//            57.6,  575.4, 169.62, 0x00a99f83
//            57.7,  588.8, 171.59, 0x00ab9655
//            57.8,  602.6, 173.57, 0x00ad92fa
//            57.9,  616.6, 175.58, 0x00af9582
//            58.0,  631.0, 177.62, 0x00b19e00
//            58.1,  645.7, 179.67, 0x00b3ac84
//            58.2,  660.7, 181.75, 0x00b5c122
//            58.3,  676.1, 183.86, 0x00b7dbea
//            58.4,  691.8, 185.99, 0x00b9fcef
//            58.5,  707.9, 188.14, 0x00bc2444
//            58.6,  724.4, 190.32, 0x00be51fb
//            58.7,  741.3, 192.52, 0x00c08628
//            58.8,  758.6, 194.75, 0x00c2c0dd
//            58.9,  776.2, 197.01, 0x00c5022e
//            59.0,  794.3, 199.29, 0x00c74a2e
//            59.1,  812.8, 201.60, 0x00c998f1
//            59.2,  831.8, 203.93, 0x00cbee8b
//            59.3,  851.1, 206.29, 0x00ce4b11
//            59.4,  871.0, 208.68, 0x00d0ae97
//            59.5,  891.3, 211.10, 0x00d31932
//            59.6,  912.0, 213.54, 0x00d58af7
//            59.7,  933.3, 216.02, 0x00d803fa
//            59.8,  955.0, 218.52, 0x00da8452
//            59.9,  977.2, 221.05, 0x00dd0c14
//            60.0, 1000.0, 223.61, 0x00df9b57
//            60.1, 1023.3, 226.20, 0x00e2322f
//            60.2, 1047.1, 228.82, 0x00e4d0b5
//            60.3, 1071.5, 231.46, 0x00e776fe
//            60.4, 1096.5, 234.15, 0x00ea2522
//            60.5, 1122.0, 236.86, 0x00ecdb38
//            60.6, 1148.2, 239.60, 0x00ef9958
//            60.7, 1174.9, 242.37, 0x00f25f98
//            60.8, 1202.3, 245.18, 0x00f52e13
//            60.9, 1230.3, 248.02, 0x00f804df
//            61.0, 1258.9, 250.89, 0x00fae415
//            61.1, 1288.2, 253.80, 0x00fdcbcf
                case(ptbl_idx)
                0: begin    // 50.0dBm in Q15.16 volts across 50 ohm load
                    volts_to_dbm[0] <= 32'h0046b5ef; // 70.7 v << 16
                end
                1: begin
                    volts_to_dbm[1] <= 32'h0047878b;
                end
                2: begin
                    volts_to_dbm[2] <= 32'h00485b94;
                end
                3: begin
                    volts_to_dbm[3] <= 32'h00493213;
                end
                4: begin
                    volts_to_dbm[4] <= 32'h004a0b0d;
                end
                5: begin
                    volts_to_dbm[5] <= 32'h004ae68a;
                end
                6: begin
                    volts_to_dbm[6] <= 32'h004bc492;
                end
                7: begin
                    volts_to_dbm[7] <= 32'h004ca52c;
                end
                8: begin
                    volts_to_dbm[8] <= 32'h004d8860;
                end
                9: begin
                    volts_to_dbm[9] <= 32'h004e6e35;
                end
                10: begin   // 51.0
                    volts_to_dbm[10] <= 32'h004f56b4;
                end
                11: begin
                    volts_to_dbm[11] <= 32'h005041e3;
                end
                12: begin
                    volts_to_dbm[12] <= 32'h00512fcc;
                end
                13: begin
                    volts_to_dbm[13] <= 32'h00522077;
                end
                14: begin
                    volts_to_dbm[14] <= 32'h005313ea;
                end
                15: begin
                    volts_to_dbm[15] <= 32'h00540a30;
                end
                16: begin
                    volts_to_dbm[16] <= 32'h0055034f;
                end
                17: begin
                    volts_to_dbm[17] <= 32'h0055ff51;
                end
                18: begin
                    volts_to_dbm[18] <= 32'h0056fe3e;
                end
                19: begin
                    volts_to_dbm[19] <= 32'h0058001e;
                end
                20: begin   // 52.0
                    volts_to_dbm[20] <= 32'h005904fb;
                end
                21: begin
                    volts_to_dbm[21] <= 32'h005a0cde;
                end
                22: begin
                    volts_to_dbm[22] <= 32'h005b17ce;
                end
                23: begin
                    volts_to_dbm[23] <= 32'h005c25d6;
                end
                24: begin
                    volts_to_dbm[24] <= 32'h005d36fe;
                end
                25: begin
                    volts_to_dbm[25] <= 32'h005e4b51;
                end
                26: begin
                    volts_to_dbm[26] <= 32'h005f62d6;
                end
                27: begin
                    volts_to_dbm[27] <= 32'h00607d97;
                end
                28: begin
                    volts_to_dbm[28] <= 32'h00619b9f;
                end
                29: begin
                    volts_to_dbm[29] <= 32'h0062bcf7;
                end
                30: begin   // 53.0
                    volts_to_dbm[30] <= 32'h0063e1a9;
                end
                31: begin
                    volts_to_dbm[31] <= 32'h006509be;
                end
                32: begin
                    volts_to_dbm[32] <= 32'h00663541;
                end
                33: begin
                    volts_to_dbm[33] <= 32'h0067643b;
                end
                34: begin
                    volts_to_dbm[34] <= 32'h006896b8;
                end
                35: begin
                    volts_to_dbm[35] <= 32'h0069ccc2;
                end
                36: begin
                    volts_to_dbm[36] <= 32'h006b0662;
                end
                37: begin
                    volts_to_dbm[37] <= 32'h006c43a4;
                end
                38: begin
                    volts_to_dbm[38] <= 32'h006d8493;
                end
                39: begin
                    volts_to_dbm[39] <= 32'h006ec939;
                end
                40: begin   // 54.0
                    volts_to_dbm[40] <= 32'h007011a1;
                end
                41: begin
                    volts_to_dbm[41] <= 32'h00715dd7;
                end
                42: begin
                    volts_to_dbm[42] <= 32'h0072ade6;
                end
                43: begin
                    volts_to_dbm[43] <= 32'h007401d8;
                end
                44: begin
                    volts_to_dbm[44] <= 32'h007559bb;
                end
                45: begin
                    volts_to_dbm[45] <= 32'h0076b599;
                end
                46: begin
                    volts_to_dbm[46] <= 32'h0078157e;
                end
                47: begin
                    volts_to_dbm[47] <= 32'h00797976;
                end
                48: begin
                    volts_to_dbm[48] <= 32'h007ae18e;
                end
                49: begin
                    volts_to_dbm[49] <= 32'h007c4dd1;
                end
                50: begin   // 55.0
                    volts_to_dbm[50] <= 32'h007dbe4b;
                end
                51: begin
                    volts_to_dbm[51] <= 32'h007f330a;
                end
                52: begin
                    volts_to_dbm[52] <= 32'h0080ac1a;
                end
                53: begin
                    volts_to_dbm[53] <= 32'h00822988;
                end
                54: begin
                    volts_to_dbm[54] <= 32'h0083ab60;
                end
                55: begin
                    volts_to_dbm[55] <= 32'h008531b0;
                end
                56: begin
                    volts_to_dbm[56] <= 32'h0086bc85;
                end
                57: begin
                    volts_to_dbm[57] <= 32'h00884bed;
                end
                58: begin
                    volts_to_dbm[58] <= 32'h0089dff5;
                end
                59: begin
                    volts_to_dbm[59] <= 32'h008b78aa;
                end
                60: begin   // 56.0
                    volts_to_dbm[60] <= 32'h008d161b;
                end
                61: begin
                    volts_to_dbm[61] <= 32'h008eb855;
                end
                62: begin
                    volts_to_dbm[62] <= 32'h00905f67;
                end
                63: begin
                    volts_to_dbm[63] <= 32'h00920b5f;
                end
                64: begin
                    volts_to_dbm[64] <= 32'h0093bc4c;
                end
                65: begin
                    volts_to_dbm[65] <= 32'h0095723c;
                end
                66: begin
                    volts_to_dbm[66] <= 32'h00972d3f;
                end
                67: begin
                    volts_to_dbm[67] <= 32'h0098ed63;
                end
                68: begin
                    volts_to_dbm[68] <= 32'h009ab2b7;
                end
                69: begin
                    volts_to_dbm[69] <= 32'h009c7d4b;
                end
                70: begin   // 57.0
                    volts_to_dbm[70] <= 32'h009e4d2e;
                end
                71: begin
                    volts_to_dbm[71] <= 32'h00a02270;
                end
                72: begin
                    volts_to_dbm[72] <= 32'h00a1fd22;
                end
                73: begin
                    volts_to_dbm[73] <= 32'h00a3dd52;
                end
                74: begin
                    volts_to_dbm[74] <= 32'h00a5c313;
                end
                75: begin
                    volts_to_dbm[75] <= 32'h00a7ae73;
                end
                76: begin
                    volts_to_dbm[76] <= 32'h00a99f83;
                end
                77: begin
                    volts_to_dbm[77] <= 32'h00ab9655;
                end
                78: begin
                    volts_to_dbm[78] <= 32'h00ad92fa;
                end
                79: begin
                    volts_to_dbm[79] <= 32'h00af9582;
                end
                80: begin   // 58.0
                    volts_to_dbm[80] <= 32'h00b19e00;
                end
                81: begin
                    volts_to_dbm[81] <= 32'h00b3ac84;
                end
                82: begin
                    volts_to_dbm[82] <= 32'h00b5c122;
                end
                83: begin
                    volts_to_dbm[83] <= 32'h00b7dbea;
                end
                84: begin
                    volts_to_dbm[84] <= 32'h00b9fcef;
                end
                85: begin
                    volts_to_dbm[85] <= 32'h00bc2444;
                end
                86: begin
                    volts_to_dbm[86] <= 32'h00be51fb;
                end
                87: begin
                    volts_to_dbm[87] <= 32'h00c08628;
                end
                88: begin
                    volts_to_dbm[88] <= 32'h00c2c0dd;
                end
                89: begin
                    volts_to_dbm[89] <= 32'h00c5022e;
                end
                90: begin   // 59.0
                    volts_to_dbm[90] <= 32'h00c74a2e;
                end
                91: begin
                    volts_to_dbm[91] <= 32'h00c998f1;
                end
                92: begin
                    volts_to_dbm[92] <= 32'h00cbee8b;
                end
                93: begin
                    volts_to_dbm[93] <= 32'h00ce4b11;
                end
                94: begin
                    volts_to_dbm[94] <= 32'h00d0ae97;
                end
                95: begin
                    volts_to_dbm[95] <= 32'h00d31932;
                end
                96: begin
                    volts_to_dbm[96] <= 32'h00d58af7;
                end
                97: begin
                    volts_to_dbm[97] <= 32'h00d803fa;
                end
                98: begin
                    volts_to_dbm[98] <= 32'h00da8452;
                end
                99: begin
                    volts_to_dbm[99] <= 32'h00dd0c14;
                end
                100: begin  // 60.0
                    volts_to_dbm[100] <= 32'h00df9b57;
                end
                101: begin
                    volts_to_dbm[101] <= 32'h00e2322f;
                end
                102: begin
                    volts_to_dbm[102] <= 32'h00e4d0b5;
                end
                103: begin
                    volts_to_dbm[103] <= 32'h00e776fe;
                end
                104: begin
                    volts_to_dbm[104] <= 32'h00ea2522;
                end
                105: begin
                    volts_to_dbm[105] <= 32'h00ecdb38;
                end
                106: begin
                    volts_to_dbm[106] <= 32'h00ef9958;
                end
                107: begin
                    volts_to_dbm[107] <= 32'h00f25f98;
                end
                108: begin
                    volts_to_dbm[108] <= 32'h00f52e13;
                end
                109: begin
                    volts_to_dbm[109] <= 32'h00f804df;
                end
                CAL_TBL_MAX: begin      // 61.0
                    volts_to_dbm[110] <= 32'h00fae415;
                    cal_state <= CAL_IDLE;                
                end
//                CAL_TBL_MAX: begin  // 61.1
//                    volts_to_dbm[111] <= 32'h00fdcbcf;
//                    cal_state <= CAL_IDLE;                
//                end
                endcase
                ptbl_idx <= ptbl_idx + 7'b000_0001;
            end
            CAL1: begin
                cal_tmp1 <= {16'd0, adcf_dat_i[15:0]};      // FWDI
                cal_mult1 <= zm_fi_gain_i;
                cal_tmp2 <= {16'd0, adcf_dat_i[31:16]};     // FWDQ
                cal_mult2 <= zm_fq_gain_i;
                cal_tmp3 <= {16'd0, adcr_dat_i[15:0]};      // REFLI
                cal_mult3 <= zm_ri_gain_i;
                cal_tmp4 <= {16'd0, adcr_dat_i[31:16]};     // REFLQ
                cal_mult4 <= zm_rq_gain_i;
                cal_state <= CAL2;
            end
            CAL2: begin
// 31-Jul-2018 update, ADC values already shifted left 2, don't need this
//                // cal_tmp => [XX][14 bits ADC]
//                // sign extend bipolar values            
//                if(cal_tmp1[13])             
//                    cal_tmp1[31:14] <= 18'b1111_1111_1111_1111_11; //{18'b1111_1111_1111_1111_11, cal_tmp1[13:0]};
//                if(cal_tmp2[13])             
//                    cal_tmp2[31:14] <= 18'b1111_1111_1111_1111_11; //{18'b1111_1111_1111_1111_11, cal_tmp2[13:0]};
//                if(cal_tmp3[13])             
//                    cal_tmp3[31:14] <= 18'b1111_1111_1111_1111_11; //{18'b1111_1111_1111_1111_11, cal_tmp3[13:0]};
//                if(cal_tmp4[13])             
//                    cal_tmp4[31:14] <= 18'b1111_1111_1111_1111_11; //{18'b1111_1111_1111_1111_11, cal_tmp4[13:0]};
//                cal_state <= CAL3;
//            end
//            CAL3: begin
                // d0=calibrated, d1=ADC, d2=volts, d3=dBm
                // calibrated ADC value is meaningless, ignore d0
                // output is either ADC, Volts, or dBm
                if(ops_i[1])
                    cal_state <= CAL_DONE;      // just copy signed int's to output
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
                if(ops_i[3]) begin
                    cal_state <= CAL_DBM;
                end
                else begin
                    // returning volts, or some error condition
                    cal_state <= CAL_DONE;
                end
            end
            CAL_DONE: begin
                // done cal, format output as needed
                if(ops_i[1]) begin
                    adcf_dat <= {cal_tmp2[15:0], cal_tmp1[15:0]};   // [FWDQ,FWDI]
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
                else if(ops_i[3]) begin
                    // Pfwd = (VqFwd^2 + ViFwd^2)/50
                    // Prfl = (VqRfl^2 + ViRfl^2)/50
                    






                    done_o <= 1'b1;
                    cal_state <= CAL_IDLE;
    
                end
                else begin// ? error of some sort
                    done_o <= 1'b1;                
                    cal_state <= CAL_IDLE;
                end
            end
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
