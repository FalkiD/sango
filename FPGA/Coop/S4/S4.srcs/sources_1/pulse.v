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
// Description: pulse will parse the pulse opcode and run it once.
//      Pulse opcode has width of pulse in 100ns ticks and
//      optionally a measurement flag and measurement offset.
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

module pulse #(parameter FILL_BITS = 4)
(
    input  wire         sys_clk,
    input  wire         sys_rst_n,
    
    input  wire         pulse_en,

    // Pulse opcode(s) are in input fifo
    input  wire [63:0]  pls_fifo_dat_i,     // pulse fifo
    output reg          pls_fifo_ren_o,     // fifo read line
    input  wire         pls_fifo_mt_i,      // fifo empty flag
    input  wire [FILL_BITS-1:0]  pls_fifo_count_i,   // fifo count, for debug message only

    input  wire         rf_enable_i,        // RF enabled by MCU, Interlock, etc.
    output wire         rf_gate_o,          // RF_GATE line
    output wire         rf_gate2_o,         // RF_GATE2 line, initial release always ON
    input  wire         dbg_rf_gate_i,      // Debug mode assert RF_GATE lines
    input  wire         zm_normal_i,        // 0 to calibrate ZMon offset, measure with RFGATE OFF during pulse
                                            // 1 is normal operation

    // controlled by opcode output wire         zmon_en_o,          // Enable ZMON
    output wire         conv_o,             // CONV pulse
    output wire         adc_sclk_o,         // ZMON SCK
    input  wire         adcf_sdo_i,         // FWD SDO
    input  wire         adcr_sdo_i,         // REFL SDO

    output reg  [31:0]  adc_fifo_dat_o,     // 32 bits of FWD REFL ADC data written to output fifo
    output reg          adc_fifo_wen_o,     // ADC results fifo write enable
    input  wire         adc_fifo_full_i,    // ADC FIFO full

    output reg  [7:0]   status_o            // Pulse status, 0=Busy, SUCCESS when done, or an error code
    );

    // Main Globals
    reg [6:0]       state = 0;

    /////////////////////////////////////////////////////////
    // user-programmed pulse opcode parsing
    // Pulse is programmed from pattern editor, times and 
    // widths are in 100us ticks.
    /////////////////////////////////////////////////////////
    reg [3:0]       channel;                // 1-16 minus 1
    reg [23:0]      pulse = 24'h00_0000_0000;   // Pulse width from pulse opcode, 100ns ticks, 100ns to 1.67 seconds
    reg             measure;                // flag, 1=measure, 0=no measurement, from pulse opcode 
    reg [23:0]      measure_at;             // measure at this tick, from pulse opcode   
    reg [23:0]      ticks;                  // pulse width tick counter while pulse ON
    reg [7:0]       sys_ticks;              // system (100MHz) ticks
    localparam PULSE_TICKS = 9;             // 10 0-based sys ticks per pulse tick

    reg             rf_gate;
    reg             rf_gate2;
    reg             conv;
    reg             adc_sclk;

    // connect external wires
    assign rf_gate_o = dbg_rf_gate_i ? 1'b1 : rf_gate;
    assign rf_gate2_o = dbg_rf_gate_i ? 1'b1 : rf_gate2;
    //assign zmon_en_o = zmon_en;
    assign adc_sclk_o = adc_sclk;
    assign conv_o = conv;

// debugging
//reg [7:0] mtbl_idx;

    // ZMON ADC variables, processing
    // LTC1407A ADC state machine
    localparam AIdle = 3'd0, ASckOn = 3'd1, ASckOnWait = 3'd2, ASckOff = 3'd3, ADone = 3'd4, ADone2 = 3'd5, SckOnStretch = 3'd2, DbgInit = 3'd6;
    reg [2:0]       astate = AIdle;
    reg [31:0]      adcf_dat = 32'b0;
    reg [31:0]      adcr_dat = 32'b0;
    reg [5:0]       acount = 6'b0;
    reg [2:0]       sck_time = 3'b0;
    // Assumes 100MHz clock, /6 = 16.67MHz for LTC1407A's
    always @(posedge sys_clk)    // 100MHz, 6 clocks per T = 16.667MHz 'SPI'
        if(!sys_rst_n) begin
