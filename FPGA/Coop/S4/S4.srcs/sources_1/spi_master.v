//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/12/2016 05:21:26 PM
// Design Name: 
// Module Name: spi_master
// Project Name: S4
// Target Devices: Artix-7
// Tool Versions: 
// Description: SPI master from OpenCores.org
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments: 
// 
//////////////////////////////////////////////////////////////////////////////////

// 05-Jul-2016 refactor for CPHA=0, sample data on rising edge of SCK
//
// Code from https://embeddedmicro.com/tutorials/mojo/serial-peripheral-interface-spi
// Originally CPOL = 0 and CPHA = 1, ie SCK low is idle, data sampled falling edge
//

module spi #(parameter CLK_DIV = 2,
             parameter CPHA = 0)(
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
  //assign sck = sck_q[CLK_DIV-1] & (state_q == WAIT_HALF); // TRANSFER); (for CPHA=1)
  assign sck = sck_q[CLK_DIV-1] & (state_q == (CPHA==0 ? WAIT_HALF : TRANSFER)); // TRANSFER); (for CPHA=1) 
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
          if(CPHA == 0)
            state_d = TRANSFER;    // change state, CPHA=0
          else 
            state_d = WAIT_HALF;   // change state
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
        if(CPHA == 0) begin
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
        else begin
          sck_d = sck_q + 1'b1;                  // increment clock counter
          if (sck_q == {CLK_DIV-1{1'b1}}) begin  // if clock is half full (about to fall)
            sck_d = 1'b0;                        // reset to 0
            state_d = TRANSFER;                  // change state
          end
        end
      end
      TRANSFER: begin
        if(CPHA == 0) begin
          sck_d = sck_q + 1'b1;                           // increment clock counter
          if (sck_q == 4'b0000) begin                     // if clock counter is 0
            mosi_d = data_q[7];                           // output the MSB of data
          end else if (sck_q == {CLK_DIV-1{1'b1}}) begin  // else if it's half full (about to fall)
            data_d = {data_q[6:0], miso};                 // read in data (shift in)
            state_d = WAIT_HALF;
          end
        end
        else begin
          sck_d = sck_q + 1'b1;                           // increment clock counter
          if (sck_q == 4'b0000) begin                     // if clock counter is 0
            mosi_d = data_q[7];                           // output the MSB of data
          end else if (sck_q == {CLK_DIV-1{1'b1}}) begin  // else if it's half full (about to fall)
            data_d = {data_q[6:0], miso};                 // read in data (shift in)
          end else if (sck_q == {CLK_DIV{1'b1}}) begin    // else if it's full (about to rise)
            ctr_d = ctr_q + 1'b1;                         // increment bit counter
            if (ctr_q == 3'b111) begin                    // if we are on the last bit
              idle_pause = IDLE_COUNTER;
              state_d = IDLE_WAIT; //IDLE;                             // change state
              data_out_d = data_q;                        // output data
              new_data_d = 1'b1;                          // signal data is valid
            end
          end
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
