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

`define BUF_WIDTH 9
`define BUF_SIZE ( 1<<`BUF_WIDTH )

`define STATE_IDLE                  7'h01
`define STATE_FETCH_FIRST           7'h02   // 1 extra clock after assert rd_en   
`define STATE_FETCH                 7'h03
`define STATE_LENGTH                7'h04
`define STATE_DATA                  7'h05
`define STATE_WAIT_DATA             7'h06   // Waiting for more fifo data
`define STATE_READ_SPACER           7'h07
`define STATE_FIFO_WRITE            7'h08
`define STATE_BEGIN_RESPONSE        7'h09
`define STATE_WRITE_LENGTH1         7'h0c
`define STATE_WRITE_LENGTH2         7'h0d
`define STATE_RSP_OPCODE            7'h0e
`define STATE_WRITE_RESPONSE        7'h0f
`define STATE_WR_PTN1               7'h10
`define STATE_WR_PTN2               7'h11
`define STATE_DBG_DELAY             7'h12
`define STATE_EMPTY_FIFO            7'h13

// If the input fifo has incomplete data, wait this many ticks 
// before clearing it (so we never get stuck in odd state)
`define WAIT_FIFO_TMO              1000

// Max fetch attempts with FIFO empty ON
//`define MAX_FETCH_ATTEMPTS          8'd50

// Write pattern mode versus normal (execute immediately) mode
`define NORMAL_PROCESSOR            1'b0
`define WRITE_PATTERN               1'b1

/*
    Opcode block MUST be terminated by a NULL opcode
    Later: Fix this requirement, opcode processor must sit & wait 
    for next byte. MMC clock and this module's SYS_CLK are different. 
    Normal to wait for next byte.
*/
module opcodes #(parameter MMC_FILL_LEVEL_BITS = 16,
                 parameter RSP_FILL_LEVEL_BITS = 10,
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

    output reg  [7:0]    response_o,              // to fifo, response bytes(status, measurements, echo, etc)
    output reg           response_wr_en_o,        // response fifo write enable
    input  wire          response_fifo_empty_i,   // response fifo empty flag
    input  wire          response_fifo_full_i,    // response fifo full flag
    output wire          response_ready_o,        // response is waiting
    output wire [RSP_FILL_LEVEL_BITS-1:0] response_length_o,     // update response length when response is ready
    input  wire [RSP_FILL_LEVEL_BITS-1:0] response_fifo_count_i, // response fifo count, response_ready when fifo_length==response_length

    output reg  [31:0] frequency_o,               // to fifo, frequency output in MHz
    output reg         frq_wr_en_o,               // frequency fifo write enable
    input              frq_fifo_empty_i,          // frequency fifo empty flag
    input              frq_fifo_full_i,           // frequency fifo full flag

    output reg  [38:0] power_o,                   // to fifo, power output in dBm
    output reg         pwr_wr_en_o,               // power fifo write enable
//    input              pwr_fifo_empty_i,          // power fifo empty flag
//    input              pwr_fifo_full_i,           // power fifo full flag

//    output reg  [63:0] pulse_o,                 // to fifo, pulse opcode
//    output reg         pulse_wr_en_o,           // pulse fifo write enable
//    input              pulse_fifo_empty_i,      // pulse fifo empty flag
//    input              pulse_fifo_full_i,       // pulse fifo full flag

    output reg         bias_enable_o,             // bias control

    // pattern opcodes are saved in pattern RAM.
//    output reg         ptn_wr_en_o,             // opcode processor saves pattern opcodes to pattern RAM 
//    output reg  [15:0] ptn_addr_o,              // address 
//    output reg  [95:0] ptn_data_o,              // 12 bytes, 3 bytes patClk tick, 9 bytes for opcode, length, and data   
//    input       [95:0] ptn_data_i,              // 12 bytes, 3 bytes patClk tick, 9 bytes for opcode, length, and data   

//    output reg         ptn_processor_en_o,      // Run pattern processor 
//    output reg  [15:0] ptn_start_addr_o,        // address 

    output reg  [31:0] opcode_counter_o,        // count opcodes for status info                     
    output reg  [7:0]  status_o,                // NULL opcode terminates, done=0, or error code
    output wire [6:0]  state_o,                 // For debugger display
    
//    // Debugging
    output reg  [15:0]  dbg_opcodes_o           // 1st opcode in 8 MSB's, last opcode in 8 LSB's
//    output reg  [15:0] last_length_o
    );

