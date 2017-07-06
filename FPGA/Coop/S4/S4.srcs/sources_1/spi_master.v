//
// 26-Apr-2016 using VHDL version that support CPOL
// and CPHA selection, multiple slave devices.
//
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/12/2016 05:21:26 PM
// Design Name: 
// Module Name: spi_master
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: SPI master from OpenCores.org
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments: X7 SPI devices:
//
//# Device=00 Main Board DDS (AD9956)
//# Control Function Register 1 (CFR1) (0x00)
//0x00 0x00 0x00 0x00 0x40 0x00
//# Control Function Register 2 (CFR2) (0x01)
//0x00 0x01 0x00 0x02 0x49 0x90 0x20
//# Rising Delta Frequency Tuning Word (RDFTW) (0x02)
//# Falling Delta Frequency Tuning Word (FDFTW) (0x03)
//# Rising Sweep Ramp Rate (RSRR) (0x04)
//# Falling Sweep Ramp Rate (FSRR) (0x05)
//# Profile Control Register No. 0 (PCR0) (0x06)
//# Profile Control Register No. 1 (PCR1) (0x07)
//# Profile Control Register No. 2 (PCR2) (0x08)
//# Profile Control Register No. 3 (PCR3) (0x09)
//# Profile Control Register No. 4 (PCR4) (0x0a)
//# Profile Control Register No. 5 (PCR5) (0x0b)
//# Profile Control Register No. 6 (PCR6) (0x0c)
//# Profile Control Register No. 7 (PCR7) (0x0d)

//# Device=01 Main Board Rsyn (ADF4108)
//# Initialization latch
//0x01 0x1f 0xf8 0x13
//# Function latch
//0x01 0x1f 0xf8 0x12
//# Reference counter latch
//0x01 0x00 0x00 0x04
//# N counter latch
//0x01 0x00 0x05 0x1d

//# Device=02 Main Board Msyn (ADF4108)
//# Device=03 Main Board MBW register (74LVC595)

//# Device=10 Main Board FPGA Config block write
//# Device=11 Main Board FPGA Channel 1 block write
//# Device=12 Main Board FPGA Channel 2 block write
//# Device=13 Main Board FPGA Channel 3 block write
//# Device=14 Main Board FPGA Channel 4 block write

//# Device=18 Main Board FPGA Status block read
//# Device=19 Main Board FPGA Channel 1 measurement block read
//# Device=1a Main Board FPGA Channel 2 measurement block read
//# Device=1b Main Board FPGA Channel 3 measurement block read
//# Device=1c Main Board FPGA Channel 4 measurement block read

//# Device=20 Output Module 1 IQ DAC (AD9717)
//# Device=21 Output Module 1 Gain Levelling (MCP4921)
//# Device=22 Output Module 1 Attenuator (HMC629->HMC629->MCP4921)
//# Device=24 Output Module 1 FPGA

//# Device=28 Output Module 2 IQ DAC (AD9717)
//# Device=29 Output Module 2 Gain Levelling (MCP4921)
//# Device=2a Output Module 2 Attenuator (HMC629->HMC629->MCP4921)
//# Device=2c Output Module 2 FPGA

//# Device=30 Output Module 3 IQ DAC (AD9717)
//# Device=31 Output Module 3 Gain Levelling (MCP4921)
//# Device=32 Output Module 3 Attenuator (HMC629->HMC629->MCP4921)
//# Device=34 Output Module 3 FPGA

//# Device=38 Output Module 4 IQ DAC (AD9717)
//# Device=39 Output Module 4 Gain Levelling (MCP4921)
//# Device=3a Output Module 4 Attenuator (HMC629->HMC629->MCP4921)
//# Device=3c Output Module 4 FPGA
// 
//////////////////////////////////////////////////////////////////////////////////

