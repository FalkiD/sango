//////////////////////////////////////////////////////////////////////////////////
// Company: Ampleon
// Engineer: Rick Rigby
// 
// Create Date: 07/17/2017
// Design Name: S4 power control module
// Module Name: power
// Project Name: 
// Target Devices: Artix-7, DAC7563
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments: Implement power calculations.
// 
//////////////////////////////////////////////////////////////////////////////////

`include "timescale.v"
`include "version.v"
`include "status.h"
`include "opcodes.h"

module power #(parameter FILL_BITS = 4)
(
  input  wire           sys_clk,
  input  wire           sys_rst_n,
    
  input  wire           power_en,

  // Power opcode(s) are in input fifo
  // Power opcode byte 0 is channel#, (only 1 channel for S4)
  // byte 1 unused, byte 2 is 8 lsb's,
  // byte 3 is 8 msb's of Q7.8 format power
  // in dBm. (Positive values only)
  // Upper 7 bits are opcode, user power or cal
  input  wire [38:0]    pwr_fifo_i,               // fifo data in
  output reg            pwr_fifo_ren_o,           // fifo read line
  input  wire           pwr_fifo_mt_i,            // fifo empty flag
  input  wire [FILL_BITS-1:0] pwr_fifo_count_i,         // fifo count

  // outputs, VGA SPI to DAC7563
  output wire           VGA_MOSI_o,
  output wire           VGA_SCLK_o,
  output reg            VGA_SSn_o,       
  output wire           VGA_VSW_o,       
  
  output reg [7:0]      status_o                  // 0=busy, SUCCESS when done, or an error code
);

  // Main Globals
  reg [6:0]       state = 0;
  reg [6:0]       next_state;         // saved while waiting for multiply/divide in FRQ_WAIT state

  reg [31:0]      power = 0;      
  reg [38:0]      pwr_word;           // whole 39 bit word
  reg [6:0]       pwr_opcode;         // which power opcode, user request or cal?
  // Latency for math operations, Xilinx multiplier & divrem divider have no reliable "done" line???
  localparam MULTIPLIER_CLOCKS = 4;
  localparam DIVIDER_CLOCKS = 42;
  reg [5:0]       latency_counter;    // wait for multiplier & divider 
  reg [3:0]       byte_idx;           // countdown when writing bytes to fifo

//    // Xilinx multiplier.
//    // A input is 56 bits. B input is 24 bits
//    // Output is 64 bits
//    reg [55:0] multA;                   // A multiplier input
//    reg [23:0] multB;                   // B multiplier input
//    wire [63:0] multiplier_result;      // Result
//    mult48 ddsMultiply (
//       .CLK(clk),
//       .A(multA),
//       .B(multB),
//       .CE(power_en),
//       .P(multiplier_result)
//     );      
    
//    // Instantiate simple division ip for division not
//    // requiring remainder.
//    // Use 32-bit divider to convert programmed frequency 
//    // in Hertz to MHz, other calculations for limits, etc
//    parameter WIDTH_FR = 32;
//    reg  [31:0] divisor;             // always 1MHz here
//    reg  [31:0] dividend;            // frequency in Hertz
//    wire [31:0] quotient;            // MHz
//    wire        divide_done;         // Division done
//    reg         div_enable;          // Divider enable
//    division #(WIDTH_FR) divnorem (
//        .enable(div_enable),
//        .A(dividend), 
//        .B(divisor), 
//        .result(quotient),
//        .done(divide_done)
//    );

