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
    output wire         rf_gate2_o,         // RF_GATE2 line

    output wire         zmon_en_o,          // Enable ZMON
    output wire         conv_o,             // CONV pulse
    output wire         adc_sclk_o,         // ZMON SCK
    input  wire         adcf_sdo_i,         // FWD SDO
    input  wire         adcr_sdo_i,         // REFL SDO
    input  wire         adctrig_i,          // Host read request

    output reg [31:0]   adc_fifo_dat_o,     // 32 bits of FWD REFL ADC data written to output fifo
    output reg          adc_fifo_wen_o,     // ADC results fifo write enable

    output reg  [7:0]   status_o            // 0=Busy, SUCCESS when done, or an error code
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
    localparam PULSE_TICKS = 10;            // 10 sys ticks per pulse tick

    reg             rf_gate;
    reg             rf_gate2;
    reg             zmon_en;
    reg             conv;
    reg             adc_sclk;

    // connect ZMON lines
    assign rf_gate_o = rf_gate;
    assign rf_gate2_o = rf_gate2;
    assign zmon_en_o = zmon_en;
    assign adc_sclk_o = adc_sclk;

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

`ifdef XILINX_SIMULATOR
    integer         filepulse = 0;
    reg [7:0]       dbgdata;
`endif

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
            rf_gate2 <= 1'b0;
            conv <= 1'b0;
        end
        else if(pulse_en == 1'b1) begin
            case(state)
            PULSE_IDLE: begin
                if(!pls_fifo_mt_i) begin
                    pls_fifo_ren_o <= 1'b1;   // read next value
                    state <= PULSE_SPACER;
                    status_o <= 1'b0;
                end
                else begin
                    status_o <= 1'b1;
                    rf_gate <= 1'b0;
                    rf_gate2 <= 1'b0;
                    conv <= 1'b0;
                end
            end
            PULSE_SPACER: begin
                state <= PULSE_READ;
            end
            PULSE_READ: begin
                // read pulse data from fifo
                // turn RF_GATE ON (start pulse)
                pulse <= pls_fifo_dat_i[31:8] - 24'h00_0000_0001;         // pulse width count is 0-based
                ticks <= 24'h00_0000;
                sys_ticks <= 32'h0000_0000;
                measure <= pls_fifo_dat_i[32];
                measure_at <= pls_fifo_dat_i[63:39] - 24'h00_0000_0001;   // meas offset 0-based 
                pls_fifo_ren_o <= 0;
                rf_gate <= pulse_en & rf_enable_i;   // on
                rf_gate2 <= pulse_en & rf_enable_i;
                conv <= 1'b0;
                state <= PULSE_RUN;
            `ifdef XILINX_SIMULATOR
                if(filepulse == 0)
                    filepulse = $fopen("../../../project_1.srcs/sources_1/pulse_in.txt", "a");
                $fdisplay (filepulse, "Pulse:0x%h ON", pls_fifo_dat_i);
            `endif
            end
            PULSE_RUN: begin
                if(ticks == pulse) begin
                    state <= PULSE_DONE;
                    rf_gate <= 1'b0;
                    rf_gate2 <= 1'b0;
                `ifdef XILINX_SIMULATOR
                    $fdisplay (filepulse, "Pulse Done");
                `endif
                end
                else if(measure) begin
                    if(ticks == measure_at) begin
                        // Start a measurement                
                      `ifdef XILINX_SIMULATOR
                        if(filepulse == 0)
                            filepulse = $fopen("../../../project_1.srcs/sources_1/pulse_in.txt", "a");
                        $fdisplay (filepulse, "Pulse->Meas at 0x%h", measure_at);
                      `endif
                        conv <= 1'b1;       // Start ZMON conversion using conv line
                    end
                    else if(ticks == measure_at+2)
                        conv <= 1'b0;         // CONV OFF
                end
                //             
                if(sys_ticks+1 == PULSE_TICKS) begin
                    ticks <= ticks + 1;
                    sys_ticks <= 8'h00;               
                end
                else
                    sys_ticks <= sys_ticks + 1;
            end
            PULSE_DONE: begin
                // return measurements, etc
                state <= PULSE_IDLE;
                status_o = `SUCCESS;
            end
            default:
                begin
                `ifdef XILINX_SIMULATOR
                    $fdisplay (filepulse, "Pulse:Unknwon State Error");
                    if(pls_fifo_mt_i) begin
                        $fclose(filepulse);
                        filepulse = 0;
                    end
                `endif
                    status_o = `ERR_UNKNOWN_PULSE_STATE;
                    state = PULSE_IDLE;
                end
            endcase
        end
    end    

    // ZMON ADC variables, processing
    wire read_zmon;
    assign read_zmon = adctrig_i | conv; 

   // LTC1407A ADC state machine
    localparam AIdle = 3'd0, ASckOn = 3'd1, ASckOnWait = 3'd2, ASckOff = 3'd3, ADone = 3'd4, ADone2 = 3'd5, SckOnStretch = 3'd2;
    reg [2:0]       astate = AIdle;
    reg [31:0]      adcf_dat = 32'b0;
    reg [31:0]      adcr_dat = 32'b0;
    reg [5:0]       acount = 6'b0;
    reg [2:0]       sck_time = 3'b0;
    
    // Assumes 100MHz clock, /6 = 16.67MHz for LTC1407A's
    always @(posedge sys_clk)    // 100MHz, 6 clocks per T = 16.667MHz 'SPI'
        if(!sys_rst_n) begin
            astate <= AIdle;
            adc_fifo_wen_o <= 0;
        end
        else begin
            case (astate)
            AIdle: begin
                adc_fifo_wen_o <= 0;
                if (read_zmon) begin
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
                adc_fifo_dat_o <= {adcf_dat[15:2], 2'b0, adcf_dat[31:18], 2'b0};
                adc_fifo_wen_o <= 1'b1;                // write ADCF data
                astate <= ADone2;
            end
            ADone2: begin
                adc_fifo_dat_o <= {adcr_dat[15:2], 2'b0, adcr_dat[31:18], 2'b0};
                adc_fifo_wen_o <= 1'b1;                // write ADCR data
                astate <= AIdle;
            end
            endcase // case (astate)
      end

endmodule