`ifdef XILINX_SIMULATOR
    integer         fileopcode = 0;
    integer         filefreqs = 0;
    integer         filepwr = 0;
    integer         filepulse = 0;
    integer         filebias = 0;
    integer         fileopcerr = 0;
    integer         filepattern = 0;
    reg [7:0]       dbgdata;
    reg             dumpRAM;
`endif

    reg          operating_mode = 0; // 0=normal, process & run opcodes. 1=save pattern mode, write opcodes to pattern RAM
    reg  [6:0]   state = 0;          // Use as flag in hardware to indicate first starting up
    reg  [6:0]   next_state = `STATE_IDLE;
    reg  [6:0]   last_state = `STATE_IDLE;
    reg          blk_rsp_done;       // flag, 1 sent response for block, 0=response not sent yet
    reg  [6:0]   opcode = 0;         // Opcode being processed
    reg  [9:0]   length = 0;         // bytes of opcode data to read
    reg  [63:0]  uinttmp;            // up to 64-bit tmp for opcode data
    reg  [MMC_FILL_LEVEL_BITS-1:0]  read_cnt;   // Bytes read from input fifo. Go until matches SECTOR_SIZE
    reg          len_upr = 0;        // Persist upper bit of length
    reg          response_ready;     // flag when response ready
    reg  [RSP_FILL_LEVEL_BITS-1:0]  response_length;    // length of response data
    reg  [RSP_FILL_LEVEL_BITS-1:0]  rsp_length;         // length tmp var
    reg  [7:0]   rsp_data [15:0];    // 64k array of response bytes (measure, echo, status)
    reg  [RSP_FILL_LEVEL_BITS-1:0]  rsp_index;          // response array index
    //reg  [9:0]   opc_fifo_timeout;   // wait for input fifo to contain minimum data for this long before clearing it(so we never get stuck)

    reg  [15:0]  pat_addr;           // pattern address to write
    reg  [23:0]  pat_clk;            // pattern clock tick to write
    reg  [7:0]   ptn_latch_count;    // Clocks to latch data into RAM
    reg  [7:0]   saved_opc_byte;     // Save opcode byte in case of write to pattern RAM
    reg  [7:0]   saved_len_byte;     // Save opcode length byte in case of write to pattern RAM

    reg  [31:0]  trig_conf;          // trigger configuration, from trig_conf opcode
    reg  [15:0]  sync_conf;          // sync configuration, from sync_conf opcode
    
    // handle opcode integer argument data in a common way
    reg  [31:0]  shift = 0;              // tmp used building opcode data

    reg  [31:0]  counter;

    assign response_ready_o = (response_ready && response_length == response_fifo_count_i);
    assign response_length_o = response_length;
    assign state_o = state; // For debugger

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
        if( !sys_rst_n || state == 0) begin //|| (state != `STATE_IDLE && fifo_rd_empty_i == 1))
            reset_opcode_processor();
            counter <= 0;
    `ifdef XILINX_SIMULATOR
            dumpRAM <= 1'b0;
    `endif
        end
        else if(enable == 1) begin
            if((state == `STATE_IDLE && (fifo_rd_count_i >= `SECTOR_SIZE || read_cnt > 0)) || //`MIN_OPCODE_SIZE) ||
                state != `STATE_IDLE) begin
                // not IDLE or at least one opcode has been written to FIFO

                if(state == `STATE_IDLE && fifo_rd_count_i >= `SECTOR_SIZE) //    read_cnt == 0)
                  read_cnt <= fifo_rd_count_i;  // Reset our byte counter

                case(state)
                `STATE_IDLE: begin
                    // Don't continue until the response has been read(response fifo empty)
                    if(response_fifo_empty_i && !fifo_rd_empty_i) begin 
                        // Start processing opcodes, don't return to 
                        // `STATE_IDLE until a null opcode is seen.
                        begin_opcodes();
                        show_next_state(`STATE_FETCH_FIRST);
                    end
                end
    
                `STATE_DBG_DELAY: begin
                    // MSB of mode_o flag word slows way down for visual observation on Arty bd
                    //opcode_counter_o <= {25'b0_0000_0000, next_state};
                    if(counter == 0) begin
                        state <= next_state;
                    end
                    else
                        counter <= counter - 1;
                end
                
                // Opcode block done, write response fifo: status, pad byte, 
                // 2 length bytes, then data if any, then assert response_ready
                `STATE_BEGIN_RESPONSE: begin
                    response_length <= rsp_length + `DEFAULT_RESPONSE_LENGTH;  // add room for status byte & 0-padding byte
                    rsp_index <= 16'h0000;
                    // Status code is first 2 bytes, begin
                    if(status_o == 0) begin         // if status indicates busy(0), set 'SUCCESS
                        status_o <= `SUCCESS;       // Update status_o to SUCCESS
                        response_o <= `SUCCESS;     // SUCCESS into response fifo, done with opcode block
                    end
                    else
                        response_o <= status_o;
                    response_wr_en_o <= 1;
                    show_next_state(`STATE_RSP_OPCODE);
                end
                `STATE_RSP_OPCODE: begin  // opcode responding to
                    response_o <= {1'b0, opcode};
                    show_next_state(`STATE_WRITE_LENGTH1);
                end
                `STATE_WRITE_LENGTH1: begin  // LS byte of data length
                    response_o <= rsp_length[7:0];
                    show_next_state(`STATE_WRITE_LENGTH2);
                end
                `STATE_WRITE_LENGTH2: begin  // MS byte of status always 0 for now
                    response_o <= 8'h6c; //(rsp_length>>8) & 8'hff;
                    show_next_state(`STATE_WRITE_RESPONSE);
                end
                `STATE_WRITE_RESPONSE: begin
                    //fifo_rst_o <= 1'b0;             // clear input fifo reset line after a few clocks
                    if(rsp_length > 0) begin
                        response_o <= rsp_data[rsp_index];
                        rsp_length <= rsp_length - 1;
                        rsp_index <= rsp_index + 1;
                    end
                    else begin
                        response_wr_en_o <= 1'b0;
                        response_ready <= 1'b1;
                        show_next_state(`STATE_IDLE);
                        if(status_o == 0)
                            status_o <= `SUCCESS;       // Reset status_o if it's not set to an error
                    end
                end
    
    //            // Saving opcode to pattern RAM, end pulse, increment address, back to idle
    //            `STATE_WR_PTN1: begin
    //                ptn_wr_en_o <= 1'b1; 
    //                ptn_latch_count <= 0;
    //            ....        show_next_state(`STATE_IDLE);
    //                state <= `STATE_WR_PTN2;    
    //            end
    //            `STATE_WR_PTN2: begin
    //                if(ptn_latch_count == 0) begin
    //                    pat_addr <= pat_addr + 1;   // increment address 
    //                    ptn_wr_en_o <= 1'b0;        // end write pulse 
    //                    next_opcode();
    //                end
    //                else
    //                    ptn_latch_count = ptn_latch_count - 1;
    //            end
    
                // Just began from `STATE_IDLE
                `STATE_FETCH_FIRST: begin
                    show_next_state(`STATE_FETCH);  // extra tick to get reads going
                end
                `STATE_FETCH: begin
                    shift <= 8'h00;
                    uinttmp <= 64'h0000_0000_0000_0000;
                    length <= {1'b0, fifo_dat_i};
                    saved_len_byte <= {1'b0, fifo_dat_i};     // Save opcode length byte in case of write to pattern RAM
                    read_cnt <= read_cnt - 1;
                    show_next_state(`STATE_LENGTH);   // Part 1 of length, get length msb & get opcode next
                end
                `STATE_LENGTH: begin
                    saved_opc_byte <= fifo_dat_i[6:0];      // Save opcode byte in case of write to pattern RAM
                    length <= {fifo_dat_i[0], length[7:0]};
                    rsp_index <= 16'h0000;                  // index for multi-byte data blocks
                    opcode <= fifo_dat_i[7:1];              // got opcode, start reading data
                    read_cnt <= read_cnt - 1;
                    // length tests
                    if({fifo_dat_i[0], length[7:0]} > fifo_rd_count_i) begin
                        fifo_rd_en_o <= 0;                  // let it fill
                        show_next_state(`STATE_WAIT_DATA);
                    end
                    else begin
                        if({fifo_dat_i[0], length[7:0]} == 0) begin
                            fifo_rd_en_o <= 0;              // don't read next byte, opcode has no data
                        end
                        show_next_state(`STATE_DATA);
                    end
                `ifdef XILINX_SIMULATOR
                    if(fileopcode == 0)
                        fileopcode = $fopen("./opc_from_fifo.txt", "a");
                    $fdisplay (fileopcode, "%02h, length:%d", (fifo_dat_i & 8'hFE) >> 1, length);
                `endif
                end
                `STATE_WAIT_DATA: begin // Wait for asynch FIFO to receive all our data
                    if(fifo_rd_count_i >= length) begin
                        fifo_rd_en_o <= 1;                  // start reading again
                        show_next_state(`STATE_READ_SPACER);
                    end
//                    else begin
//                      if(opc_fifo_timeout == 6'd0) begin
//                        fifo_rd_en_o <= 1;
//                        show_next_state(`STATE_EMPTY_FIFO);
//                      end
//                      opc_fifo_timeout <= opc_fifo_timeout - 10'd1;    
//                    end
                end
//                `STATE_EMPTY_FIFO: begin
//                    if(fifo_rd_count_i > 0) begin
//                      saved_opc_byte <= fifo_dat_i; // Just use register to dump fifo contents
//                    end
//                    else begin
//                      fifo_rd_en_o <= 0;            // back to idle
//                      status_o <= `SUCCESS;
//                      show_next_state(`STATE_IDLE);
//                    end
//                end
                `STATE_READ_SPACER: begin
                    show_next_state(`STATE_DATA);
                end
                `STATE_DATA: begin
                    if(dbg_opcodes_o[14:8] == 7'b0000000)
                        dbg_opcodes_o[14:8] <= opcode;
                    // Look for special opcodes, RESET & NULL Terminator
                    if(opcode == 0) begin
                        if(blk_rsp_done == 1'b0) begin
                          blk_rsp_done <= 1'b1;      // Flag we've done it
                          //fifo_rst_o <= 1'b1;       // reset input fifo, done with block
                          done_opcode_block();                    
                        end
                        else begin
                          status_o <= `SUCCESS;  
                          show_next_state(`STATE_IDLE);
                        end
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
                `STATE_FIFO_WRITE:
                begin
                  frq_wr_en_o <= 0;   // All off until next opcode ready
                  pwr_wr_en_o <= 0;
    //              pulse_wr_en_o <= 0;
                 `ifdef XILINX_SIMULATOR
                    fifo_empty_note();  // checks for fifo empty, logs it if so
                 `endif
                  next_opcode();
                end
                default:
                begin
                    status_o = `ERR_INVALID_STATE;
                    rsp_length <= 0;    // DEFAULT_RESPONSE_LENGTH gets added
                    show_next_state(`STATE_BEGIN_RESPONSE);
                end
                endcase;    // main state machine case
            end // if((state=IDLE & 1 sector of data) OT state <> IDLE
        end // if(enable == 1) block
    end // always block    

//    // start running pattern
//    task start_pattern;
//    input [15:0] address;    
//    begin
//        ptn_start_addr_o <= address;    // address 
//        ptn_processor_en_o <= 1'b1;     // run pattern processor
//    `ifdef XILINX_SIMULATOR
//        dumpRAM <= 1'b1;
//    `endif
//    end
//    endtask

//    // stop a pattern
//    task stop_pattern;
//    begin
//        ptn_processor_en_o <= 1'b0;     // stop pattern processor 
//    end
//    endtask

    task done_opcode_block;
    begin
        `ifdef XILINX_SIMULATOR
            $fdisplay (fileopcode, "Terminated on 0, count:%d", opcode_counter_o);
            $fclose(fileopcode);
            fileopcode = 0;
            $fclose(filefreqs);
            filefreqs = 0;
            $fclose(filepwr);
            filepwr = 0;
            $fclose(filepulse);
            filepulse = 0;
            $fclose(filebias);
            filebias = 0;
            $fclose(fileopcerr);
            fileopcerr = 0;
            $fclose(filepattern);
            filepattern = 0;
        `endif
        // Normal, successful end of opcode block
        // already done fifo_rd_en_o <= 0;   // Disable read fifo
        show_next_state(`STATE_BEGIN_RESPONSE);
    end
    endtask

`ifdef XILINX_SIMULATOR
    task fifo_empty_note;
    begin
        if(fifo_rd_empty_i) begin
            $fdisplay (fileopcode, "Done processing opcodes, count:%d", opcode_counter_o);
            $fclose(fileopcode);
            fileopcode = 0;
            $fclose(filefreqs);
            filefreqs = 0;
            $fclose(filepwr);
            filepwr = 0;
            $fclose(filepulse);
            filepulse = 0;
            $fclose(filebias);
            filebias = 0;
            $fclose(fileopcerr);
            fileopcerr = 0;
        end
    end
    endtask
`endif

    //
    // Most opcodes run here
    //
    task opcodes_integer_arg;
    begin
        // common processsing...
        // These common opcodes can be either executed immediately or 
        // saved into pattern RAM if operating_mode is 1'b1.
        //
        // need to refactor, handle writing pattern RAM generically, not per-opcode...
        //
        if(length == 0) begin   // got all the data, write to correct fifo based on opcode, or execute opcode
            case(opcode)
            `STATUS:  begin
            end
            `FREQ: begin
//                if(operating_mode == `WRITE_PATTERN) begin // Write pattern mode
//                    // save opcode in pattern RAM
//                    ptn_addr_o <= pat_addr; 
//                    // 12 bytes, 3 bytes patClk tick, 9 bytes for left-justified opcode data
//                    ptn_data_o <= (pat_clk << 72) | 
//                                    (saved_len_byte << 64) | 
//                                    (saved_opc_byte << 56) |
//                                    (uinttmp[31:0] << 24);
//                    state <= `STATE_WR_PTN1;
//                `ifdef XILINX_SIMULATOR
//                    if(filepattern == 0)
//                        filepattern = $fopen("./pattern_ram.txt", "a");
//                    $fdisplay (filepattern, "FREQ %d to pattern RAM", uinttmp[31:0]);
//                `endif
//                end
//                else begin
                    frequency_o <= uinttmp[31:0];
                    frq_wr_en_o <= 1;   // enable write frequency FIFO
                    // Don't process anymore opcodes until fifo is written (1-tick)
                    show_next_state(`STATE_FIFO_WRITE);
                `ifdef XILINX_SIMULATOR
                    if(filefreqs == 0)
                        filefreqs = $fopen("./opcode_freqs_to_fifo.txt", "a");
                    $fdisplay (filefreqs, "Wrote %d Hz to freq processor fifo", uinttmp[31:0]);
                `endif
//                end
            end
            `POWER: begin
//                if(operating_mode == `WRITE_PATTERN) begin // Write pattern mode
//                    // save opcode in pattern RAM
//                    ptn_addr_o <= pat_addr; 
//                    // 12 bytes, 3 bytes patClk tick, 9 bytes for left-justified opcode data
//                    ptn_data_o <= (pat_clk << 72) | 
//                                    (saved_len_byte << 64) | 
//                                    (saved_opc_byte << 56) |
//                                    (uinttmp[31:0] << 24);
//                    state <= `STATE_WR_PTN1;
//                `ifdef XILINX_SIMULATOR
//                    if(filepattern == 0)
//                        filepattern = $fopen("./pattern_ram.txt", "a");
//                    $fdisplay (filepattern, "POWER 0x%h to pattern RAM", uinttmp[31:0]);
//                `endif
//                end
//                else begin
                    power_o <= {opcode[6:0], uinttmp[31:0]};
                    pwr_wr_en_o <= 1;   // enable write power FIFO
                    // Don't process anymore opcodes until fifo is written
                    show_next_state(`STATE_FIFO_WRITE);

                `ifdef XILINX_SIMULATOR
                    if(filepwr == 0)
                        filepwr = $fopen("./opcode_pwr_to_fifo.txt", "a");
                    $fdisplay (filepwr, "Wrote 0x%h to power processor fifo", uinttmp[31:0]);
                `endif
//                end
            end
            `CALPWR: begin  // power processor handles both user power requests and power cal commands
              power_o <= {opcode[6:0], uinttmp[31:0]};
              pwr_wr_en_o <= 1;   // enable write power FIFO
              // Don't process anymore opcodes until fifo is written
              show_next_state(`STATE_FIFO_WRITE);
            `ifdef XILINX_SIMULATOR
              if(filepwr == 0)
                filepwr = $fopen("./opcode_pwr_to_fifo.txt", "a");
              $fdisplay (filepwr, "Wrote 0x%h (calpwr) to power processor fifo", uinttmp[31:0]);
            `endif
            end
//            `PULSE: begin
//                if(operating_mode == `WRITE_PATTERN) begin // Write pattern mode
//                // save opcode in pattern RAM
//                    ptn_addr_o <= pat_addr; 
//                    // 12 bytes, 3 bytes patClk tick, 9 bytes for left-justified opcode data
//                    ptn_data_o <= (pat_clk << 72) | 
//                                    (saved_len_byte << 64) | 
//                                    (saved_opc_byte << 56) |
//                                    uinttmp[55:0];
//                    show_next_state(`STATE_WR_PTN1);
//                   `ifdef XILINX_SIMULATOR
//                        if(filepattern == 0)
//                            filepattern = $fopen("./pattern_ram.txt", "a");
//                        $fdisplay (filepattern, "PULSE 0x%h to pattern RAM", uinttmp[63:0]);
//                   `endif
//                end
//                else begin
//                    pulse_o <= uinttmp[63:0];
//                    pulse_wr_en_o <= 1;   // enable write ulse FIFO
//                    // Don't process anymore opcodes until fifo is written
//                    show_next_state(`STATE_FIFO_WRITE);                                    
//                `ifdef XILINX_SIMULATOR
//                    if(filepulse == 0)
//                        filepulse = $fopen("./opcode_pulse_to_fifo.txt", "a");
//                    $fdisplay (filepulse, "Wrote 0x%h to pulse processor fifo", uinttmp[63:0]);
//                `endif
//                end
//            end
            `BIAS: begin
//                if(operating_mode == `WRITE_PATTERN) begin // Write pattern mode
//                    ptn_addr_o <= pat_addr; 
//                    // 12 bytes, 3 bytes patClk tick, 9 bytes for left-justified opcode data
//                    ptn_data_o <= (pat_clk << 72) | 
//                                    (saved_len_byte << 64) | 
//                                    (saved_opc_byte << 56) |
//                                    (uinttmp[15:0] << 40);
//                    show_next_state(`STATE_WR_PTN1);
//                `ifdef XILINX_SIMULATOR
//                    if(filepattern == 0)
//                        filepattern = $fopen("./pattern_ram.txt", "a");
//                    $fdisplay (filepattern, "BIAS 0x%h to pattern RAM", uinttmp[15:0]);
//                `endif
//                end
//                else begin
              bias_enable_o <= uinttmp[8];  // ls byte is channel, always 1 for S4. Lsb of next byte is On/Off
              next_opcode();
            `ifdef XILINX_SIMULATOR
              if(filebias == 0)
                filebias = $fopen("./opcode_bias_to_fifo.txt", "a");
                $fdisplay (filebias, "BiasEnable:%d", uinttmp[8]);
            `endif
//                end
            end
            `MODE: begin
                mode_o <= uinttmp[31:0];    // Flags are set, next opcode
                next_opcode();
           `ifdef XILINX_SIMULATOR
                if(fileopcode == 0)
                    fileopcode = $fopen("./opc_from_fifo.txt", "a");
                $fdisplay (fileopcode, "MODE=0x%h", uinttmp[31:0]);
           `endif
            end
            `TRIGCONF: begin
                trig_conf <= uinttmp[31:0];
                next_opcode();
           `ifdef XILINX_SIMULATOR
                if(fileopcode == 0)
                    fileopcode = $fopen("./opc_from_fifo.txt", "a");
                $fdisplay (fileopcode, "TRIG_CONF=0x%h", uinttmp[31:0]);
           `endif
            end
            `SYNCCONF: begin
                sync_conf <= uinttmp[15:0];
                next_opcode();
           `ifdef XILINX_SIMULATOR
                if(fileopcode == 0)
                    fileopcode = $fopen("./opc_from_fifo.txt", "a");
                $fdisplay (fileopcode, "SYNC_CONF=0x%h", uinttmp[15:0]);
           `endif
            end
    //                        `PAINTFCFG:
    //                            begin
    //                            end
//            `PTN_PATCLK: begin
//                pat_clk <= uinttmp[23:0];
//                next_opcode();   
//            end
//            `PTN_PATADR: begin
//                operating_mode <= 1'b1;         // Write pattern mode
//                pat_addr <= uinttmp[15:0];      // address
//                next_opcode(); 
//            end
//            `PTN_PATCTL: begin
//                case(uinttmp[7:0])
//                `PTN_END: begin                 // end of pattern writing
//                    if(operating_mode == `WRITE_PATTERN) begin // Write pattern mode
//                    // save opcode in pattern RAM
//                        ptn_addr_o <= pat_addr; 
//                        // 11 bytes, 3 bytes patClk tick, 8 bytes for left-jsutified opcode
//                        ptn_data_o <= (pat_clk << 72) | (`PTN_PATCTL << 56) | (uinttmp[31:0] << 40);   
//                        ptn_wr_en_o <= 1'b1; 
//                        show_next_state(`STATE_WR_PTN1);
//                        operating_mode <= 1'b0;     // Done writing pattern
//                   `ifdef XILINX_SIMULATOR
//                        if(filepattern == 0)
//                            filepattern = $fopen("./pattern_ram.txt", "a");
//                        $fdisplay (filepattern, "PAT_END 0x%h to pattern RAM", uinttmp[31:0]);
//                   `endif
//                    end
//                    else begin
//                        stop_pattern();
//                        next_opcode(); 
//                    end
//                end
//                `PTN_RUN: begin
//                    start_pattern(uinttmp[31:16]);
//                    next_opcode(); 
//                end
//                `PTN_ABORT: begin
//                    stop_pattern();
//                    next_opcode(); 
//                end
//                endcase
//            end
            default: begin
                status_o <= `ERR_INVALID_OPCODE;
                rsp_length <= 0;
                show_next_state(`STATE_BEGIN_RESPONSE);
            end
            endcase
        end // if(length == 0) block
        else begin  // integer argument, 2 to 8 bytes in length
            uinttmp <= uinttmp | (fifo_dat_i << shift);
            if(length == 2)             // Turn OFF with 2 clocks left. 1=last read, 0=begin write fifo
                fifo_rd_en_o <= 0;      // pause opcode fifo reads
            length <= length - 1;
            shift <= shift + 8'd8;
            read_cnt <= read_cnt - 1;
        end
    end
    endtask

    task opcodes_byte_arg;
    begin
        // argument data is a block of bytes, save it
        // Normally pattern data, can be debug or echo opcodes
        // Pattern data is not valid when a pattern is running (opcodes w/integer args are valid)
        if(system_state_i & `STATE_PTN_BUSY) begin
        `ifdef XILINX_SIMULATOR
            if(fileopcerr == 0)
                fileopcerr = $fopen("./opcode_status.txt", "a");
            $fdisplay (fileopcerr, "*ERROR*:Cannot write pattern data while pattern is running");
        `endif
            status_o <= `ERR_PATTERN_RUNNING;
            show_next_state(`STATE_BEGIN_RESPONSE);
        end
        else begin
            case(opcode)
            `ECHO: begin
                if(response_fifo_full_i) begin
                `ifdef XILINX_SIMULATOR
                    if(fileopcerr == 0)
                        fileopcerr = $fopen("./opcode_status.txt", "a");
                    $fdisplay (fileopcerr, "*ERROR*:Response fifo is full, ECHO can't write response");
                    $fclose(fileopcerr);
                    fileopcerr = 0;
                `endif
                    status_o <= `ERR_RSP_FIFO_FULL;
                    show_next_state(`STATE_BEGIN_RESPONSE);
                end
                else if(!fifo_rd_empty_i) begin
                    rsp_data[rsp_index] <= ~fifo_dat_i; // complement the data for echo test 
                    read_cnt <= read_cnt - 1;
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
                        show_next_state(`STATE_BEGIN_RESPONSE);
                    end
                    else begin
                        length <= length - 1;
                        rsp_index <= rsp_index + 1;
                    end
                end
            end
            endcase
        end    
    end
    endtask

    task reset_opcode_processor;
    begin
        opcode <= 0;
        dbg_opcodes_o <= 16'h0000;   
        len_upr <= 0;
        length <= 9'b000000000;
        fifo_rd_en_o <= 1'b0;  // Added by John Clayton
        read_cnt <= 0;         // Bytes read from input fifo. Go until matches SECTOR_SIZE
        frq_wr_en_o <= 1'b0;
        pwr_wr_en_o <= 1'b0;
//        pulse_wr_en_o <= 1'b0;
//        bias_wr_en_o <= 1'b0;
        opcode_counter_o <= 32'h0000_0000;
        uinttmp <= 64'h0000_0000_0000_0000;
        response_wr_en_o <= 1'b0;
        trig_conf <= 32'h0000_0000;
        status_o <= `SUCCESS;
        state <= `STATE_IDLE;
        next_state <= `STATE_IDLE;
        last_state <= `STATE_IDLE;
        blk_rsp_done <= 1'b0;       // Ready
        operating_mode <= 1'b0;
        pat_addr <= 16'h0000;               // pattern address to write
        pat_clk <= 24'h00_0000;             // pattern clock tick to write
//        ptn_start_addr_o <= 16'h0000;   // address 
//        ptn_processor_en_o <= 1'b0;         // Stop pattern processor 

        response_ready <= 1'b0;
        response_length <= 16'h0000;
        rsp_index <= 16'h0000;
        rsp_length <= 0; // payload length, DEFAULT_RESPONSE_LENGTH gets added in
        mode_o <= 32'h0000_0000;
        //opc_fifo_timeout <= `WAIT_FIFO_TMO;
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
    //                pulse_wr_en_o <= 1'b0;
        response_wr_en_o <= 1'b0;
        response_ready <= 1'b0;
        response_length <= 16'h0000;
        rsp_index <= 16'h0000;
        rsp_length <= 0; // payload length, DEFAULT_RESPONSE_LENGTH gets added in
        //opc_fifo_timeout <= `WAIT_FIFO_TMO;
    end
    endtask

    // If msb of mode word is set slow way down for observation on arty board
    task show_next_state;
        input [6:0] newstate;
    begin
        if(mode_o & 32'h8000_0000) begin
            next_state <= newstate;
            state <= `STATE_DBG_DELAY;
            counter <= TWOFIFTY_MS;
        end
        else begin
            state <= newstate;
        end
    end
    endtask

    // finished an opcode, back to idle state
    task next_opcode;
    begin
        show_next_state(`STATE_IDLE);
        // When not in slow debug mode, increment opcode counter
        if(mode_o[31] == 1'b0)
            opcode_counter_o <= opcode_counter_o + 32'd1;
    end
    endtask

endmodule