//    /////////////////////////////////////////////////////////
//    // user-programmed power, power table, corresponding 
//    // magnitude table, etc.
//    /////////////////////////////////////////////////////////
//    reg [3:0]       channel;            // 1-16 minus 1
//    reg [15:0]      dbmx10;             // ((desired dBm - (40*256)) * 10) / 256 (xx.x dBm * 10, an integer)   
//    localparam      dbm_offset = 16'd400;   // Offset is 40dBm, after x10 is 400. Subtracted after >>8 
//    localparam      pwr_table_size = 8'd21;
//    // Note: array indexing reverse order from C
//    reg [7:0]       power_table [20:0] = {8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 
//                                            8'h0f, 8'h1e, 8'h2d, 8'h3c, 
//                                            8'h4b, 8'h5a, 8'h69, 8'h78,
//                                            8'h87, 8'h96, 8'ha5, 8'hb4, 
//                                            8'hc3, 8'hd2, 8'he1, 8'hf0  };
//    reg [5:0]       table_index;
//    reg [15:0]      mag_table [20:0] = { 16'h20, 16'h28, 16'h30, 16'h38,
//                                        16'h40, 16'h50, 16'h60, 16'h70, 16'h80,
//                                        16'ha0, 16'hc0, 16'he0, 16'h100,
//                                        16'h140, 16'h180, 16'h1c0, 16'h200,
//                                        16'h280, 16'h300, 16'h380, 16'h400 };
//    reg [7:0]       numerator;
//    reg [15:0]      denominator;
//    reg [15:0]      mag_step;
//    reg [15:0]      mag_data;       // interpolated mag_table value for hardware
//    localparam PWR_BYTES = 2;

  ////////////////////////////////////////
  // VGA SPI instance, SPI to DAC7563   //
  // SPI mode 1                         //
  ////////////////////////////////////////
  reg         spi_run = 0;
  reg  [7:0]  spi_write;
  wire [7:0]  spi_read;
  wire        spi_busy;         // 'each byte' busy
  wire        spi_done_byte;    // 1=done with a byte, data is valid
  spi #(.CLK_DIV(3)) vga_spi 
  (
    .clk(sys_clk),
    .rst(!sys_rst_n),
    .miso(),
    .mosi(VGA_MOSI_o),
    .sck(VGA_SCLK_o),
    .start(spi_run),
    .data_in(spi_write),
    .data_out(spi_read),
    .busy(spi_busy),
    .new_data(spi_done_byte)     // 1=signal, data_out is valid
  );
 
  /////////////////////////////////
  // Set Power state definitions //
  /////////////////////////////////
  localparam PWR_IDLE           = 0;
  localparam PWR_SPCR           = 1;
  localparam PWR_READ           = 2;
  localparam PWR_INTERNAL_DBM   = 3;   // ((user dBm - (40*256)) * 10) / 256 (xx.x dBm * 10, an integer)
  localparam PWR_VGA1           = 4;
  localparam PWR_VGA2           = 5;
  localparam PWR_VGA3           = 6;
  localparam PWR_VGA4           = 7;
  localparam PWR_VGA5           = 8;
  localparam PWR_INIT_LOOP      = 9;
  localparam PWR_LOOP_TOP       = 10;
  localparam PWR_MULT           = 11;
  localparam PWR_DIVIDE         = 12;
  localparam PWR_WAIT           = 13;
  localparam WAIT_SPI           = 14;
        
//    // done calculations, queuing data for SPI states
//    `define PWR_QUEUE               60
//    `define PWR_QUEUE_CMD           61

//    // Waiting for multiply/divide state, 7 bits available 
//    `define PWR_WAIT                127
//    ////////////////////////////////////////
//    // End of power state definitions //
//    ////////////////////////////////////////

//`ifdef XILINX_SIMULATOR
//    integer         filepwr = 0;
//`endif



// DAC7563 programming from M2
//static uint8_t InitializeDac() {

//	//	hidio 66 1 3 38 00 00
//	uint8_t dac_data[] = { 0x38, 0, 0 }; // Disable internal refs, Gain=1
//	uint8_t status = spiwrrd(SPI_DEV_ID_DAC, sizeof(dac_data), dac_data);

//	//	hidio 66 1 3 30 00 03
//	dac_data[0] = 0x30;	// LDAC pin inactive DAC A & B
//	dac_data[1] = 0;
//	dac_data[2] = 3;
//	status |= spiwrrd(SPI_DEV_ID_DAC, sizeof(dac_data), dac_data);

//	//	hidio 66 1 3 00 99 60
//	dac_data[0] = 0;		// DAC A input
//	dac_data[1] = 0x99;		// 0x996
//	dac_data[2] = 0x60;
//	status |= spiwrrd(SPI_DEV_ID_DAC, sizeof(dac_data), dac_data);

//	//	hidio 66 1 3 11 80 00
//	dac_data[0] = 0x11;		// Write DAC B input & update all DAC's
//	dac_data[1] = 0x80;		// 0x800
//	dac_data[2] = 0;
//	status |= spiwrrd(SPI_DEV_ID_DAC, sizeof(dac_data), dac_data);

//	return status;
//}


