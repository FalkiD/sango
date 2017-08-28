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
//////////////////////////////////////////////////////////////////////////////////

`include "timescale.v"
`include "status.h"
`include "opcodes.h"

`define STATE_IDLE                  7'h01
`define STATE_FETCH_FIRST           7'h02   // 1 extra clock after assert rd_en   
`define STATE_FETCH                 7'h03
`define STATE_LENGTH                7'h04
`define STATE_DATA                  7'h05
//`define STATE_SAVE_DATA             7'h06
`define STATE_WAIT_DATA             7'h07   // Waiting for more fifo data
`define STATE_READ_SPACER           7'h08
`define STATE_FIFO_WRITE            7'h09
`define STATE_BEGIN_RESPONSE        7'h0c
`define STATE_WRITE_LENGTH1         7'h0d
`define STATE_WRITE_LENGTH2         7'h0e
`define STATE_RSP_OPCODE            7'h0f
`define STATE_WRITE_RESPONSE        7'h10
`define STATE_WR_PTN                7'h11
//`define STATE_WR_PTN2               7'h12
`define STATE_WMD                   7'h13
`define STATE_RD_MEAS1              7'h14
`define STATE_RD_MEAS2              7'h15
`define STATE_RD_MEAS3              7'h16
`define STATE_RD_MEAS4              7'h17
`define STATE_DBG3                  7'h18