//`ifdef XILINX_SIMULATOR
//            astate <= DbgInit; //AIdle;            
//            mtbl_idx <= 8'h00;
//`endif            
            astate <= AIdle;
            adc_fifo_wen_o <= 0;
            adc_sclk <= 1'b0;
        end
        else begin
            case (astate)
//`ifdef XILINX_SIMULATOR
//            DbgInit: begin
//// Debug, fill MEAS fifo with real data to debug reads.
//                adc_fifo_wen_o <= 0;
//                if(mtbl_idx < 100)
//                    mtbl_idx <= mtbl_idx + 8'h01;
//                else
//                    astate <= AIdle;
//                case(mtbl_idx)
//                0: begin    // 50.0dBm in Q15.16 volts across 50 ohm load
//                    adc_fifo_dat_o <= {16'd15000, 16'd14900};  // [FWDQ 00] ]FQDI 00]
//                    adc_fifo_wen_o <= 1'b1;                // write ADCF data
//                end
//                1: begin
//                    adc_fifo_dat_o <= {16'd21000, 16'd20000};
//                    adc_fifo_wen_o <= 1'b1;                // write ADCF data
//                end
//                2: begin
//                    adc_fifo_dat_o <= {16'd14400, 16'd14448};
//                    adc_fifo_wen_o <= 1'b1;                // write ADCF data
//                end
//                3: begin
//                    adc_fifo_dat_o <= {16'd14000, 16'd14100};
//                    adc_fifo_wen_o <= 1'b1;                // write ADCF data
//                end
//                4: begin                
//                    adc_fifo_dat_o <= {16'd14250, 16'd14200};
//                    adc_fifo_wen_o <= 1'b1;                // write ADCF data
//                end
//                5: begin
//                    adc_fifo_dat_o <= {16'd15050, 16'd15200};
//                    adc_fifo_wen_o <= 1'b1;                // write ADCF data
//                end
//                6: begin
//                    adc_fifo_dat_o <= {16'd13916, 16'd14200};
//                    adc_fifo_wen_o <= 1'b1;                // write ADCF data
//                end
//                7: begin
//                    adc_fifo_dat_o <= {16'd13999, 16'd14000};
//                    adc_fifo_wen_o <= 1'b1;                // write ADCF data
//                end
//                8: begin
//                    adc_fifo_dat_o <= {16'd13692, 16'd13700};
//                    adc_fifo_wen_o <= 1'b1;                // write ADCF data
//                end
//                9: begin
//                    adc_fifo_dat_o <= {16'd13380, 16'd13750};
//                    adc_fifo_wen_o <= 1'b1;                // write ADCF data
//                end
//                10: begin   // 51.0
//                    adc_fifo_dat_o <= {16'd13200, 16'd13220};
//                    adc_fifo_wen_o <= 1'b1;                // write ADCF data
//                end
//                11: begin
//                    adc_fifo_dat_o <= {16'd13240, 16'd13220};
//                    adc_fifo_wen_o <= 1'b1;                // write ADCF data
//                end
//                12: begin
//                    adc_fifo_dat_o <= {16'd13004, 16'd13104};
//                    adc_fifo_wen_o <= 1'b1;                // write ADCF data
//                end
//                13: begin
//                    adc_fifo_dat_o <= {16'd13014, 16'd13114};
//                    adc_fifo_wen_o <= 1'b1;                // write ADCF data
//                end
//                14: begin
//                    adc_fifo_dat_o <= {16'd13004, 16'd13104};
//                    adc_fifo_wen_o <= 1'b1;                // write ADCF data
//                end
//                15: begin
//                    adc_fifo_dat_o <= {16'd12908, 16'd13004};
//                    adc_fifo_wen_o <= 1'b1;                // write ADCF data
//                end
//                16: begin
//                    adc_fifo_dat_o <= {16'd13008, 16'd13018};
//                    adc_fifo_wen_o <= 1'b1;                // write ADCF data
//                end
//                17: begin
//                    adc_fifo_dat_o <= {16'd12632, 16'd13000};
//                    adc_fifo_wen_o <= 1'b1;                // write ADCF data
//                end
//                18: begin
//                    adc_fifo_dat_o <= {16'd12344, 16'd12340};
//                    adc_fifo_wen_o <= 1'b1;                // write ADCF data
//                end
//                19: begin
//                    adc_fifo_dat_o <= {16'd12333, 16'd12330};
//                    adc_fifo_wen_o <= 1'b1;                // write ADCF data
//                end
//                20: begin   // 52.0
//                    adc_fifo_dat_o <= {16'd12296, 16'd12297};
//                    adc_fifo_wen_o <= 1'b1;                // write ADCF data
//                end
//                21: begin
//                    adc_fifo_dat_o <= {16'd12337, 16'd12290};
//                    adc_fifo_wen_o <= 1'b1;                // write ADCF data
//                end
//                22: begin
//                    adc_fifo_dat_o <= {16'd12168, 16'd12267};
//                    adc_fifo_wen_o <= 1'b1;                // write ADCF data
//                end
//                23: begin
//                    adc_fifo_dat_o <= {16'd12260, 16'd12258};
//                    adc_fifo_wen_o <= 1'b1;                // write ADCF data
//                end
//                24: begin
//                    adc_fifo_dat_o <= {16'd11960, 16'd11980};
//                    adc_fifo_wen_o <= 1'b1;                // write ADCF data
//                end
//                25: begin
//                    adc_fifo_dat_o <= {16'd11950, 16'd11990};
//                    adc_fifo_wen_o <= 1'b1;                // write ADCF data
//                end
//                26: begin
//                    adc_fifo_dat_o <= {16'd11756, 16'd11758};
//                    adc_fifo_wen_o <= 1'b1;                // write ADCF data
//                end
//                27: begin
//                    adc_fifo_dat_o <= {16'd11788, 16'd11800};
//                    adc_fifo_wen_o <= 1'b1;                // write ADCF data
//                end
//                28: begin
//                    adc_fifo_dat_o <= {16'd11596, 16'd11600};
//                    adc_fifo_wen_o <= 1'b1;                // write ADCF data
//                end
//                29: begin
//                    adc_fifo_dat_o <= {16'd11618, 16'd11590};
//                    adc_fifo_wen_o <= 1'b1;                // write ADCF data
//                end
//                30: begin   // 53.0
//                    adc_fifo_dat_o <= {16'd11512, 16'd11510};
//                    adc_fifo_wen_o <= 1'b1;                // write ADCF data
//                end
//                31: begin
//                    adc_fifo_dat_o <= {16'd11498, 16'd11507};
//                    adc_fifo_wen_o <= 1'b1;                // write ADCF data
//                end
//                32: begin
//                    adc_fifo_dat_o <= {16'd11360, 16'd11357};
//                    adc_fifo_wen_o <= 1'b1;                // write ADCF data
//                end
//                33: begin
//                    adc_fifo_dat_o <= {16'd11368, 16'd11366};
//                    adc_fifo_wen_o <= 1'b1;                // write ADCF data
//                end
//                34: begin
//                    adc_fifo_dat_o <= {16'd11292, 16'd11290};
//                    adc_fifo_wen_o <= 1'b1;                // write ADCF data
//                end
//                35: begin
//                    adc_fifo_dat_o <= {16'd11288, 16'd11297};
//                    adc_fifo_wen_o <= 1'b1;                // write ADCF data
//                end
//                36: begin                
//                    adc_fifo_dat_o <= {16'd11056, 16'd11050};
//                    adc_fifo_wen_o <= 1'b1;                // write ADCF data
//                end
//                37: begin
//                    adc_fifo_dat_o <= {16'd11048, 16'd11051};
//                    adc_fifo_wen_o <= 1'b1;                // write ADCF data
//                end
//                38: begin
//                    adc_fifo_dat_o <= {16'd10964, 16'd10960};
//                    adc_fifo_wen_o <= 1'b1;                // write ADCF data
//                end
//                39: begin
//                    adc_fifo_dat_o <= {16'd11000, 16'd10970};
//                    adc_fifo_wen_o <= 1'b1;                // write ADCF data
//                end
//                40: begin   // 54.0
//                    adc_fifo_dat_o <= {16'd10924, 16'd10920};
//                    adc_fifo_wen_o <= 1'b1;                // write ADCF data
//                end
//                41: begin
//                    adc_fifo_dat_o <= {16'd10940, 16'd10930};
//                    adc_fifo_wen_o <= 1'b1;                // write ADCF data
//                end
//                42: begin
//                    adc_fifo_dat_o <= {16'd10816, 16'd10810};
//                    adc_fifo_wen_o <= 1'b1;                // write ADCF data
//                end
//                43: begin
//                    adc_fifo_dat_o <= {16'd10820, 16'd10800};
//                    adc_fifo_wen_o <= 1'b1;                // write ADCF data
//                end
//                44: begin
//                    adc_fifo_dat_o <= {16'd10740, 16'd10730};
//                    adc_fifo_wen_o <= 1'b1;                // write ADCF data
//                end
//                45: begin
//                    adc_fifo_dat_o <= {16'd10737, 16'd10732};
//                    adc_fifo_wen_o <= 1'b1;                // write ADCF data
//                end
//                46: begin
//                    adc_fifo_dat_o <= {16'd10488, 16'd10489};
//                    adc_fifo_wen_o <= 1'b1;                // write ADCF data
//                end
//                47: begin
//                    adc_fifo_dat_o <= {16'd10490, 16'd10477};
//                    adc_fifo_wen_o <= 1'b1;                // write ADCF data
//                end
//                48: begin
//                    adc_fifo_dat_o <= {16'd10452, 16'd10450};
//                    adc_fifo_wen_o <= 1'b1;                // write ADCF data
//                end
//                49: begin
//                    adc_fifo_dat_o <= {16'd10448, 16'd10460};
//                    adc_fifo_wen_o <= 1'b1;                // write ADCF data
//                end
//                50: begin
//                    adc_fifo_dat_o <= {16'd10472, 16'd10470};
//                    adc_fifo_wen_o <= 1'b1;                // write ADCF data
//                end
//                51: begin
//                    adc_fifo_dat_o <= {16'd10478, 16'd10468};
//                    adc_fifo_wen_o <= 1'b1;                // write ADCF data
//                end
//                52: begin
//                    adc_fifo_dat_o <= {16'd10420, 16'd10425};
//                    adc_fifo_wen_o <= 1'b1;                // write ADCF data
//                end
//                53: begin
//                    adc_fifo_dat_o <= {16'd10422, 16'd10421};
//                    adc_fifo_wen_o <= 1'b1;                // write ADCF data
//                end
//                54: begin
//                    adc_fifo_dat_o <= {16'd10332, 16'd10330};
//                    adc_fifo_wen_o <= 1'b1;                // write ADCF data
//                end
//                55: begin
//                    adc_fifo_dat_o <= {16'd10335, 16'd10327};
//                    adc_fifo_wen_o <= 1'b1;                // write ADCF data
//                end
//                56: begin
//                    adc_fifo_dat_o <= {16'd10144, 16'd10140};
//                    adc_fifo_wen_o <= 1'b1;                // write ADCF data
//                end
//                57: begin
//                    adc_fifo_dat_o <= {16'd10146, 16'd10141};
//                    adc_fifo_wen_o <= 1'b1;                // write ADCF data
//                end
//                58: begin
//                    adc_fifo_dat_o <= {16'd10184, 16'd10186};
//                    adc_fifo_wen_o <= 1'b1;                // write ADCF data
//                end
//                59: begin
//                    adc_fifo_dat_o <= {16'd10180, 16'd10179};
//                    adc_fifo_wen_o <= 1'b1;                // write ADCF data
//                end
//                60: begin   // 56.0
//                    adc_fifo_dat_o <= {16'd10152, 16'd10150};
//                    adc_fifo_wen_o <= 1'b1;                // write ADCF data
//                end
//                61: begin
//                    adc_fifo_dat_o <= {16'd10157, 16'd10155};
//                    adc_fifo_wen_o <= 1'b1;                // write ADCF data
//                end
//                62: begin
//                    adc_fifo_dat_o <= {16'd10052, 16'd10055};
//                    adc_fifo_wen_o <= 1'b1;                // write ADCF data
//                end
//                63: begin
//                    adc_fifo_dat_o <= {16'd10050, 16'd10057};
//                    adc_fifo_wen_o <= 1'b1;                // write ADCF data
//                end
//                64: begin
//                    adc_fifo_dat_o <= {16'd9950, 16'd9955};
//                    adc_fifo_wen_o <= 1'b1;                // write ADCF data
//                end
//                65: begin
//                    adc_fifo_dat_o <= {16'd9948, 16'd9978};
//                    adc_fifo_wen_o <= 1'b1;                // write ADCF data
//                end
//                66: begin
//                    adc_fifo_dat_o <= {16'd10104, 16'd10100};
//                    adc_fifo_wen_o <= 1'b1;                // write ADCF data
//                end
//                67: begin
//                    adc_fifo_dat_o <= {16'd10050, 16'd9999};
//                    adc_fifo_wen_o <= 1'b1;                // write ADCF data
//                end
//                68: begin
//                    adc_fifo_dat_o <= {16'd10076, 16'd10080};
//                    adc_fifo_wen_o <= 1'b1;                // write ADCF data
//                end
//                69: begin
//                    adc_fifo_dat_o <= {16'd10070, 16'd10100};
//                    adc_fifo_wen_o <= 1'b1;                // write ADCF data
//                end
//                70: begin   // 57.0
//                    adc_fifo_dat_o <= {16'd10072, 16'd10080};
//                    adc_fifo_wen_o <= 1'b1;                // write ADCF data
//                end
//                71: begin
//                    adc_fifo_dat_o <= {16'd10068, 16'd10091};
//                    adc_fifo_wen_o <= 1'b1;                // write ADCF data
//                end
//                72: begin
//                    adc_fifo_dat_o <= {16'd9956, 16'd9957};
//                    adc_fifo_wen_o <= 1'b1;                // write ADCF data
//                end
//                73: begin
//                    adc_fifo_dat_o <= {16'd9959, 16'd9958};
//                    adc_fifo_wen_o <= 1'b1;                // write ADCF data
//                end
//                74: begin
//                    adc_fifo_dat_o <= {16'd9984, 16'd9980};
//                    adc_fifo_wen_o <= 1'b1;                // write ADCF data
//                end
//                75: begin
//                    adc_fifo_dat_o <= {16'd9979, 16'd9974};
//                    adc_fifo_wen_o <= 1'b1;                // write ADCF data
//                end
//                76: begin
//                    adc_fifo_dat_o <= {16'd9979, 16'd9974};
//                    adc_fifo_wen_o <= 1'b1;                // write ADCF data
//                end
//                77: begin
//                    adc_fifo_dat_o <= {16'd9979, 16'd9974};
//                    adc_fifo_wen_o <= 1'b1;                // write ADCF data
//                end
//                78: begin
//                    adc_fifo_dat_o <= {16'd9979, 16'd9974};
//                    adc_fifo_wen_o <= 1'b1;                // write ADCF data
//                end
//                79: begin
//                    adc_fifo_dat_o <= {16'd9979, 16'd9974};
//                    adc_fifo_wen_o <= 1'b1;                // write ADCF data
//                end
//                80: begin   // 58.0
//                    adc_fifo_dat_o <= {16'd9979, 16'd9974};
//                    adc_fifo_wen_o <= 1'b1;                // write ADCF data
//                end
//                81: begin
//                    adc_fifo_dat_o <= {16'd9979, 16'd9974};
//                    adc_fifo_wen_o <= 1'b1;                // write ADCF data
//                end
//                82: begin
//                    adc_fifo_dat_o <= {16'd9979, 16'd9974};
//                    adc_fifo_wen_o <= 1'b1;                // write ADCF data
//                end
//                83: begin
//                    adc_fifo_dat_o <= {16'd9979, 16'd9974};
//                    adc_fifo_wen_o <= 1'b1;                // write ADCF data
//                end
//                84: begin
//                    adc_fifo_dat_o <= {16'd9979, 16'd9974};
//                    adc_fifo_wen_o <= 1'b1;                // write ADCF data
//                end
//                85: begin
//                    adc_fifo_dat_o <= {16'd9979, 16'd9974};
//                    adc_fifo_wen_o <= 1'b1;                // write ADCF data
//                end
//                86: begin
//                    adc_fifo_dat_o <= {16'd9979, 16'd9974};
//                    adc_fifo_wen_o <= 1'b1;                // write ADCF data
//                end
//                87: begin
//                    adc_fifo_dat_o <= {16'd9979, 16'd9974};
//                    adc_fifo_wen_o <= 1'b1;                // write ADCF data
//                end
//                88: begin
//                    adc_fifo_dat_o <= {16'd9979, 16'd9974};
//                    adc_fifo_wen_o <= 1'b1;                // write ADCF data
//                end
//                89: begin
//                    adc_fifo_dat_o <= {16'd9979, 16'd9974};
//                    adc_fifo_wen_o <= 1'b1;                // write ADCF data
//                end
//                90: begin   // 59.0
//                    adc_fifo_dat_o <= {16'd9979, 16'd9974};
//                    adc_fifo_wen_o <= 1'b1;                // write ADCF data
//                end
//                91: begin
//                    adc_fifo_dat_o <= {16'd9979, 16'd9974};
//                    adc_fifo_wen_o <= 1'b1;                // write ADCF data
//                end
//                92: begin
//                    adc_fifo_dat_o <= {16'd9979, 16'd9974};
//                    adc_fifo_wen_o <= 1'b1;                // write ADCF data
//                end
//                93: begin
//                    adc_fifo_dat_o <= {16'd9979, 16'd9974};
//                    adc_fifo_wen_o <= 1'b1;                // write ADCF data
//                end
//                94: begin
//                    adc_fifo_dat_o <= {16'd9979, 16'd9974};
//                    adc_fifo_wen_o <= 1'b1;                // write ADCF data
//                end
//                95: begin
//                    adc_fifo_dat_o <= {16'd9979, 16'd9974};
//                    adc_fifo_wen_o <= 1'b1;                // write ADCF data
//                end
//                96: begin
//                    adc_fifo_dat_o <= {16'd9979, 16'd9974};
//                    adc_fifo_wen_o <= 1'b1;                // write ADCF data
//                end
//                97: begin
//                    adc_fifo_dat_o <= {16'd9979, 16'd9974};
//                    adc_fifo_wen_o <= 1'b1;                // write ADCF data
//                end
//                98: begin
//                    adc_fifo_dat_o <= {16'd9979, 16'd9974};
//                    adc_fifo_wen_o <= 1'b1;                // write ADCF data
//                end
//                99: begin
//                    adc_fifo_dat_o <= {16'd9979, 16'd9974};
//                    adc_fifo_wen_o <= 1'b1;                // write ADCF data
//                end
//                endcase            
//            end
//`endif            
            AIdle: begin
                adc_fifo_wen_o <= 0;
                if (conv) begin
                    acount <= 6'd34;
                    astate <= ASckOn;
                end
            end
            ASckOn: begin
                adc_sclk <= 1;
                acount <= acount - 1;
                sck_time <= SckOnStretch;
                astate <= ASckOnWait;
            end
            ASckOnWait: begin
                if (sck_time == 0)
                    astate <= ASckOff;
                else
                    sck_time <= sck_time - 1;
                end
            ASckOff: begin
                adc_sclk <= 0;
                adcf_dat <= {adcf_dat[30:0], adcf_sdo_i};
                adcr_dat <= {adcr_dat[30:0], adcr_sdo_i};
                if (acount == 0)
                    astate <= ADone;
                else
                    astate <= ASckOn;
                end
            ADone: begin
                if(adc_fifo_full_i == 1'b0) begin
                    adc_fifo_dat_o <= {adcf_dat[15:2], 2'b0, adcf_dat[31:18], 2'b0};
                    // RMR, use shifted 16-bit #'s above  adc_fifo_dat_o <= {2'b0, adcf_dat[15:2], 2'b0, adcf_dat[31:18]};
                    // test:adc_fifo_dat_o <= {2'b0, 14'h1000, 2'b0, 14'h1fff};                
                    adc_fifo_wen_o <= 1'b1;                // write ADCF data
                end
                astate <= ADone2;
            end
            ADone2: begin
                if(adc_fifo_full_i == 1'b0) begin
                    adc_fifo_dat_o <= {adcr_dat[15:2], 2'b0, adcr_dat[31:18], 2'b0};
                    //adc_fifo_dat_o <= {2'b0, adcr_dat[15:2], 2'b0, adcr_dat[31:18]};
                    // test:adc_fifo_dat_o <= {2'b0, 14'h2000, 2'b0, 14'h3000};
                    adc_fifo_wen_o <= 1'b1;                // write ADCR data
                end
                astate <= AIdle;
            end
            endcase // case (astate)
      end


    /////////////////////////////////
    // Set Pulse state definitions //
    /////////////////////////////////
    localparam PULSE_IDLE           = 0;
    localparam PULSE_READ           = 1;
    localparam PULSE_SPACER         = 2;
    localparam PULSE_RUN            = 3;
    localparam PULSE_DONE           = 4;
    ////////////////////////////////////////
    // End of pulse state definitions //
    ////////////////////////////////////////

    always @( posedge sys_clk)
    begin
        if(!sys_rst_n) begin
            state <= PULSE_IDLE;
            pls_fifo_ren_o <= 1'b0;
            pulse <= 24'h00_000000;
            channel <= 4'b0000;
            ticks <= 24'h00_0000;
            sys_ticks <= 32'd0;
            measure <= 1'b0;
            measure_at <= 24'h00_0000;
            rf_gate <= 1'b0;
            rf_gate2 <= 1'b1;       // Initial release this is always ON
            conv <= 1'b0;
            //zmon_en <= 1'b0;
            status_o <= `SUCCESS;
        end
        else if(pulse_en == 1'b1) begin
            case(state)
            PULSE_IDLE: begin
                if(!pls_fifo_mt_i && astate == AIdle) begin
                    // pulse requested & measurement Idle
                    pls_fifo_ren_o <= 1'b1;     // read next value
                    state <= PULSE_SPACER;
                    status_o = 8'h00;           // busy
                end
                else begin
                    rf_gate <= 1'b0;
                    rf_gate2 <= 1'b1;           // Initial release, always ON
                    conv <= 1'b0;
                    if(status_o == 8'h00)
                        status_o <= `SUCCESS;
                end
            end
            PULSE_SPACER: begin
                state <= PULSE_READ;
            end
            PULSE_READ: begin
                // read pulse data from fifo
                // turn RF_GATE ON (start pulse)
                pulse <= pls_fifo_dat_i[31:8];      // 100ns ticks of width
                ticks <= 24'h00_0000;
                sys_ticks <= 32'h0000_0000;
                measure <= pls_fifo_dat_i[32];
                measure_at <= pls_fifo_dat_i[63:39] - 24'h00_0000_0001;   // meas offset 0-based 
                pls_fifo_ren_o <= 0;
                rf_gate <= pulse_en & rf_enable_i & zm_normal_i;   // on
                //rf_gate2 <= pulse_en & rf_enable_i;   // this switch is too fast for PA, leave ON
                if(pls_fifo_dat_i[32] == 1'b1 &&
                    pls_fifo_dat_i[63:39] - 24'h00_0000_0001 == 0)
                    conv <= 1'b1;   // measure at tick 0
                else conv <= 1'b0;  // measure OFF at tick 0
                state <= PULSE_RUN;
            end
            PULSE_RUN: begin
//                if(ticks == pulse) begin
//                    state <= PULSE_DONE;
//                    rf_gate <= 1'b0;
//                    //rf_gate2 <= 1'b0;
//                    conv <= 1'b0;
//                end
                if(measure) begin
                    if(ticks == measure_at)
                        conv <= 1'b1;           // Start ZMON conversion using conv line                    
                    else if(ticks == measure_at+1)
                        conv <= 1'b0;           // CONV OFF
                end
                //             
                if(sys_ticks == PULSE_TICKS) begin
                    ticks <= ticks + 1;
                    sys_ticks <= 8'h00;               
                    if((ticks+1) == pulse) begin    // stop this puppy before an extra tick goes by
                        state <= PULSE_DONE;
                        rf_gate <= 1'b0;
                        //rf_gate2 <= 1'b0;
                        conv <= 1'b0;
                    end
                end
                else
                    sys_ticks <= sys_ticks + 1;
            end
            PULSE_DONE: begin
                // make sure measurement done too before returning to idle
                if(astate == AIdle) begin
                    status_o = `SUCCESS;
                    state <= PULSE_IDLE;
                end                
            end
            default:
                begin
                    status_o = `ERR_UNKNOWN_PULSE_STATE;
                    state = PULSE_IDLE;
                end
            endcase
        end
    end    

endmodule