//// *** Set Power from M2:
//// Convert dB into dac value & send it
//// dB is relative to dac 0x80(128)
//static uint8_t SetSynthesizer(uint16_t db, uint16_t *pvmag) {
//	float value = (float)db/2000.0;
//	value = pow(10.0, value);
//	value = value * 128.0 + 0.5;
//	uint16_t vmag = (uint16_t)value + 0x800; //((pow(10.0, (db/20.0)) * (double)0x800) + 0.5);
//	*pvmag = vmag;
//	int16_t phase = 0x800; //GetPhase();
//#ifdef DEBUG
//	iprintf("dB:%04d, IDac:0x%03x, QDac:0x%03x\n", db, vmag, phase);
//#endif

//	// I(magnitude) is DAC A, Q(phase) is DAC B
//	uint8_t dac_data[3];
//	dac_data[0] = 0;		// DAC A input
//	dac_data[1] = (vmag>>4) & 0xff;
//	dac_data[2] = (vmag&0xf)<<4;
//	uint8_t status = spiwrrd(SPI_DEV_ID_DAC, sizeof(dac_data), dac_data);

//	dac_data[0] = 0x11;		// Write DAC B input & update all DAC's
//	dac_data[1] = (phase>>4) & 0xff;
//	dac_data[2] = (phase&0xf)<<4;
//	status |= spiwrrd(SPI_DEV_ID_DAC, sizeof(dac_data), dac_data);

//	return status;
//}

// DAC7563 uses SPI mode 1. As long as SSEL(SYNC) is low for 24 bits
// to be clocked in, the DAC will be updated on teh 24th falling 
// edge of SCLK

  always @( posedge sys_clk) begin
    if( !sys_rst_n ) begin
      state <= PWR_IDLE;
      next_state <= PWR_IDLE;
      pwr_fifo_ren_o <= 1'b0;
      power <= 32'h00000000;
      latency_counter <= 6'b000000; 
//      channel <= 4'b0000;
//      dbmx10 <= 16'h0000;   
//      table_index <= 6'b000000;
//      numerator <= 8'h00;
//      denominator <= 16'h0001;
//      mag_step <= 16'h0000;
//      mag_data <= 16'h0000;
      VGA_SSn_o <= 1'b1;
    end
    else if(power_en == 1) begin
      case(state)
        PWR_WAIT: begin
          if(latency_counter == 0)
            state <= next_state;
          else
            latency_counter <= latency_counter - 1;
        end
        PWR_IDLE: begin
          if(!pwr_fifo_mt_i) begin
            pwr_fifo_ren_o <= 1;
            state <= PWR_READ;
            status_o <= 1'b0;
          end
          else
            status_o <= `SUCCESS;
        end
        PWR_SPCR: begin
          state <= PWR_READ;
        end             
        PWR_READ: begin
          // read power from fifo
          pwr_word <= pwr_fifo_i;
          pwr_fifo_ren_o <= 1'b0;
          if(pwr_fifo_i[38:32] == `POWER) begin
            state <= PWR_INTERNAL_DBM;
          end
          else begin
            state <= PWR_VGA1;  // write 1st byte of 3
            VGA_SSn_o <= 1'b0;
          end