/*
    Opcode block MUST be terminated by a NULL opcode
    Later: Fix this requirement, opcode processor must sit & wait 
    for next byte. MMC clock and this module's SYS_CLK are different. 
    Normal to wait for next byte.
*/
module opcodes #(parameter MMC_FILL_LEVEL_BITS = 16,
                 parameter RSP_FILL_LEVEL_BITS = 10,
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

    output reg  [63:0] pulse_o,                   // to fifo, pulse opcode
    output reg         pulse_wr_en_o,             // pulse fifo write enable

    input  wire [31:0] meas_fifo_dat_i,           // measurement fifo from pulse opcode
    output reg         meas_fifo_ren_o,           // measurement fifo read enable
    input  wire [MMC_FILL_LEVEL_BITS-1:0] meas_fifo_cnt_i, // measurements in fifo after pulse/pattern

    output reg         bias_enable_o,             // bias control

    // pattern opcodes are saved in pattern RAM.
    output reg                      ptn_wen_o,    // opcode processor saves pattern opcodes to pattern RAM 
    output wire [PTN_FILL_BITS-1:0] ptn_addr_o,   // address 
    output wire [PTN_WR_WORD-1:0]   ptn_data_o,   // 12 bytes, 3 bytes patClk tick, 9 bytes for opcode and its data   
    input  wire [PTN_RD_WORD-1:0]   ptn_data_i,   // next pattern opcode to run, 0 if nothing to do   
    input  wire [PTN_FILL_BITS-1:0] ptn_index_i,  // address of pattern entry to run(only run it once, address is unique in RAM) 
    output reg                      ptn_run_o,    // run pattern 
    input  wire [7:0]               ptn_status_i, // pattern processor status

    output reg  [31:0]   opcode_counter_o,        // count opcodes for status info                     
    output reg  [7:0]    status_o,                // NULL opcode terminates, done=0, or error code
    output wire [6:0]    state_o,                 // For debugger display
    
    // Debugging
    output reg  [23:0]   dbg_opcodes_o,           // patadr count in 8 MSB's, 1st opcode in 8 MID's, last opcode in 8 LSB's

    // STATUS command
    input  wire          syn_stat_i,              // SYN STAT pin, 1=PLL locked
    input  wire [11:0]   dbm_x10_i                // dBm x10, system power level    
    );

    reg  [3:0]   operating_mode = `OPCODE_NORMAL; // 0=normal, process & run opcodes, other cmds for pattern load/run
    reg  [6:0]   state = `STATE_IDLE;             // Use as flag in hardware to indicate first starting up
    reg  [6:0]   next_state = `STATE_IDLE;
    reg  [6:0]   last_state = `STATE_IDLE;
    reg          blk_rsp_done;       // flag, 1 sent response for block, 0=response not sent yet
    reg  [6:0]   opcode = 0;         // Opcode being processed
    reg  [9:0]   length = 0;         // bytes of opcode data to read
    reg  [63:0]  uinttmp;            // temp for opcode data, up to 8 bytes
    reg          len_upr = 0;        // Persist upper bit of length
    reg          response_ready;     // flag when response ready
    reg  [MMC_FILL_LEVEL_BITS-1:0]  response_length;    // length of response data
    reg  [MMC_FILL_LEVEL_BITS-1:0]  rsp_length;         // length tmp var
    reg  [7:0]   rsp_data [`STATUS_RESPONSE_SIZE-1:0];  // 22 byte array of response bytes (echo, status)
    reg  [MMC_FILL_LEVEL_BITS-1:0]  rsp_index;          // response array index
    localparam GENERAL_ARR  = 2'b00;
    localparam MEAS_FIFO    = 2'b01;
    reg  [1:0]                      rsp_source;         // 0=general array, 1=measurement fifo

    // Pattern data registers
    reg  [PTN_FILL_BITS-1:0]        ptn_addr;           // pattern address to write
    reg  [PTN_FILL_BITS-1:0]        ptn_index_done;     // index of pattern opcode just run(only run it once)
    reg  [23:0]                     ptn_clk;            // pattern clock tick to write
    reg  [PTN_WR_WORD-1:0]          ptn_data_reg;       // pattern data written to pattern RAM
    reg  [7:0]                      ptn_latch_count;    // Clocks to latch data into RAM
    reg  [7:0]                      ptn_count;
    reg  [7:0]                      saved_opc_byte;     // Save opcode byte in case of write to pattern RAM

    reg  [31:0]  trig_conf;          // trigger configuration, from trig_conf opcode
    reg  [15:0]  sync_conf;          // sync configuration, from sync_conf opcode
    
    // handle opcode integer argument data in a common way
    reg  [31:0]  shift = 0;          // tmp used building opcode data and returning measurements
    
    wire         pulse_busy;
    wire         pwr_busy;
    wire         frq_busy;

    // flag for each opcode, argument data is a block of bytes(1) or an integer(0)
    // Xilinx Verilog is MS data 1st, LS data last. Opcode 0 will be last entry
    // So far only PTN_DATA and ECHO use a block of bytes as arg data
    reg arg_is_bytes [127:0] = 
    {1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0,
     1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0,
     1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 
     1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 
     1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 
     1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 
     1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 
     1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0};    
//   0..., DBG_READREG, DBG_MBWSPI, DBG_MSYNSPI, DBG_RSYNSPI, DBG_DDSSPI, DBG_FLASHSPI, DBG_IQDATA, DBG_IQSPI, DBG_IQCTRL, DBG_OPCTRL, DBG_LEVELSPI, DBG_ATTENSPI
//   0..., MEAS_ZMCTL, MEAS_ZMSIZE
//   0,0,0,0,0,0,0,0,0,0,0,0, PTN_DATA, PTN_PATCTL, PTN_PATADR, PTN_PATCLK
//   0, 0, 0, ECHO, PAINTFCFG, SYNCCONF, TRIGCONF, LENGTH, MODE, BIAS, PULSE, PHASE, POWER, FREQ, STATUS, TERMINATOR

    always @( posedge sys_clk) begin
        if(!sys_rst_n) begin
            reset_opcode_processor();
        end
        else if(enable == 1) begin

            // check for pattern data first when running a pattern
            if(operating_mode == `PTNCMD_RUN  &&
                (ptn_data_i != `PTNDATA_NONE && ptn_index_i != ptn_index_done)) begin
                if(ptn_status_i > `SUCCESS) begin
                    // there's a problem, stop the pattern
                    stop_pattern();
                    status_o <= ptn_status_i;
                end
                else begin
                    // execute the next pattern opcode:
                    // --set opcode, length, and uinttmp registers
                    // --set state to STATE_DATA, continue.
                    // this jumps into normal opcode processing
                    opcode <= ptn_data_i[70:64];
                    length <= 0;                        // jump into processing uinttmp
                    uinttmp <= ptn_data_i[63:0];
                    ptn_index_done <= ptn_index_i;      // only run it once
                    state <= `STATE_DATA;               // process the parsed opcode
                end
            end
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
                
                // Opcode block done, write response fifo: status, pad byte, 
                // 2 length bytes, then data if any, then assert response_ready
                `STATE_BEGIN_RESPONSE: begin
                    if(rsp_length == 0) begin  // not using general array, get measurement results
                        rsp_length <= (meas_fifo_cnt_i << 2);   // 4 bytes per word
                        response_length <= (meas_fifo_cnt_i << 2) + `DEFAULT_RESPONSE_LENGTH;  // add room for status byte
                        rsp_source <= MEAS_FIFO;
                    end
                    else begin
                        response_length <= rsp_length + `DEFAULT_RESPONSE_LENGTH;  // add room for status byte
                        rsp_source <= GENERAL_ARR;
                    end
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
                    response_o <= {1'b0, opcode};
                    state <= `STATE_WRITE_LENGTH1;
                end
                `STATE_WRITE_LENGTH1: begin  // LS byte of data length
                    response_o <= rsp_length[7:0];
                    state <= `STATE_WRITE_LENGTH2;
                end
                `STATE_WRITE_LENGTH2: begin      // MS byte of status always 0 for now
                    response_o <= 8'h6c;         // (rsp_length>>8) & 8'hff;
                    state <= `STATE_WRITE_RESPONSE;
                end
                `STATE_WRITE_RESPONSE: begin
                    // this messes up the MMC core??? fifo_rst_o <= 1'b0;             // clear input fifo reset line after a few clocks
                    if(rsp_length > 0) begin
                        if(rsp_source == MEAS_FIFO && rsp_length == (meas_fifo_cnt_i<<2)) begin
                            response_wr_en_o <= 1'b0;       // Off while we read fifo
                            meas_fifo_ren_o <= 1'b1;        // start reading measurement fifo                        
                            uinttmp[31:0] <= 32'd0;
                            state <= `STATE_RD_MEAS1;
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
//                `STATE_RD_MEAS1: begin
//                    state <= `STATE_RD_MEAS2;   // read fifo spacer
//                end
                `STATE_RD_MEAS1: begin
                    uinttmp <= {32'd0, meas_fifo_dat_i};
                    response_wr_en_o <= 1'b0;               // don't write extra response byte after meas word
                    meas_fifo_ren_o <= 1'b0;
                    state <= `STATE_RD_MEAS2;
                end
                `STATE_RD_MEAS2: begin
                    rsp_length <= rsp_length - 1;
                    rsp_index <= rsp_index + 1;

                    // write response byte
                    response_wr_en_o <= 1'b1;
                    response_o <= uinttmp[7:0];

                    // prep next byte
                    if(((rsp_index+1) & 2'b11) == 2'b0 &&
                            rsp_length > 1) begin
                        meas_fifo_ren_o <= 1'b1;                // read next result
                        state <= `STATE_RD_MEAS1;
                    end
                    else
                        uinttmp <= {8'h00, uinttmp[31:8]};

                    // Done?
                    if(rsp_length == 0) begin
                        response_wr_en_o <= 1'b0;
                        response_ready <= 1'b1;
                        state <= `STATE_IDLE;
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
                    shift <= 8'h00;
                    uinttmp <= 64'h0000_0000_0000_0000;
                    length <= {1'b0, fifo_dat_i};
                    // **** 02-Aug if 0 length then turn OFF read NOW
                    if({1'b0, fifo_dat_i} > (fifo_rd_count_i-1) || fifo_dat_i == 8'h00)
                        fifo_rd_en_o <= 0;                    // must turn OFF REN 1 clock early
                    state <= `STATE_LENGTH;   // Part 1 of length, get length msb & get opcode next
                end
                `STATE_LENGTH: begin
                    saved_opc_byte <= fifo_dat_i[6:0];      // Save opcode byte in case of write to pattern RAM
                    length <= {fifo_dat_i[0], length[7:0]};
                    rsp_index <= 16'h0000;                  // index for multi-byte data blocks
                    opcode <= fifo_dat_i[7:1];              // got opcode, start reading data
                    // length tests
                    if({fifo_dat_i[0], length[7:0]} > (fifo_rd_count_i-1)) begin
                        fifo_rd_en_o <= 0;                  // let it fill
                        state <= `STATE_WAIT_DATA;
                    end
                    else begin
                        if({fifo_dat_i[0], length[7:0]} == 0) begin
                            fifo_rd_en_o <= 0;              // don't read next byte, opcode has no data
                        end
                        state <= `STATE_DATA;
                    end
                end
                `STATE_WAIT_DATA: begin // Wait for asynch FIFO to receive all our data
                    if(fifo_rd_count_i >= length) begin
                        fifo_rd_en_o <= 1;                  // start reading again
                        state <= `STATE_READ_SPACER;
                    end
                end
                `STATE_READ_SPACER: begin
                    state <= `STATE_DATA;
                end
                `STATE_DATA: begin
                    if(dbg_opcodes_o[14:8] == 7'b0000000)
                        dbg_opcodes_o[14:8] <= opcode;
                    // Look for special opcodes, RESET & NULL Terminator
                    // On NULL, check for response data available. If measurement data is in the fifo
                    // send it. Make sure the pulse & pattern processors are idle(done) first.
                    if(opcode == 0) begin
                        state <= `STATE_WMD;    // Check for measurement done before doing response
                    end
                    else if(opcode == `RESET) begin
                        reset_opcode_processor();
                    end
                    else begin
                        dbg_opcodes_o[7:0] <= {1'b0, opcode};
                      // Reset response already sent flag
                        blk_rsp_done <= 1'b0;   // flag, response is required
                        // Gather opcode data payload, then run it
                        // Most opcodes will use the same code here, (integer args) just different number of bytes.
                        if(!arg_is_bytes[opcode[6:0]]) begin    // Opcode with integer argument
                            opcodes_integer_arg();              // common opcodes
                        end
                        else begin  // if(arg_is_bytes[opcode[6:0]]) 
                            opcodes_byte_arg();                 // ECHO, other special opcodes
                        end
                    end
                end
                `STATE_WMD: begin
                  // Got null opcode, done.
                  // Wait Measurement Delay, wait until pulse processor and
                  // pattern processor are not busy (all measurements are done)
                  if(pulse_busy_i == 1'b0) begin // need cmds while ptn runs   && ptn_status_i != 8'h00) begin
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
        ptn_addr <= address;            // address
        ptn_index_done <= 0;            // keep track of which we've run(only run it once)
        ptn_run_o <= 1'b1;              // run pattern
        operating_mode <= `PTNCMD_RUN;  // Opcode processor mode to run pattern data
    end
    endtask

    // stop a pattern
    task stop_pattern;
    begin
        ptn_run_o <= 1'b0;              // stop pattern
        ptn_index_done <= 0;            // keep track of which we've run(only run each entry once)
        operating_mode <= `OPCODE_NORMAL; 
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
            `STATUS:  begin
                // return system status, 1st 4 bytes are standard, opcode status, last opcode, 2 length bytes.
                // For status opcode, length = 20 bytes defined so far:
                // opcodes processed, 4 bytes
                // opcode processor status
                // opcode processor state
                // first opcode executed
                // last opcode executed
                // patadr count, how many patterns have been written
                // opcode fifo count, 2 bytes
                // opcode response fifo count, 2 bytes
                // frequency, 4 bytes
                // power, 2 bytes, dBm on Q7.8 format
                // pattern processor status
                // SYN_STAT
                if(response_fifo_full_i) begin
                    status_o <= `ERR_RSP_FIFO_FULL;
                    state <= `STATE_BEGIN_RESPONSE;
                end
                else begin
                    case(rsp_index)
                    0:   begin
                        rsp_data[rsp_index] <= opcode_counter_o[7:0];   // opcodes processed, 4 bytes
                        rsp_index <= rsp_index + 1; 
                    end
                    1:   begin
                        rsp_data[rsp_index] <= opcode_counter_o[15:8];
                        rsp_index <= rsp_index + 1; 
                    end
                    2:    begin
                        rsp_data[rsp_index] <= opcode_counter_o[23:16];
                        rsp_index <= rsp_index + 1; 
                    end
                    3:    begin
                        rsp_data[rsp_index] <= opcode_counter_o[31:24];
                        rsp_index <= rsp_index + 1; 
                    end
                    4:    begin
                        rsp_data[rsp_index] <= status_o;                // opcode processor status
                        rsp_index <= rsp_index + 1; 
                    end
                    5:    begin
                        rsp_data[rsp_index] <= state;                   // opcode processor state
                        rsp_index <= rsp_index + 1; 
                    end
                    6:    begin
                        rsp_data[rsp_index] <= {1'b0, dbg_opcodes_o[14:8]}; // first opcode executed
                        rsp_index <= rsp_index + 1; 
                    end
                    7:    begin
                        rsp_data[rsp_index] <= dbg_opcodes_o[7:0];          // last opcode executed
                        rsp_index <= rsp_index + 1; 
                    end
                    8:    begin
                        rsp_data[rsp_index] <= dbg_opcodes_o[23:16];        // patadr count, how many patterns have been written
                        rsp_index <= rsp_index + 1; 
                    end
                    9:    begin
                        rsp_data[rsp_index] <= fifo_rd_count_i[7:0];        // opcode fifo count, 2 bytes
                        rsp_index <= rsp_index + 1; 
                    end
                    10:   begin
                        rsp_data[rsp_index] <= {3'd0, fifo_rd_count_i[12:8]};       
                        rsp_index <= rsp_index + 1; 
                    end
                    11:    begin
                        rsp_data[rsp_index] <= response_fifo_count_i[7:0];  // opcode response fifo count, 2 bytes
                        rsp_index <= rsp_index + 1; 
                    end
                    12:    begin
                        rsp_data[rsp_index] <= {3'd0, response_fifo_count_i[12:8]};       
                        rsp_index <= rsp_index + 1; 
                    end
                    13:    begin
                        rsp_data[rsp_index] <= frequency_o[7:0];       // frequency, 4 bytes
                        rsp_index <= rsp_index + 1; 
                    end
                    14:    begin
                        rsp_data[rsp_index] <= frequency_o[12:8];
                        rsp_index <= rsp_index + 1; 
                    end
                    15:    begin
                        rsp_data[rsp_index] <= frequency_o[23:16];
                        rsp_index <= rsp_index + 1; 
                    end
                    16:    begin
                        rsp_data[rsp_index] <= frequency_o[31:24];
                        rsp_index <= rsp_index + 1; 
                    end
                    17:    begin
                        rsp_data[rsp_index] <= dbm_x10_i[7:0];              // power, 2 bytes, dBm x10
                        rsp_index <= rsp_index + 1; 
                    end
                    18:    begin
                        rsp_data[rsp_index] <= {4'd0, dbm_x10_i[11:8]};
                        rsp_index <= rsp_index + 1; 
                    end
                    19:    begin
                        rsp_data[rsp_index] <= ptn_status_i;                // pattern processor status
                        rsp_index <= rsp_index + 1; 
                    end
                    20:    begin
                        rsp_data[rsp_index] <= {7'd0, syn_stat_i};          // SYN_STAT, 1 if PLL locked
                        rsp_index <= rsp_index + 1; 
                    end
                    21:    begin
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
                    ptn_data_reg <= {ptn_clk, 1'b0, saved_opc_byte[7:1], uinttmp};
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
                    ptn_data_reg <= {ptn_clk, 1'b0, saved_opc_byte[7:1], uinttmp};
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
                    ptn_data_reg <= {ptn_clk, 1'b0, saved_opc_byte[7:1], uinttmp};
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
                    ptn_data_reg <= {ptn_clk, 1'b0, saved_opc_byte[7:1], uinttmp};
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
                    ptn_data_reg <= {ptn_clk, 1'b0, saved_opc_byte[7:1], uinttmp};
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
                    ptn_data_reg <= {ptn_clk, 1'b0, saved_opc_byte[7:1], uinttmp};
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
            `PTN_PATCTL: begin
                case(uinttmp[7:0])
                `PTN_END: begin                   // end of pattern writing or running
                    if(operating_mode == `PTNCMD_LOAD) begin  // Write pattern mode, end of pattern
                    // save opcode in pattern RAM
                        // 12 bytes, 3 bytes patclk tick, 1 byte opcode, 8 bytes for opcode data (uinttmp)
                        ptn_data_reg <= {ptn_clk, 1'b0, saved_opc_byte[7:1], uinttmp};
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
                    start_pattern(uinttmp[31:16]);
                    next_opcode(); 
                end
                `PTN_ABORT: begin
                    stop_pattern();
                    next_opcode(); 
                end
                endcase
            end
            `MEAS:  begin
//                // return measurements, 1st 4 bytes are standard, opcode status, last opcode, 2 length bytes.
//                if(response_fifo_full_i) begin
//                    status_o <= `ERR_RSP_FIFO_FULL;
//                    state <= `STATE_BEGIN_RESPONSE;
//                end
//                else begin
//                    case(rsp_index)
//                    0:   begin
//                        rsp_data[rsp_index] <= opcode_counter_o[7:0];   // opcodes processed, 4 bytes
//                        rsp_index <= rsp_index + 1; 
//                    end
//                    1:   begin
//                        rsp_data[rsp_index] <= opcode_counter_o[15:8];
//                        rsp_index <= rsp_index + 1; 
//                    end


//                    2:    begin
//                        rsp_data[rsp_index] <= {7'd0, syn_stat_i};          // SYN_STAT, 1 if PLL locked
//                        rsp_index <= rsp_index + 1; 
//                    end
//                    3:    begin
//                        rsp_data[rsp_index] <= 8'd0;                        // pad to even # of bytes
//                        rsp_index <= rsp_index + 1; 
                        rsp_length <= 0;
//                        opcode_counter_o <= opcode_counter_o + 32'd1;
                        state <= `STATE_BEGIN_RESPONSE;
//                    end
//                    endcase
//                end
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
        // argument data is a block of bytes, save it
        // Normally pattern data, can be debug or echo opcodes
        // Pattern data is not valid when a pattern is running (opcodes w/integer args are valid)
//        if(system_state_i & `STATE_PTN_BUSY) begin
//            status_o <= `ERR_PATTERN_RUNNING;
//            state <= `STATE_BEGIN_RESPONSE;
//        end
//        else begin
            case(opcode)
            `ECHO: begin
                if(response_fifo_full_i) begin
                    status_o <= `ERR_RSP_FIFO_FULL;
                    state <= `STATE_BEGIN_RESPONSE;
                end
                else if(!fifo_rd_empty_i) begin
                    rsp_data[rsp_index] <= ~fifo_dat_i; // complement the data for echo test 
//                    if(length == 2) begin               // 1-based counter. Turn OFF FIFO early
//                        length <= length - 1;
//                        fifo_rd_en_o <= 0;                   // turn off reading
//                        rsp_length <= rsp_index + 1;    // 0-based index
//                    end
                    if(length == 1) begin
                        fifo_rd_en_o <= 0;              // turn off reading
                        status_o <= `SUCCESS;
                        rsp_length <= rsp_index + 1;    // 0-based index
                        // this might belong in a task such as next_opcode...
                        if(mode_o[31] == 1'b0)
                            opcode_counter_o <= opcode_counter_o + 32'd1;
                        state <= `STATE_BEGIN_RESPONSE;
                    end
                    else begin
                        length <= length - 1;
                        rsp_index <= rsp_index + 1;
                    end
                end
            end
            endcase
//        end    
    end
    endtask

    task reset_opcode_processor;
    begin
        opcode <= 0;
        dbg_opcodes_o <= 24'h00_0000;   
        len_upr <= 0;
        length <= 9'b000000000;
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
        ptn_clk <= 24'h00_0000;             // pattern clock tick to write
        ptn_run_o <= 1'b0;                  // Stop pattern processor 
        ptn_index_done <= 0;                // keep track of which we've run(only run it once)
        ptn_count <= 8'h00;                 // total patadr opcodes received(debugging only)
        ptn_wen_o <= 1'b0;

        response_ready <= 1'b0;
        response_length <= 16'h0000;
        rsp_index <= 16'h0000;
        rsp_length <= 0; // payload length, DEFAULT_RESPONSE_LENGTH gets added in
        rsp_source <= GENERAL_ARR;
        meas_fifo_ren_o <= 1'b0;                        
        mode_o <= 32'h0000_0000;
        bias_enable_o <= 1'b0;
        fifo_rst_o <= 1'b0;
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
        response_wr_en_o <= 1'b0;
        response_ready <= 1'b0;
        response_length <= 16'h0000;
        rsp_index <= 16'h0000;
        rsp_length <= 0; // payload length, DEFAULT_RESPONSE_LENGTH gets added in
        rsp_source <= GENERAL_ARR;
        meas_fifo_ren_o <= 1'b0;
        ptn_latch_count <= 8'd0;
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

    // Concurrent assignments
    assign response_ready_o     = (response_ready && response_length == response_fifo_count_i);
    assign response_length_o    = response_length;
    assign state_o              = state; // For debugger
    assign ptn_data_o           = ptn_data_reg;    
    assign ptn_addr_o           = ptn_addr;

endmodule
