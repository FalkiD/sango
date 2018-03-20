//////////////////////////////////////////////////////////////////////////////////
// Company: Ampleon USA
// Engineer: Rick Rigby
// 
// Create Date: 03/28/2016 06:13:10 PM
// Design Name: Sango MMC interface
// Module Name: opcodes
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: MMC opcode processor for sango FPGA corees
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments: Integration with MMC core, 17-Feb-2017
//
// Opcodes get processed until the read fifo is empty. If an error occurs
// a response will be sent. No more  processing will be done until the
// response fifo is empty. If no errors occur processing continues until
// the read fifo is empty.
//
// History:
//  11-Jan-2018 V1.01.1, bugfix, can't get to STATE_DATA when RD line is OFF!
//  11-Nov-2017 Shipped first article to Imagineering, FPGA V1.01.0 
//////////////////////////////////////////////////////////////////////////////////

`include "timescale.v"
`include "version.v"
`include "status.h"
`include "opcodes.h"

`define STATE_IDLE                  7'h01
`define STATE_FETCH_FIRST           7'h02   // 1 extra clock after assert rd_en   
`define STATE_FETCH                 7'h03
`define STATE_LENGTH                7'h04
`define STATE_DATA                  7'h05
`define STATE_PTN_DATA1             7'h06
`define STATE_WAIT_DATA             7'h07   // Waiting for more fifo data
`define STATE_READ_SPACER           7'h08
`define STATE_FIFO_WRITE            7'h09
`define STATE_BEGIN_RESPONSE        7'h0c
`define STATE_WRITE_LENGTH1         7'h0d
`define STATE_WRITE_LENGTH2         7'h0e
`define STATE_RSP_OPCODE            7'h0f
`define STATE_WRITE_RESPONSE        7'h10
`define STATE_WR_PTN                7'h11
`define STATE_PTN_DATA2             7'h12
`define STATE_CLR_PTN1              7'h13
`define STATE_CLR_PTN2              7'h14
`define STATE_RD_MEAS1              7'h15
`define STATE_RD_MEAS2              7'h16
`define STATE_RD_MEAS3              7'h17
`define STATE_RD_MEAS4              7'h18
`define STATE_RD_MEAS5              7'h19
`define STATE_RD_SPACER             7'h1a
`define STATE_DBG3                  7'h1b

/*
    Opcode block MUST be terminated by a NULL opcode
    Later: Fix this requirement, opcode processor must sit & wait 
    for next byte. MMC clock and this module's SYS_CLK are different. 
    Normal to wait for next byte.
*/
module opcodes #(parameter MMC_FILL_LEVEL_BITS = 16,
                 parameter PCMD_BITS = 4,
                 parameter PTN_FILL_BITS = 16,
                 parameter PTN_WR_WORD = 96,
                 parameter PTN_RD_WORD = 72,
                 parameter HUNDRED_MS = 10000000,    // 10e6 ticks per 100ms
                 parameter TWOFIFTY_MS = 50000000     // 25e6 ticks per 250ms
  )
  (
    input  wire          sys_clk,
    input  wire          sys_rst_n,
    input  wire          enable,

    input  wire [7:0]    fifo_dat_i,              // opcode fifo
    output reg           fifo_rd_en_o,            // fifo read line
    input  wire          fifo_rd_empty_i,         // fifo empty flag
    input  wire [MMC_FILL_LEVEL_BITS-1:0]  fifo_rd_count_i, // fifo fill level
    output reg           fifo_rst_o,              // reset input fifo as soon as we get a null opcode 

    input  wire [15:0]   system_state_i,          // overall state of system, "running a pattern", for example
    output reg  [31:0]   mode_o,                  // MODE opcode can set system-wide flags
    input  wire          pulse_busy_i,            // Pulse processor is busy (must wait for measurements)

    output reg  [7:0]    response_o,              // to fifo, response bytes(status, measurements, echo, etc)
    output reg           response_wr_en_o,        // response fifo write enable
    input  wire          response_fifo_empty_i,   // response fifo empty flag
    input  wire          response_fifo_full_i,    // response fifo full flag
    output wire          response_ready_o,        // response is waiting
    output wire [MMC_FILL_LEVEL_BITS-1:0] response_length_o,     // update response length when response is ready
    input  wire [MMC_FILL_LEVEL_BITS-1:0] response_fifo_count_i, // response fifo count, response_ready when fifo_length==response_length

    output reg  [31:0] frequency_o,               // to fifo, frequency output in MHz
    output reg         frq_wr_en_o,               // frequency fifo write enable
    input              frq_fifo_empty_i,          // frequency fifo empty flag
    input              frq_fifo_full_i,           // frequency fifo full flag

    output reg  [38:0] power_o,                   // to fifo, power output in dBm
    output reg         pwr_wr_en_o,               // power fifo write enable
    // power calibration outputs
    output wire [11:0] pwr_caldata_o,             // data written into power table
    output reg  [11:0] pwr_calidx_o,              // index into power table
    output reg         pwr_calibrate_o,           // doing power calibration, frequency will choose which power table

    output reg  [63:0] pulse_o,                   // to fifo, pulse opcode
    output reg         pulse_wr_en_o,             // pulse fifo write enable

    input  wire [31:0] meas_fifo_dat_i,           // measurement fifo from pulse opcode
    output reg         meas_fifo_ren_o,           // measurement fifo read enable
    input  wire [PTN_FILL_BITS-1:0] meas_fifo_cnt_i, // measurements in fifo after pulse/pattern

    output reg         bias_enable_o,             // bias control

    input wire         extrig_i,                  // external trigger input, rising edge
    output wire [31:0] trig_conf_o,               // trig_configuration word
    output reg  [31:0] config_o,                  // various configuration bits, CONFIG opcode

    // pattern opcodes are saved in pattern RAM.
    output reg  [PCMD_BITS-1:0]     ptn_cmd_o,    // command/mode, used to clear sections of pattern RAM
    output reg                      ptn_wen_o,    // opcode processor saves pattern opcodes to pattern RAM 
    output wire [PTN_FILL_BITS-1:0] ptn_addr_o,   // address 
    output wire [PTN_WR_WORD-1:0]   ptn_data_o,   // 12 bytes, 3 bytes patclk tick, 9 bytes for opcode and its data   

    // pattern entries are run from this fifo when it's not empty
    input  wire [PTN_RD_WORD-1:0]   ptn_data_i,   // next pattern opcode to run, 0 if nothing to do
    output reg                      ptn_fifo_ren_o, // read enable pattern fifo  
    input  wire                     ptn_fifo_mt_i,  // pattern fifo empty flag
    output reg                      ptn_run_o,    // run pattern 
    input  wire [PTN_FILL_BITS-1:0] ptn_index_i,  // index of pattern entry being run (for status only)
    input  wire [7:0]               ptn_status_i, // pattern processor status
    output reg                      ptn_rst_n_o,  // pattern reset from PTN_CTL[RESET] opcode

    output reg  [31:0]   opcode_counter_o,        // count opcodes for status info                     
    output reg  [7:0]    status_o,                // NULL opcode terminates, done=0, or error code
    output wire [6:0]    state_o,                 // For debugger display
    
    // Debugging
    output reg  [31:0]   dbg_opcodes_o,           // Upr16[OpcMode(8)__patadr_count(8)]____Lwr16[first_opcode__last_opcode]
    output reg  [31:0]   dbg2_o,                  // debugging patterns

    // STATUS command
    input  wire          syn_stat_i,              // SYN STAT pin, 1=PLL locked
    input  wire [11:0]   dbm_x10_i                // dBm x10, system power level    
    );

    // opcodes with integer arguments have 8 bytes or less of data
    localparam INT_ARG_BYTES = 8;

    // PowerCal modes when opcode is CALPTBL and state = STATE_WRITE_DATA
    localparam PWRCAL1          = 4'd1;
    localparam PWRCAL2          = 4'd2;
    localparam PWRCAL_SPACER    = 4'd3;
    localparam PWRCAL3          = 4'd4;

    // trigger bit definitions
    localparam TRIG_ARM         = 8'h80;    // Arm trigger
    localparam TRIG_ABORT       = 8'h40;    // Abort triggering
    localparam TRIG_NOW         = 8'h20;    // Send pattern now
    localparam TRIG_CONTINUOUS  = 8'h10;    // Continuous mode, every N ms, N was user-programmed
    localparam TRIG_SOURCE      = 8'h04;    // This box is trigger source
    localparam TRIG_EXTERN      = 8'h02;    // This box is trigger slave
    localparam TRIG_ENABLE      = 8'h01;    // Enable triggering

    reg  [3:0]   operating_mode = `OPCODE_NORMAL; // 0=normal, process & run opcodes, other cmds for pattern load/run
    reg  [6:0]   state = `STATE_IDLE;             // Use as flag in hardware to indicate first starting up
    reg  [6:0]   next_state = `STATE_IDLE;
    reg  [6:0]   last_state = `STATE_IDLE;
    reg          blk_rsp_done;       // flag, 1 sent response for block, 0=response not sent yet
    reg  [6:0]   opcode = 0;         // Opcode being processed
    reg  [9:0]   length = 0;         // bytes of opcode data to read
    reg  [31:0]  bytes_processed;    // count opcode fifo bytes processed
    reg  [63:0]  uinttmp;            // temp for opcode data, up to 8 bytes
    reg          len_upr = 0;        // Persist upper bit of length
    reg          response_ready;     // flag when response ready
    reg  [MMC_FILL_LEVEL_BITS-1:0]  response_length;    // length of response data
    reg  [MMC_FILL_LEVEL_BITS-1:0]  rsp_length;         // length tmp var
    reg  [7:0]   rsp_data [`STATUS_RESPONSE_SIZE-1:0];  // 26 byte array of response bytes for status
    reg  [MMC_FILL_LEVEL_BITS-1:0]  rsp_index;          // response array index
    localparam GENERAL_ARR  = 2'b00;
    localparam MEAS_FIFO    = 2'b01;
    reg  [1:0]                      rsp_source;         // 0=general array, 1=measurement fifo

    // Pattern data registers
    reg  [PTN_FILL_BITS-1:0]        ptn_addr;           // pattern address to write
    reg  [23:0]                     ptn_clk;            // pattern clock tick to write
    reg  [PTN_WR_WORD-1:0]          ptn_data_reg;       // pattern data written to pattern RAM
    reg  [7:0]                      ptn_latch_count;    // Clocks to latch data into RAM
    reg  [7:0]                      ptn_count;

    reg  [31:0]  trig_conf;          // trigger configuration, from trig_conf opcode
    localparam TICKS_PER_MS   = 18'd100000;
    reg  [8:0]   trig_ms;            // continuous trigger millisecond counter
    reg  [17:0]  trig_counter = 18'd0; // 100,000 ticks per millisecond, 18 bits
    reg          extrigg;            // external trigger latch, detect rising edge
    reg  [15:0]  sync_conf;          // sync configuration, from sync_conf opcode
    
    // handle opcode integer argument data in a common way
    reg  [31:0]  shift = 0;          // tmp used building opcode data and returning measurements, etc
    
    //wire         pulse_busy;  just use pulse_busy_i
    wire         pwr_busy;
    wire         frq_busy;
    
    reg  [3:0]   pwrcal_mode;
    reg  [11:0]  pwr_caldata;        // put together 12-bit word to write into power table

    reg  [15:0]  version = `VERSION;

    // Zmon (MEAS) calibration registers
    reg  [31:0]  zm_fi_gain;         // zmon fwd "I" ADC gain, Q15.16 float
    reg  [15:0]  zm_fi_offset;       // zmon fwd "I" ADC offset, signed int
    reg  [31:0]  zm_fq_gain;         // zmon fwd "Q" ADC gain, Q15.16 float
    reg  [15:0]  zm_fq_offset;       // zmon fwd "Q" ADC offset, signed int

    reg  [31:0]  zm_ri_gain;         // zmon refl "I" ADC gain, Q15.16 float
    reg  [15:0]  zm_ri_offset;       // zmon refl "I" ADC offset, signed int
    reg  [31:0]  zm_rq_gain;         // zmon refl "Q" ADC gain, Q15.16 float
    reg  [15:0]  zm_rq_offset;       // zmon refl "Q" ADC offset, signed int
    
    reg  [7:0]   meas_ops;           // which operations
    reg          run_calcs;          // run meas_calcs instance, process one measurement
    wire         calc_done;          // done flag    
    reg  [31:0]  adcf_raw;           // meas_calcs input raw data
    reg  [31:0]  adcr_raw;           // meas_calcs input raw data
    wire [31:0]  adcf_dat;           // meas_calcs output, FWDQ FWDI ADC or Q15.16 FWDI volts
    wire [31:0]  adcr_dat;           // meas_calcs output, RFLQ RFLI ADC or Q15.16 RFLI volts
    wire [31:0]  adcfq_volts;        // meas_calcs output, Q15.16 FWDQ volts
    wire [31:0]  adcrq_volts;        // meas_calcs output, Q15.16 RFLQ volts
    // Measurement calculation, calibration instance
    meas_calcs meas_math
    (
        .sys_clk            (sys_clk),
        .sys_rst_n          (sys_rst_n),
  
        .ops_i              (meas_ops),             // which operation(s)
        .run_i              (run_calcs),            // do it
        .done_o             (calc_done),            // calculation(s) done

        .adcf_dat_i         (adcf_raw),             // [xx][FWDQ][xx][FWDI]
        .adcr_dat_i         (adcr_raw),             // [xx][RFLQ][xx][RFLI]

        .adcf_dat_o         (adcf_dat),             // [16 bits calibrated FWDQ][16 bits calibrated FWDI]
        .adcr_dat_o         (adcr_dat),             // [16 bits calibrated RFLQ][16 bits calibrated RFLI]
        .adcfq_volts_o      (adcfq_volts),          // [Q15.16 format calibrated FWDQ voltage] (ops_i[M_VOLTS])
        .adcrq_volts_o      (adcrq_volts),          // [Q15.16 format calibrated RFLQ voltage] (ops_i[M_VOLTS])

        .zm_fi_gain_i       (zm_fi_gain),           // zmon fwd "I" ADC gain, Q15.16 float
        .zm_fi_offset_i     (zm_fi_offset),         // zmon fwd "I" ADC offset, signed int
        .zm_fq_gain_i       (zm_fq_gain),           // zmon fwd "Q" ADC gain, Q15.16 float
        .zm_fq_offset_i     (zm_fq_offset),         // zmon fwd "Q" ADC offset, signed int
    
        .zm_ri_gain_i       (zm_ri_gain),           // zmon refl "I" ADC gain, Q15.16 float
        .zm_ri_offset_i     (zm_ri_offset),         // zmon refl "I" ADC offset, signed int
        .zm_rq_gain_i       (zm_rq_gain),           // zmon refl "Q" ADC gain, Q15.16 float
        .zm_rq_offset_i     (zm_rq_offset)         // zmon refl "Q" ADC offset, signed int  
    );


    // opcode processing
    always @( posedge sys_clk) begin
        if(!sys_rst_n) begin
            reset_opcode_processor();
            dbg2_o <= 32'hbaadf00d;
        end
        else if(enable == 1) begin

            // 02-Feb-2018 use upper 8 bits to count external trigger pulses for dbg
            //dbg2_o <= {ptn_data_i[71:64], 11'd0, meas_fifo_cnt_i};
            //dbg2_o <= {12'd0, pwrcal_mode, bytes_processed[15:0]};
            // 02-Oct bytes_processed added for debugging, may use to read 1 sector at a time.
            // value is incorrect though, double-counts twice. 512 byte sector comes to 0x202??
            dbg_opcodes_o[27:24] <= operating_mode;   // operating_mode to debugger
        
        dbg2_o[31:24] <= {7'b000_0000, extrigg};            

            // 07-Feb refactor
            // If IDLE and MMC fifo is empty check for all other 
            // requests: start a pattern, run pattern opcode, trigger.
            extrigg <= 1'b0;    // 1-tick signal to catch rising edge of tigger
            if(state == `STATE_IDLE && fifo_rd_count_i == 0) begin
                // 1) check for pattern start request if pattern not running
                if(operating_mode == `PTNCMD_RUN && ptn_run_o == 1'b0) begin
                    // we haven't started it yet
                    ptn_run_o <= 1'b1; // start pattern processor
                end
                // 2) Check for pattern processor request to run opcode
                else if(!ptn_fifo_mt_i) begin
                    // execute the next pattern opcode from the pattern fifo
                    ptn_fifo_ren_o <= 1'b1;
                    state <= `STATE_PTN_DATA1;            
                end
                // 3) If trigger enabled & (pattern & pulse) not running,
                //    check for trigger requests
                else if(trig_conf[`TRGBIT_EN] == 1'b1 && 
                            operating_mode == `OPCODE_NORMAL && 
                            pulse_busy_i == 1'b0) begin
                    // Handle triggering options if pattern processor 
                    // and pulse processor are ready
                    if(trig_conf[`TRGBIT_CONT] == 1'b1) begin
                       if(trig_ms >= trig_conf[23:16]) begin
                           // run pattern, reset counters
                            start_pattern(ptn_addr);
                           trig_ms <= 9'd0;
                           trig_counter <= 18'd0;
                       end
                       if(trig_counter >= TICKS_PER_MS) begin
                           trig_ms <= trig_ms + 9'd1;
                           trig_counter <= 18'd0;                    
                       end
                       else
                           trig_counter <= trig_counter + 18'd1;
                    end
                    else if(trig_conf[`TRGBIT_EXT] == 1'b1) begin
                       if(extrig_i == 1'b1 && extrigg == 1'b0) begin
                           // rising edge of TRIG_IN signal detected
                           // Not checking for overrun yet...
                    
              dbg2_o[15:0] <= dbg2_o[15:0] + 16'h0001;
                    
                           start_pattern(ptn_addr);
                           extrigg <= 1'b1;    // 1-tick signal
                       end
                    end
                end
            end
            // Process opcodes from MMC fifo and all other states
            else if((state == `STATE_IDLE && fifo_rd_count_i >= `MIN_OPCODE_SIZE) ||
                    state != `STATE_IDLE) begin
                // not IDLE or at least one opcode has been written to FIFO
                case(state)
                `STATE_IDLE: begin
                    // Don't continue until the response has been read(response fifo empty)
                    if(response_fifo_empty_i && !fifo_rd_empty_i) begin 
                        // Start processing opcodes, don't return to 
                        // `STATE_IDLE until a null opcode is seen.
                        begin_opcodes();
                        state <= `STATE_FETCH_FIRST;
                    end
                end

                // get next pattern entry from fifo
                `STATE_PTN_DATA1: begin
                    state <= `STATE_PTN_DATA2;
                end
                `STATE_PTN_DATA2: begin
                    // --set opcode, length, and uinttmp registers
                    // --set state to STATE_DATA, continue.
                    // this jumps into normal opcode processing
                    //dbg2_o <= {ptn_data_i[71:64], 11'd0, meas_fifo_cnt_i};
                    opcode <= ptn_data_i[70:64];
                    length <= 0;                        // jump into processing uinttmp
                    uinttmp <= ptn_data_i[63:0];
                    ptn_fifo_ren_o <= 1'b0;
                    state <= `STATE_DATA;               // process the parsed opcode
                end

                // Opcode block done, write response fifo: status, pad byte, 
                // 2 length bytes, then data if any, then assert response_ready
                `STATE_BEGIN_RESPONSE: begin
                    response_length <= rsp_length + `DEFAULT_RESPONSE_LENGTH;  // add room for status byte
                    rsp_index <= 16'h0000;
                    // Status code is first 2 bytes, begin
                    if(status_o == 0) begin         // if status indicates busy(0), set 'SUCCESS
                        status_o <= `SUCCESS;       // Update status_o to SUCCESS
                        response_o <= `SUCCESS;     // SUCCESS into response fifo, done with opcode block
                    end
                    else
                        response_o <= status_o;
                    response_wr_en_o <= 1;
                    state <= `STATE_RSP_OPCODE;
                end
                `STATE_RSP_OPCODE: begin  // opcode responding to
                    response_o <= dbg_opcodes_o[7:0];
                    state <= `STATE_WRITE_LENGTH1;
                end
                `STATE_WRITE_LENGTH1: begin  // LS byte of data length
                    response_o <= rsp_length[7:0];
                    state <= `STATE_WRITE_LENGTH2;
                end
                `STATE_WRITE_LENGTH2: begin      // MS byte of status always 0 for now
                    response_o <= {5'd0, rsp_length[10:8]}; //8'h6c;         // (rsp_length>>8) & 8'hff;
                    state <= `STATE_WRITE_RESPONSE;
                end
                `STATE_WRITE_RESPONSE: begin
                    // this messes up the MMC core??? fifo_rst_o <= 1'b0;             // clear input fifo reset line after a few clocks
                    if(rsp_length > 0) begin
                        if(rsp_source == MEAS_FIFO) begin
                            response_wr_en_o <= 1'b0;       // Off while we read fifo
                            meas_fifo_ren_o <= 1'b1;        // start reading measurement fifo                        
                            uinttmp <= 64'd0;
                            state <= `STATE_RD_SPACER;
                        end
                        else begin
                            response_o <= rsp_data[rsp_index];
                            rsp_length <= rsp_length - 1;
                            rsp_index <= rsp_index + 1;
                        end
                    end
                    else begin
                        response_wr_en_o <= 1'b0;
                        response_ready <= 1'b1;
                        state <= `STATE_IDLE;
                        if(status_o == 0)
                            status_o <= `SUCCESS;       // Reset status_o if it's not set to an error
                    end
                end
                `STATE_RD_SPACER: begin
                    response_wr_en_o <= 1'b0;           // don't write extra response byte after meas word
                    state <= `STATE_RD_MEAS1;
                end
                `STATE_RD_MEAS1: begin
                    adcf_raw <= meas_fifo_dat_i;
                    //response_wr_en_o <= 1'b0;           // don't write extra response byte after meas word
                    meas_fifo_ren_o <= 1'b0;
                    state <= `STATE_RD_MEAS2;
                end
                `STATE_RD_MEAS2: begin
                    adcr_raw <= meas_fifo_dat_i;
                    // too late  meas_fifo_ren_o <= 1'b0;
                    state <= `STATE_RD_MEAS3;
                end
                `STATE_RD_MEAS3: begin
                    // process meas fifo adc results based on requested MEAS arg options
                    run_calcs <= 1'b1;
                    state <= `STATE_RD_MEAS4;
                end
                `STATE_RD_MEAS4: begin
                    if(calc_done) begin
                        run_calcs <= 1'b0;
                        if(meas_ops[1] == 1'b1) begin
                            uinttmp <= {adcr_dat, adcf_dat};
                        end
                        else if(meas_ops[2])
                            // volts needs 16 bytes, uses 2 sets of registers,
                            // here we're always on a 16-byte boundary, use the 1st set of registers
                            uinttmp <= {adcfq_volts, adcf_dat};
                        state <= `STATE_RD_MEAS5;                    
                    end
                end
                `STATE_RD_MEAS5: begin
                    rsp_length <= rsp_length - 1;
                    rsp_index <= rsp_index + 1;

                    // write response byte
                    response_wr_en_o <= 1'b1;
                    response_o <= uinttmp[7:0];

                    // prep next byte
                    if(((rsp_index+1) & 3'b111) == 3'b000 && rsp_length > 1) begin
                        // volts mode needs 16 bytes, uses 2 sets of registers,
                        // if we're not on a 16-byte boundary then use
                        // 2nd set of registers
                        if(meas_ops[2] && ((rsp_index+1) & 4'b1111) != 4'b0000)
                            // not on 16-byte boundary, continue using 2nd register set
                            uinttmp <= {adcrq_volts, adcr_dat}; 
                        else begin
                            meas_fifo_ren_o <= 1'b1;                // read next result
                            state <= `STATE_RD_SPACER;
                        end
                    end
                    else
                        uinttmp <= {8'h00, uinttmp[63:8]};

                    // Done?
                    if(rsp_length == 0) begin
                        // Note: we have already completed response, set the flag to
                        // prevent null opcodes from generating another response
                        response_wr_en_o <= 1'b0;
                        response_ready <= 1'b1;
                        next_opcode();
                        blk_rsp_done <= 1'b1;      // Flag we've done a response
                        if(status_o == 0)
                            status_o <= `SUCCESS;       // Reset status_o if it's not set to an error
                    end
                end
    
                // Just began from `STATE_IDLE
                `STATE_FETCH_FIRST: begin
                    state <= `STATE_FETCH;  // extra tick to get reads going
                end
                // **** 02-Aug If 256 byte opcode is illegal then we can know
                // ****        a 0-length opcode from its first byte & turn OFF
                // ****        reads NOW. If we don't we read one extra byte &
                // ****        leave an extra byte in the input FIFO
                `STATE_FETCH: begin
                    // Added 02-Oct-2017 for debugging, count is 2 high though??
                    bytes_processed <= bytes_processed + 32'h0000_0001;
                    
                    shift <= 8'h00;
                    uinttmp <= 64'h0000_0000_0000_0000;
                    length <= {1'b0, fifo_dat_i};
                    // **** 02-Aug if 0 length then turn OFF read NOW
                    // 01-Nov added '=' to '<', if not enough to continue
                    // must turn OFF now to avoid missing next byte
                    if({1'b0, fifo_dat_i} >= (fifo_rd_count_i-1) || fifo_dat_i == 8'h00)
                        fifo_rd_en_o <= 0;                    // must turn OFF REN 1 clock early
                    state <= `STATE_LENGTH;   // Part 1 of length, get length msb & get opcode next
                end
                `STATE_LENGTH: begin
                    length <= {fifo_dat_i[0], length[7:0]};
                    rsp_index <= 16'h0000;                  // index for multi-byte data blocks
                    opcode <= fifo_dat_i[7:1];              // got opcode, start reading data
                    if(bad_opcode(fifo_dat_i[7:1])) begin   // stop if the opcode is bogus
                        state <= `STATE_IDLE;
                    end
                    // length tests
                    else if({fifo_dat_i[0], length[7:0]} > (fifo_rd_count_i-1)) begin
                        // need more data, wait for it if valid request
                        if((fifo_dat_i[7:1] != `CALPTBL && fifo_dat_i[7:1] != `CALZMON)
                                 && length > INT_ARG_BYTES) begin
                           // Opcode with integer argument
                           // ...none have more than 8 bytes of data
                            status_o <= `ERR_INVALID_LENGTH;
                            state <= `STATE_BEGIN_RESPONSE;
                        end
                        else begin
                            fifo_rd_en_o <= 0;                  // let it fill
                            state <= `STATE_WAIT_DATA;
                        end
                    end
                    else begin
                        if({fifo_dat_i[0], length[7:0]} == 0) begin
                            fifo_rd_en_o <= 0;              // don't read next byte, opcode has no data
                            state <= `STATE_DATA;           // 11-Jan-2018 rearrangement after bugfix
                        end
                        else if(fifo_rd_en_o == 1'b0) begin
                            fifo_rd_en_o <= 1'b1;           // 11-Jan-2018 bugfix, can't get to STATE_DATA when RD line is OFF!
                            state <= `STATE_READ_SPACER;                        
                        end
                        else
                            state <= `STATE_DATA;
                    end
                end
                `STATE_WAIT_DATA: begin // Wait for asynch FIFO to receive all our data

      //dbg2_o <= {5'd0, fifo_rd_count_i, 6'd0, length};

                    if(fifo_rd_count_i >= length) begin
                        fifo_rd_en_o <= 1;                  // start reading again

      //dbg2_o <= {5'd0, fifo_rd_count_i, 6'd0, length};

                        state <= `STATE_READ_SPACER;
                    end
                end
                `STATE_READ_SPACER: begin
                    state <= `STATE_DATA;
                end
                `STATE_DATA: begin
                    if(dbg_opcodes_o[14:8] == 7'b0000000)
                        dbg_opcodes_o[14:8] <= opcode;
                        
                    // 02-Oct bytes_processed added for debugging, may use to read 1 sector at a time.
                    // value is incorrect though, double-counts twice. 512 byte sector comes to 0x202??
                    bytes_processed <= bytes_processed + 32'h0000_0001;

                    // Look for special opcodes, RESET & NULL Terminator
                    // On NULL, check for response data available. If measurement data is in the fifo
                    // send it. Make sure the pulse & pattern processors are idle(done) first.
                    if(opcode == 0) begin
                        // Do not wait for anything, other opcodes are used to read measurement results
                        // and other specialized responses
                        //state <= `STATE_WMD;    // Check for measurement done before doing response
                        if(blk_rsp_done == 1'b0) begin
                          blk_rsp_done <= 1'b1;      // Flag we've done it
                          // this f's up the MMC core, asserts MMC d0 for a while, count increases to 0x200???  fifo_rst_o <= 1'b1;        // reset input fifo, done with block or blocks
                          done_opcode_block();       // Begin response
                        end
                        else begin
                          status_o <= `SUCCESS;  
                          state <= `STATE_IDLE;
                        end
                    end
                    else if(opcode == `RESET) begin
                        reset_opcode_processor();
                    end
                    else begin
                        if(opcode > `STATUS)    // STATUS opc always shows STATUS as last otherwise...
                            dbg_opcodes_o[7:0] <= {1'b0, opcode};
                      // Reset response already sent flag
                        blk_rsp_done <= 1'b0;   // flag, response is required
                        // Gather opcode data payload, then run it
                        // Most opcodes will use the same code here, (integer args) just different number of bytes.
                        if(opcode == `CALPTBL || opcode == `CALZMON) begin
                            // CALPTBL has 502 bytes as arg, CALZMON has 24 bytes
                            opcodes_byte_arg();                 // CALPTBL, other special opcodes                        
                        end
                        else begin                              // Opcode with integer argument
                            opcodes_integer_arg();              // common opcodes
                        end 
                    end
                end
                `STATE_FIFO_WRITE:
                begin
                  frq_wr_en_o <= 0;   // All off until next opcode ready
                  pwr_wr_en_o <= 0;
                  pulse_wr_en_o <= 0;
                  next_opcode();
                end

                // Saved pattern entry to pattern RAM, increment address, back to idle
                `STATE_WR_PTN: begin
                    if(ptn_latch_count == 0) begin
                        ptn_clk <= ptn_clk + 1;     // increment tick(offset) 
                        ptn_wen_o <= 1'b0;          // end write pulse 
                        next_opcode();
                    end
                    else
                        ptn_latch_count = ptn_latch_count - 1;
                end

                // Clearing section of pattern RAM, when done, back to idle
                `STATE_CLR_PTN1: begin
                    if(shift == 32'h0000_0005)
                        ptn_rst_n_o <= 1'b1;        // un-assert pattern reset                        
                    else if(shift == 32'h0000_0000)
                        state <= `STATE_CLR_PTN2;   // a few clocks to make sure pattern processor gets into PTN_CLEAR state
                    shift <= shift - 32'h0000_0001;
                end
                `STATE_CLR_PTN2: begin
                    if(ptn_status_i == `SUCCESS) begin      // pattern processor status, SUCCESS when done clearing RAM section
                        //ptn_cmd_o <= `OPCODE_NORMAL;
                        ptn_data_reg <= 0;
                        ptn_count <= 8'h00;                 // cleared RAM
                        next_opcode();
                    end
                end

                default:
                begin
                    status_o = `ERR_INVALID_STATE;
                    rsp_length <= 0;    // DEFAULT_RESPONSE_LENGTH gets added
                    state <= `STATE_BEGIN_RESPONSE;
                end
                endcase;    // main state machine case
            end // if((state=IDLE & at least 1 opcode)
        end // if(enable == 1) block
    end // always block    

    // start running pattern
    task start_pattern;
    input [15:0] address;    
    begin
        ptn_addr <= address;                // address
        if(ptn_count > 8'h00)               // don't run if nothing loaded
            operating_mode <= `PTNCMD_RUN;  // Opcode processor mode to run pattern data as soon as opcode processor is idle
    end
    endtask

    // stop a pattern
    task stop_pattern;
    begin
        ptn_run_o <= 1'b0;              // stop pattern
        ptn_fifo_ren_o <= 1'b0;
        operating_mode <= `OPCODE_NORMAL;
        // change to 1-tick signal   extrigg <= 1'b0;                // reset for next external trigger detection                 
    end
    endtask

    task done_opcode_block;
    begin
        // Normal, successful end of opcode block
        // already done fifo_rd_en_o <= 0;   // Disable read fifo
        state <= `STATE_BEGIN_RESPONSE;
    end
    endtask

    //
    // Most opcodes run here
    //
    task opcodes_integer_arg;
    begin
        // common processsing...
        // These common opcodes can be either executed immediately or 
        // saved into pattern RAM if operating_mode is PTNCMD_LOAD.
        if(length == 0) begin   // got all the data, write to correct fifo based on opcode, or execute opcode
            case(opcode)
            `CONFIG: begin
                // byte 2, d0=1 for VGA high gain mode, 0 for default low gain mode
                config_o <= uinttmp[31:0];              // various config bits
                next_opcode();   
            end
            `STATUS:  begin
                // return system status, 1st 4 bytes are standard, opcode status, last opcode, 2 length bytes.
                // For status opcode, length = 26 bytes defined so far(9/21/2017):
                // VERSION V.vv.r, 2 bytes
                // opcodes processed, 4 bytes
                // opcode processor status
                // opcode processor state
                // first opcode executed
                // last opcode executed
                // patadr count, how many patterns have been written
                // opcode fifo count, 2 bytes
                // measurement results available count, 2 bytes
                // frequency, 4 bytes
                // power, 2 bytes, dBm on Q7.8 format
                // pattern processor status
                // pattern index(address being run), 2 bytes
                // SYN_STAT
                // pad byte for even number
                if(response_fifo_full_i) begin
                    status_o <= `ERR_RSP_FIFO_FULL;
                    state <= `STATE_BEGIN_RESPONSE;
                end
                else begin
                    case(rsp_index)
                    0: begin
                        rsp_data[rsp_index] <= version[7:0];
                        rsp_index <= rsp_index + 1; 
                    end
                    1: begin
                        rsp_data[rsp_index] <= version[15:8];
                        rsp_index <= rsp_index + 1; 
                    end
                    2: begin
                        rsp_data[rsp_index] <= opcode_counter_o[7:0];   // opcodes processed, 4 bytes
                        rsp_index <= rsp_index + 1; 
                    end
                    3: begin
                        rsp_data[rsp_index] <= opcode_counter_o[15:8];
                        rsp_index <= rsp_index + 1; 
                    end
                    4: begin
                        rsp_data[rsp_index] <= opcode_counter_o[23:16];
                        rsp_index <= rsp_index + 1; 
                    end
                    5: begin
                        rsp_data[rsp_index] <= opcode_counter_o[31:24];
                        rsp_index <= rsp_index + 1; 
                    end
                    6: begin
                        rsp_data[rsp_index] <= status_o;                // opcode processor status
                        rsp_index <= rsp_index + 1; 
                    end
                    7: begin
                        rsp_data[rsp_index] <= state;                   // opcode processor state
                        rsp_index <= rsp_index + 1; 
                    end
                    8: begin
                        rsp_data[rsp_index] <= {1'b0, dbg_opcodes_o[14:8]}; // first opcode executed
                        rsp_index <= rsp_index + 1; 
                    end
                    9: begin
                        rsp_data[rsp_index] <= dbg_opcodes_o[7:0];          // last opcode executed
                        rsp_index <= rsp_index + 1; 
                    end
                    10: begin
                        rsp_data[rsp_index] <= dbg_opcodes_o[23:16];        // patadr count, how many patterns have been written
                        rsp_index <= rsp_index + 1; 
                    end
                    11: begin
                        rsp_data[rsp_index] <= fifo_rd_count_i[7:0];        // opcode fifo count, 2 bytes
                        rsp_index <= rsp_index + 1; 
                    end
                    12: begin
                        rsp_data[rsp_index] <= {6'd0, fifo_rd_count_i[10:8]};       
                        rsp_index <= rsp_index + 1; 
                    end
                    13: begin
                        rsp_data[rsp_index] <= meas_fifo_cnt_i[8:1];  // Divide by 2, 2 entries=one measurement set. response_fifo_count_i[7:0];  // measurement results available count, 2 bytes. Was opcode response fifo count, 2 bytes
                        rsp_index <= rsp_index + 1; 
                    end
                    14: begin
                        rsp_data[rsp_index] <= {5'd0, meas_fifo_cnt_i[PTN_FILL_BITS-1:9]}; //response_fifo_count_i[10:8]}; // measurement results available count, ms byte. Was opcode response fifo count, 2 bytes       
                        rsp_index <= rsp_index + 1; 
                    end
                    15: begin
                        rsp_data[rsp_index] <= frequency_o[7:0];       // frequency, 4 bytes
                        rsp_index <= rsp_index + 1; 
                    end
                    16: begin
                        rsp_data[rsp_index] <= frequency_o[12:8];
                        rsp_index <= rsp_index + 1; 
                    end
                    17: begin
                        rsp_data[rsp_index] <= frequency_o[23:16];
                        rsp_index <= rsp_index + 1; 
                    end
                    18: begin
                        rsp_data[rsp_index] <= frequency_o[31:24];
                        rsp_index <= rsp_index + 1; 
                    end
                    19: begin
                        rsp_data[rsp_index] <= dbm_x10_i[7:0];              // power, 2 bytes, dBm x10
                        rsp_index <= rsp_index + 1; 
                    end
                    20: begin
                        rsp_data[rsp_index] <= {4'd0, dbm_x10_i[11:8]};
                        rsp_index <= rsp_index + 1; 
                    end
                    21: begin
                        rsp_data[rsp_index] <= ptn_status_i;                // pattern processor status
                        rsp_index <= rsp_index + 1; 
                    end
                    22: begin
                        rsp_data[rsp_index] <= ptn_index_i[7:0];            // pattern index(address being run), 2 bytes
                        rsp_index <= rsp_index + 1; 
                    end
                    23: begin
                        rsp_data[rsp_index] <= ptn_index_i[12:8];
                        rsp_index <= rsp_index + 1; 
                    end
                    24: begin
                        rsp_data[rsp_index] <= {7'd0, syn_stat_i};          // SYN_STAT, 1 if PLL locked
                        rsp_index <= rsp_index + 1; 
                    end
                    25:    begin
                        rsp_data[rsp_index] <= 8'd0;                        // pad to even # of bytes
                        rsp_index <= rsp_index + 1; 
                        rsp_length <= rsp_index + 2;
                        opcode_counter_o <= opcode_counter_o + 32'd1;
                        state <= `STATE_BEGIN_RESPONSE;
                    end
                    endcase
                end
            end
            `FREQ: begin
                if(operating_mode == `PTNCMD_LOAD) begin // Write pattern mode
                    // 12 bytes, 3 bytes patClk tick, 1 byte opcode, 8 bytes for left-justified opcode data
                    ptn_data_reg <= {ptn_clk, 1'b0, opcode, uinttmp};
                    ptn_wen_o <= 1'b1;  // Write the entry 
                    state <= `STATE_WR_PTN;
                end
                else begin
                    frequency_o <= uinttmp[31:0];
                    frq_wr_en_o <= 1;   // enable write frequency FIFO
                    // Don't process anymore opcodes until fifo is written (1-tick)
                    state <= `STATE_FIFO_WRITE;
                end
            end
            `POWER: begin
                if(operating_mode == `PTNCMD_LOAD) begin // Write pattern mode
                    // 12 bytes, 3 bytes patClk tick, 1 byte opcode, 8 bytes of opcode data
                    ptn_data_reg <= {ptn_clk, 1'b0, opcode, uinttmp};
                    ptn_wen_o <= 1'b1;  // Write the entry 
                    state <= `STATE_WR_PTN;
                end
                else begin
                    power_o <= {opcode[6:0], uinttmp[31:0]};
                    pwr_wr_en_o <= 1;   // enable write power FIFO
                    // Don't process anymore opcodes until fifo is written
                    state <= `STATE_FIFO_WRITE;
                end
            end
            `CALPWR: begin  // power processor handles both user power requests and power cal commands
                if(operating_mode == `PTNCMD_LOAD) begin // Write pattern mode
                    // 12 bytes, 3 bytes patClk tick, 1 byte opcode, 8 bytes of opcode data
                    ptn_data_reg <= {ptn_clk, 1'b0, opcode, uinttmp};
                    ptn_wen_o <= 1'b1;  // Write the entry 
                    state <= `STATE_WR_PTN;
                end
                else begin
                    power_o <= {opcode[6:0], uinttmp[31:0]};
                    pwr_wr_en_o <= 1;   // enable write power FIFO
                    // Don't process anymore opcodes until fifo is written
                    state <= `STATE_FIFO_WRITE;
                end
            end
            `PULSE: begin
                if(operating_mode == `PTNCMD_LOAD) begin // Write pattern mode
                    // 12 bytes, 3 bytes patClk tick, 1 byte opcode, 8 bytes of opcode data
                    ptn_data_reg <= {ptn_clk, 1'b0, opcode, uinttmp};
                    ptn_wen_o <= 1'b1;  // Write the entry 
                    state <= `STATE_WR_PTN;
                end
                else begin
                    pulse_o <= uinttmp[63:0];
                    pulse_wr_en_o <= 1;   // enable write ulse FIFO
                    state <= `STATE_FIFO_WRITE;                                    
                end
            end
            `BIAS: begin
                if(operating_mode == `PTNCMD_LOAD) begin // Write pattern mode
                    // 12 bytes, 3 bytes patClk tick, 1 byte opcode, 8 bytes of opcode data
                    ptn_data_reg <= {ptn_clk, 1'b0, opcode, uinttmp};
                    ptn_wen_o <= 1'b1;  // Write the entry 
                    state <= `STATE_WR_PTN;
                end
                else begin
                    bias_enable_o <= uinttmp[8];  // ls byte is channel, always 1 for S4. Lsb of next byte is On/Off
                    next_opcode();
                end
            end
            `MODE: begin
                if(operating_mode == `PTNCMD_LOAD) begin // Write pattern mode
                    // 12 bytes, 3 bytes patClk tick, 1 byte opcode, 8 bytes of opcode data
                    ptn_data_reg <= {ptn_clk, 1'b0, opcode, uinttmp};
                    ptn_wen_o <= 1'b1;  // Write the entry 
                    state <= `STATE_WR_PTN;
                end
                else begin
                    mode_o <= uinttmp[31:0];    // Flags are set, next opcode
                    next_opcode();
                end
            end
            `TRIGCONF: begin
                trig_conf <= uinttmp[31:0];
                // Trigger bits are in 2nd byte:
                //TRIG_ARM         = 8'h80;    // Arm trigger
                //TRIG_ABORT       = 8'h40;    // Abort triggering
                //TRIG_NOW         = 8'h20;    // Run pattern now
                //TRIG_CONTINUOUS  = 8'h10;    // Continuous mode, every N ms, N was user-programmed
                //TRIG_SOURCE      = 8'h04;    // This box is trigger source
                //TRIG_EXTERN      = 8'h02;    // This box is trigger slave
                //TRIG_ENABLE      = 8'h01;    // Enable triggering
                //
                // For trigger now, MCU already sent pat_ctl[ADDR] which starts pattern                     
                if(uinttmp[12] == 1'b1 && uinttmp[8] == 1'b1) begin
                    trig_ms <= 9'd0;        // reset continuous trigger ms counter
                    trig_counter <= 18'd0;  // reset continuous trigger tick counter
                end
                if(uinttmp[`TRGBIT_EXT == 1'b0])
                    extrigg <= 1'b0;   // reset this sucker, gets stuck??
                next_opcode();
            end
            `SYNCCONF: begin
                sync_conf <= uinttmp[15:0];
                next_opcode();
            end
    //                        `PAINTFCFG:
    //                            begin
    //                            end
            `PTN_PATADR: begin
                operating_mode <= `PTNCMD_LOAD;     // Write pattern mode
                ptn_addr <= uinttmp[15:0];          // address
                ptn_clk <= 24'd0;                   // reset, use as offset to load entries
                ptn_count <= ptn_count + 8'h01;     // total PTN_PATADR opcodes written(total patterns loaded)
                dbg_opcodes_o[23:16] <= ptn_count + 8'h01;     // total PTN_PATADR opcodes written(total patterns loaded)
                next_opcode(); 
            end
            `PTN_PATCLK: begin
                ptn_clk <= uinttmp[23:0];
                next_opcode();   
            end
            `PTN_BRANCH: begin
                if(operating_mode == `PTNCMD_LOAD) begin  // Write pattern mode
                // save opcode in pattern RAM
                    // 12 bytes, 3 bytes patclk tick, 1 byte opcode, 8 bytes for opcode data (uinttmp)
                    ptn_data_reg <= {ptn_clk, 1'b0, opcode, uinttmp};
                    ptn_wen_o <= 1'b1; 
                    state <= `STATE_WR_PTN;
                end
                else
                    // pattern processor handles PTN_BRANCH, opcode processor does nothing in run mod
                    next_opcode();                     
            end
            `PTN_PATCTL: begin
                case(uinttmp[7:0])
                `PTN_END: begin                   // end of pattern writing or running
                    if(operating_mode == `PTNCMD_LOAD) begin  // Write pattern mode, end of pattern
                    // save opcode in pattern RAM
                        // 12 bytes, 3 bytes patclk tick, 1 byte opcode, 8 bytes for opcode data (uinttmp)
                        ptn_data_reg <= {ptn_clk, 1'b0, opcode, uinttmp};
                        ptn_wen_o <= 1'b1; 
                        state <= `STATE_WR_PTN;
                        operating_mode <= `OPCODE_NORMAL;     // Done writing pattern
                    end
                    else begin
                        stop_pattern();
                        next_opcode(); 
                    end
                end
                `PTN_RUN: begin
                    ptn_addr <= uinttmp[31:16]; // save for ccontinuous trigger mode
                    start_pattern(uinttmp[31:16]);
                    next_opcode(); 
                end
                `PTN_ABORT: begin
                    stop_pattern();
                    next_opcode(); 
                end
                `PTN_RST: begin
//                  31-Jan-2018 just clear the whole thing, fw writes all ptns at once anyway
//                    // clear the space between pat_addr & the address specified in the arg
//                    // use pat_addr & ptn_data_reg, set ptn_cmd_o so pattern module clears RAM
//                    ptn_data_reg <= { 80'h0000_0000_0000_0000_0000, uinttmp[31:16] };
//                    ptn_cmd_o <= `PTNCMD_CLEAR;

                    // Turn triggers OFF
                    trig_conf[15:8] <= 8'h00;
                    ptn_rst_n_o <= 1'b0;        // assert pattern reset
                    shift <= 32'h0000_0005;     // wait a few clocks so pattern processor status is PTN_CLEAR
                    state <= `STATE_CLR_PTN1;   // wait for pattern processor to finish RAM reset
                end
                endcase
            end
            `MEAS_ZMSIZE: begin
                status_o <= `ERR_OPC_NOT_SUPPORTED;
                rsp_length <= 0;
                state <= `STATE_BEGIN_RESPONSE;
            end
            `MEAS_ZMCTL: begin
                status_o <= `ERR_OPC_NOT_SUPPORTED;
                rsp_length <= 0;
                state <= `STATE_BEGIN_RESPONSE;
            end            
            `MEAS:  begin
                // return measurements, 1st 4 bytes are standard, opcode status, last opcode, 2 length bytes.
                // args: byte 0 is operations, bitmask,
                // d3 = dBm
                // d2 =	Volts
                // d1 = Adc counts
                // d0 = Calibrated
                //
                // byte 1: unused
                // byte 2: LSB, # of measurements requested
                // byte 3: MSB, # of measurements requested
                // each measurement is initially 8 bytes:
                // 16 bits FWDI, 16 bits FWDQ, 16 bits REFLI, 16 bits REFLQ
                // (I is real component, Q is imaginary component)
                // Process as needed & write response fifo
                //
                // Returned size depends on format, each result is returned as:
                // d1, Adc counts, 8 bytes, 4 signed 16-bit ints
                // d2, Volts, 16 bytes, 4 Q15.16 values
                // d3, dBm, 4 bytes, 2 Q7.8 values
                //
                if(uinttmp[3:1] == 3'd0) begin
                    status_o <= `ERR_MEAS_TYPE;
                    rsp_length <= 0;
                    state <= `STATE_BEGIN_RESPONSE;
                end
                else begin 
                    meas_ops <= uinttmp[7:0];   // save this
                    //
                    // if more data available than can be sent at once
                    // including the 4 bytes of rsp header, cut down the length
                    //
                    // if requested more than there is, extra values will be all 0
                    //
                    if(uinttmp[1]) begin        // ADC readings, 8 bytes per reading, 4 signed 16-bit integers
                        if({uinttmp[28:16], 3'b000} > ((1 << MMC_FILL_LEVEL_BITS)-8)) 
                        //if( ({1'd0, meas_fifo_cnt_i, 2'b00}) > ((1 << MMC_FILL_LEVEL_BITS)-8))
                            rsp_length <= ((1 << MMC_FILL_LEVEL_BITS) - 8);
                        else
                            rsp_length <= {uinttmp[28:16], 3'b000};  // requested measurements times 8 bytes per
                    end
                    else if(uinttmp[2]) begin   // voltage, 16 bytes per reading, Q15.16
                        if( {uinttmp[27:16], 4'b0000} > ((1 << MMC_FILL_LEVEL_BITS)-16))
                        //if( ({meas_fifo_cnt_i, 3'b000}) > ((1 << MMC_FILL_LEVEL_BITS)-16))
                            rsp_length <= ((1 << MMC_FILL_LEVEL_BITS) - 16);
                        else
                            rsp_length <= {uinttmp[27:16], 4'b0000}; // requested measurements times 16 bytes per
                    end
                    else if(uinttmp[3]) begin   // Power, 4 bytes per reading, Q7.8, same as raw meas fifo count
                        if({uinttmp[29:16], 2'b00}  > ((1 << MMC_FILL_LEVEL_BITS)-4))
                        //if( ({2'd0, meas_fifo_cnt_i, 1'b0}) > ((1 << MMC_FILL_LEVEL_BITS)-4))
                            rsp_length <= ((1 << MMC_FILL_LEVEL_BITS) - 4);
                        else
                            rsp_length <= {uinttmp[29:16], 2'b00};   // dBm, requested measurements times 4 bytes per
                    end
                    rsp_source <= MEAS_FIFO;
                    state <= `STATE_BEGIN_RESPONSE;                
                end
            end
            default: begin
                status_o <= `ERR_INVALID_OPCODE;
                rsp_length <= 0;
                state <= `STATE_BEGIN_RESPONSE;
            end
            endcase
        end // if(length == 0) block
        else begin  // integer argument, 2 to 8 bytes in length
            uinttmp <= uinttmp | (fifo_dat_i << shift);
            if(length == 2)             // Turn OFF with 2 clocks left. 1=last read, 0=begin write fifo
                fifo_rd_en_o <= 0;      // pause opcode fifo reads
            length <= length - 1;
            shift <= shift + 8'd8;
        end
    end
    endtask

    task opcodes_byte_arg;
    begin
        // argument data is a block of bytes, save the data as needed
        case(opcode)
        // For power cal;, write the frequency opcode to set frequency, then
        // write cal data block to update the frequency table.
        // pwr_calidx_o is reset at beginning of each CALPTBL opcode
        `CALPTBL: begin
            case(pwrcal_mode)
            PWRCAL1: begin
                pwr_calidx_o <= 12'd0;                              // reset
                pwr_calibrate_o <= 1'b0;
                pwr_caldata <= {4'd0, fifo_dat_i};                  // 8 lsb's
                pwrcal_mode <= PWRCAL2;
            end
            PWRCAL2: begin
                pwr_caldata <= {fifo_dat_i[3:0], pwr_caldata[7:0]}; // 4 msb's
                pwr_calibrate_o <= 1'b1;
                pwrcal_mode <= PWRCAL3;
            end
            PWRCAL3: begin
                pwr_calibrate_o <= 1'b0;                
                pwr_caldata <= {4'd0, fifo_dat_i};                  // 8 lsb's
                pwr_calidx_o <= pwr_calidx_o + 1;
                if(pwr_calidx_o < `PWR_TBL_ENTRIES) begin        
                    pwrcal_mode <= PWRCAL2;
                end
                else begin
                    pwrcal_mode <= PWRCAL1;
                    next_opcode();
                end
            end
            endcase
            if(length == 2)             // Turn OFF with 2 clocks left. 1=last read, 0=begin write fifo
                fifo_rd_en_o <= 0;      // pause opcode fifo reads
            length <= length - 1;
        end
        `CALZMON: begin
            // stash these bytes in the response buffer as temporary storage.
            if(length == 0) begin
                // got all the data, update in-use registers
                zm_fi_gain     <= {rsp_data[3], rsp_data[2], rsp_data[1], rsp_data[0]};
                zm_fi_offset   <= {rsp_data[5], rsp_data[4]};
                zm_fq_gain     <= {rsp_data[9], rsp_data[8], rsp_data[7], rsp_data[6]};
                zm_fq_offset   <= {rsp_data[11], rsp_data[10]};
                zm_ri_gain     <= {rsp_data[15], rsp_data[14], rsp_data[13], rsp_data[12]};
                zm_ri_offset   <= {rsp_data[17], rsp_data[16]};
                zm_rq_gain     <= {rsp_data[21], rsp_data[20], rsp_data[19], rsp_data[18]};
                zm_rq_offset   <= {rsp_data[23], rsp_data[22]};
                next_opcode();
            end
            else begin
                rsp_data[24-length] <= fifo_dat_i;
                if(length == 2)             // Turn OFF with 2 clocks left. 1=last read
                    fifo_rd_en_o <= 0;      // pause opcode fifo reads
                length <= length - 1;
            end
        end
        default: begin
            status_o <= `ERR_INVALID_OPCODE;
            rsp_length <= 0;
            state <= `STATE_BEGIN_RESPONSE;
        end
        endcase
    end
    endtask

    task reset_opcode_processor;
    begin
        opcode <= 0;
        dbg_opcodes_o <= 32'h0000_0000;   
        len_upr <= 0;
        length <= 9'b000000000;
        bytes_processed <= 32'h0000_0000;
        fifo_rd_en_o <= 1'b0;  // Added by John Clayton
        frq_wr_en_o <= 1'b0;
        pwr_wr_en_o <= 1'b0;
        pulse_wr_en_o <= 1'b0;
        opcode_counter_o <= 32'h0000_0000;
        uinttmp <= 64'h0000_0000_0000_0000;
        response_wr_en_o <= 1'b0;
        trig_conf <= 32'h0000_0000;
        status_o <= `SUCCESS;
        state <= `STATE_IDLE;
        next_state <= `STATE_IDLE;
        last_state <= `STATE_IDLE;
        blk_rsp_done <= 1'b0;               // Ready
        operating_mode <= `OPCODE_NORMAL;
        ptn_addr <= 16'h0000;               // pattern address to write
        ptn_clk <= 24'h00_0000;             // pattern clock tick to write, also used to clear RAM section
        ptn_run_o <= 1'b0;                  // Stop pattern processor 
        ptn_count <= 8'h00;                 // total patadr opcodes received(debugging only)
        ptn_cmd_o <= `OPCODE_NORMAL;        // was initially used to clear sections of pattern RAM. No longer used for this(30-Jan-2018). Other cmds not used yet
        ptn_wen_o <= 1'b0;
        ptn_fifo_ren_o <= 1'b0;
        ptn_data_reg <= 0;                

        pwr_caldata <= 12'd0;
        pwr_calidx_o <= 12'd0;
        pwr_calibrate_o <= 1'b0;
        pwrcal_mode <= PWRCAL1;
        
        response_ready <= 1'b0;
        response_length <= 16'h0000;
        rsp_index <= 16'h0000;
        rsp_length <= 0; // payload length, DEFAULT_RESPONSE_LENGTH gets added in
        rsp_source <= GENERAL_ARR;
        meas_fifo_ren_o <= 1'b0;                        
        mode_o <= 32'h0000_0000;
        bias_enable_o <= 1'b0;
        fifo_rst_o <= 1'b0;

        run_calcs <= 1'b0;
        meas_ops <= 1'b0;        
        
        zm_fi_gain <= 32'h0001_0000;      // zmon fwd "I" ADC gain, Q15.16 float
        zm_fi_offset <= 16'd0;            // zmon fwd "I" ADC offset, signed int
        zm_fq_gain <= 32'h0001_0000;      // zmon fwd "Q" ADC gain, Q15.16 float
        zm_fq_offset <= 16'd0;            // zmon fwd "Q" ADC offset, signed int
        
        zm_ri_gain <= 32'h0001_0000;      // zmon refl "I" ADC gain, Q15.16 float
        zm_ri_offset <= 16'd0;            // zmon refl "I" ADC offset, signed int
        zm_rq_gain <= 32'h0001_0000;      // zmon refl "Q" ADC gain, Q15.16 float
        zm_rq_offset <= 16'd0;            // zmon refl "Q" ADC offset, signed int
        
        config_o <= 32'h0000_0001;        // defauly VGA hi gain mode, control only VGA DAC B, ZMonEn OFF
        extrigg <= 1'b0;                  // external trigger latch, detect rising edge
        ptn_rst_n_o <= 1'b1;              // pattern reset from PTN_CTL[RESET] opcode
    end
    endtask

    // Start processing opcodes, doesn't return to idle until
    // a null opcode is seen.
    task begin_opcodes;
    begin
        fifo_rd_en_o <= 1;
        status_o <= 0;   // 0 is busy, undefined
        opcode <= 0;
        len_upr <= 0;
        length <= 9'b000000000;
        uinttmp <= 64'h0000_0000_0000_0000;
        
        frq_wr_en_o <= 1'b0;
        pwr_wr_en_o <= 1'b0;
        pulse_wr_en_o <= 1'b0;
        init_response();
        ptn_latch_count <= 8'd0;

        pwr_calibrate_o <= 1'b0;
        pwrcal_mode <= PWRCAL1;
    end
    endtask

    task init_response;
    begin
        response_wr_en_o <= 1'b0;
        response_ready <= 1'b0;
        response_length <= 16'h0000;
        rsp_index <= 16'h0000;
        rsp_length <= 0; // payload length, DEFAULT_RESPONSE_LENGTH gets added in
        rsp_source <= GENERAL_ARR;
        meas_fifo_ren_o <= 1'b0;
    end
    endtask

    // finished an opcode, back to idle state
    task next_opcode;
    begin
        state <= `STATE_IDLE;
        opcode_counter_o <= opcode_counter_o + 32'd1;
        ptn_latch_count <= 8'd0;
    end
    endtask

    // test for unrecognized opcode, back to idle state on bad opcode
    function bad_opcode;
    input [6:0] opcode;    
    begin
        if((opcode > `CALZMON && opcode < `PTN_PATCLK) ||
           (opcode > `PTN_BRANCH && opcode < `MEAS_ZMSIZE) ||
           (opcode > `MEAS)) begin 
            bad_opcode = 1'b1;
        end
        else bad_opcode = 1'b0;
    end
    endfunction

    // Concurrent assignments
    assign response_ready_o     = (response_ready && response_length == response_fifo_count_i);
    assign response_length_o    = response_length;
    assign state_o              = state; // For debugger
    assign ptn_data_o           = ptn_data_reg;    
    assign ptn_addr_o           = ptn_addr;
    assign pwr_caldata_o        = pwr_caldata;
    assign trig_conf_o          = trig_conf;

endmodule