//        `ifdef XILINX_SIMULATOR
//          if(filepwr == 0)
//            filepwr = $fopen("../../../project_1.srcs/sources_1/pwr_in.txt", "a");
//        `endif
        end
        PWR_VGA1: begin
          power <= pwr_word[31:0];
          pwr_opcode <= pwr_word[38:32];
          state <= PWR_VGA2;
        end
        PWR_VGA2: begin    // 32 bit word has 24 bits of DAC data in 3 LS bytes
          // write 1st byte
          spi_write <= power[23:16];
          spi_run <= 1'b1;
          next_state <= PWR_VGA3;
          state <= WAIT_SPI;
        end
        PWR_VGA3: begin
          // 2nd byte
          spi_write <= power[15:8];
          spi_run <= 1'b1;
          next_state <= PWR_VGA4;
          state <= WAIT_SPI;
        end
        PWR_VGA4: begin
          // 3rd byte
          spi_write <= power[7:0];
          spi_run <= 1'b1;
          next_state <= PWR_VGA5;
          state <= WAIT_SPI;
        end
        PWR_VGA5: begin
          VGA_SSn_o <= 1'b1;
          spi_run <= 1'b0;
          state <= PWR_IDLE;
          status_o <= `SUCCESS;
        end
        WAIT_SPI: begin
          if(spi_done_byte == 1'b1) begin
            state <= next_state;
            spi_run <= 1'b0;
          end
        end
        PWR_INTERNAL_DBM: begin
          //dbmx10 <= (((pwr_tmp << 3) + (pwr_tmp << 1)) >> 8) - dbm_offset;    // Initial dbm * 10 / 256 - 400                
          state <= PWR_INIT_LOOP;
        end
//        PWR_INIT_LOOP: begin
//          table_index <= 0;
//          state <= `PWR_LOOP_TOP;
//            `ifdef XILINX_SIMULATOR
//                $fdisplay (filepwr, "Power(Q8.7):0x%h, dbmx10:%d", power, dbmx10);
//            `endif
//            end
//            `PWR_LOOP_TOP: begin
//                if(dbmx10 > power_table[table_index]) begin
//                    numerator <= dbmx10 - power_table[table_index];
//                    // Verilog "static array" indexing is in reverse order
//                    denominator <= power_table[table_index - 1] - power_table[table_index];
//                    mag_step <= mag_table[table_index - 1] - mag_table[table_index];
//                    state <= `PWR_MULT;
//                end
//                else begin
//                    if(table_index < pwr_table_size - 1) begin 
//                        table_index <= table_index + 1;
//                    end
//                    else begin
//                        status_o <= `ERR_POWER_INVALID;
//                        state <= `PWR_IDLE;
//                    end
//                end
//            end
//            `PWR_MULT: begin
//                multA <= mag_step;
//                multB <= numerator;
//                latency_counter <= `MULTIPLIER_CLOCKS;
//                next_state <= `PWR_DIVIDE;
//                state <= `PWR_WAIT;
//            end
//            `PWR_DIVIDE: begin
//                dividend <= multiplier_result;
//                divisor <= denominator;
//                div_enable <= 1;
//                state <= `PWR_DIV_WAIT;            // Wait for result
//            end
//            `PWR_DIV_WAIT: begin
//                if(divide_done) begin
//                    mag_data <= quotient[15:0] + mag_table[table_index];
//                    div_enable <= 0;
//                    state <= `PWR_IDLE;
////                    byte_idx <= `PWR_BYTES;
////                    state <= `PWR_QUEUE;
//                end
//            end
//            `PWR_QUEUE: begin
//                //
//                // Queue calculated bytes for SPI write
//                //
//                // When queueing has finished, byte_idx will be 0,
//                // waiting for top level to write DDS at this point,
//                // When SPI write is finished, go back to idle
//                if(byte_idx == 0) begin
//                    // wait in this state (PWR_QUEUE, byte_idx=0) until SPI fifo is empty (write has finished)
//                    if(spi_processor_idle) begin
//                        // done with write SPI, continue calculations if necessary
//                        state = `PWR_IDLE;  // Done
//                        status_o = `SUCCESS;
//                    end
//                end
//                else begin
//                    byte_idx = byte_idx - 1;
//                    if(byte_idx == 0) begin
//                        // Data bytes are in SPI fifo at top level, queue request to write.
//                        // But first, wait for fifo_empty to turn OFF
//                        spi_wr_en_o <= 0;   // Turn OFF writes!
//                        next_state <= `PWR_QUEUE_CMD;  // after fifo empty turns OFF
//                        state <= `PWR_SPIWRDATA_FINISH;
//                    end
//                    else begin
//                        shift = (`PWR_BYTES - byte_idx) << 3;
//                        spi_wr_en_o <= 1;       // Enable writes, SPI processor is not busy
//                        spi_o <= (mag_data >> shift);
//                        next_state <= `PWR_QUEUE_CMD;
//                        state <= `PWR_SPIWRDATA_WAIT;
//                    `ifdef XILINX_SIMULATOR
//                        dbgdata = (mag_data >> shift);
//                        $fdisplay (filepwr, "%02h", dbgdata);
//                    `endif
//                    end
//                end
//            end
//            `PWR_QUEUE_CMD: begin
//                // SPI data written to fifo, fifo empty OFF, write SPI processor request
//                spiwr_queue_data_o <= `SPI_PWR;     // queue request for Power write
//                spiwr_queue_wr_en_o <= 1;           // spi queue fifo write enable
//                next_state <= `PWR_QUEUE;           // after queueing cmd, wait in PWR_QUEUE state
//                state <= `PWR_SPIWRQUE_WAIT;
//            `ifdef XILINX_SIMULATOR
//                $fdisplay (filepwr, "  ");   // spacer line
//                //$fdisplay (filepwr, "Done with power %d\n", power);
//                $fclose (filepwr);
//                filepwr = 0;
//            `endif
//            end
        default: begin
          status_o = `ERR_UNKNOWN_PWR_STATE;
          state <= PWR_IDLE;
        end
        endcase
    end
  end    
endmodule