// 05-Jul-2016 refactor for CPHA=0, sample data on rising edge of SCK
// should parameterize this module for CPOL, CPHA
//
// Code from https://embeddedmicro.com/tutorials/mojo/serial-peripheral-interface-spi
// In this case CPOL = 0 and CPHA = 1, ie SCK low is idle, data sampled falling edge
//
`include "timescale.v"

module spi #(parameter CLK_DIV = 2)(
    input clk,
    input rst,
    input miso,
    output mosi,
    output sck,
    input start,
    input[7:0] data_in,
    output[7:0] data_out,
    output busy,
    output new_data             // 1=signal, data_out is valid
  );
   
  localparam IDLE_COUNTER = 1;
  localparam STATE_SIZE = 2;
  localparam IDLE = 2'd0,
    WAIT_HALF = 2'd1,
    TRANSFER = 2'd2,
    IDLE_WAIT = 3'd3;   // Need a clock to wait for 'start' control from SPI processor
   
  reg [2:0] idle_pause;
  reg [STATE_SIZE-1:0] state_d, state_q;
   
  reg [7:0] data_d, data_q;
  reg [CLK_DIV-1:0] sck_d, sck_q;
  reg mosi_d, mosi_q;
  reg [2:0] ctr_d, ctr_q;
  reg new_data_d, new_data_q;
  reg [7:0] data_out_d, data_out_q;
   
  assign mosi = mosi_q;
  // CPHA=1 version
  //assign sck = (~sck_q[CLK_DIV-1]) & (state_q == TRANSFER);
  // CPHA=0 version
  assign sck = sck_q[CLK_DIV-1] & (state_q == WAIT_HALF); // TRANSFER); (for CPHA=1)
  assign busy = state_q != IDLE;
  assign data_out = data_out_q;
  assign new_data = new_data_q;
   
  always @(*) begin
    sck_d = sck_q;
    data_d = data_q;
    mosi_d = mosi_q;
    ctr_d = ctr_q;
    new_data_d = 1'b0;
    data_out_d = data_out_q;
    state_d = state_q;
     
    case (state_q)
      IDLE: begin
        sck_d = 4'b0;              // reset clock counter
        ctr_d = 3'b0;              // reset bit counter
        mosi_d = 1'b0;
        if (start == 1'b1) begin   // if start command on a high clock
          data_d = data_in;        // copy data to send
          state_d = TRANSFER;     // change state, CPHA=0
// CPHA=1          state_d = WAIT_HALF;     // change state
        end
      end
      IDLE_WAIT: begin
        //if(idle_pause == 0)
            state_d = IDLE;
        //else
        //    idle_pause = idle_pause - 1;
      end

// CPHA=1 code, should parameterize the module.
//      WAIT_HALF: begin
//        sck_d = sck_q + 1'b1;                  // increment clock counter
//        if (sck_q == {CLK_DIV-1{1'b1}}) begin  // if clock is half full (about to fall)
//          sck_d = 1'b0;                        // reset to 0
//          state_d = TRANSFER;                  // change state
//        end
//      end
//      TRANSFER: begin
//        sck_d = sck_q + 1'b1;                           // increment clock counter
//        if (sck_q == 4'b0000) begin                     // if clock counter is 0
//          mosi_d = data_q[7];                           // output the MSB of data
//        end else if (sck_q == {CLK_DIV-1{1'b1}}) begin  // else if it's half full (about to fall)
//          data_d = {data_q[6:0], miso};                 // read in data (shift in)
//        end else if (sck_q == {CLK_DIV{1'b1}}) begin    // else if it's full (about to rise)
//          ctr_d = ctr_q + 1'b1;                         // increment bit counter
//          if (ctr_q == 3'b111) begin                    // if we are on the last bit
//            idle_pause = IDLE_COUNTER;
//            state_d = IDLE_WAIT; //IDLE;                             // change state
//            data_out_d = data_q;                        // output data
//            new_data_d = 1'b1;                          // signal data is valid
//          end
//        end
//      end

      // To change CPHA to 0, execute TRANSFER state first, follow with WAIT_HALF state.
      WAIT_HALF: begin
        sck_d = sck_q + 1'b1;                  // increment clock counter
        if (sck_q == {CLK_DIV{1'b1}}) begin    // if clock is full (about to rise)
          sck_d = 1'b0;                        // reset to 0
          ctr_d = ctr_q + 1'b1;                // increment bit counter
          if (ctr_q == 3'b111) begin           // if we are on the last bit
            idle_pause = IDLE_COUNTER;
            state_d = IDLE_WAIT; //IDLE;       // change state
            data_out_d = data_q;               // output data
            new_data_d = 1'b1;                 // signal data is valid
          end
          else 
            state_d = TRANSFER;                // next bit, change state
        end
      end
      TRANSFER: begin
        sck_d = sck_q + 1'b1;                           // increment clock counter
        if (sck_q == 4'b0000) begin                     // if clock counter is 0
          mosi_d = data_q[7];                           // output the MSB of data
        end else if (sck_q == {CLK_DIV-1{1'b1}}) begin  // else if it's half full (about to fall)
          data_d = {data_q[6:0], miso};                 // read in data (shift in)
          state_d = WAIT_HALF;
        end
      end
    endcase
  end
   
  always @(posedge clk) begin
    if (rst) begin
      ctr_q <= 3'b0;
      data_q <= 8'b0;
      sck_q <= 4'b0;
      mosi_q <= 1'b0;
      state_q <= IDLE;
      data_out_q <= 8'b0;
      new_data_q <= 1'b0;
    end else begin
      ctr_q <= ctr_d;
      data_q <= data_d;
      sck_q <= sck_d;
      mosi_q <= mosi_d;
      state_q <= state_d;
      data_out_q <= data_out_d;
      new_data_q <= new_data_d;
    end
  end
   
endmodule
