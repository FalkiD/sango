//------------------------------------------------------------------------------
// (C) Copyright 2016, Ampleon Inc.
//     All rights reserved.
//
// PROPRIETARY INFORMATION
//
// The information contained in this file is the property of Ampleon Inc.
// Except as specifically authorized in writing by Ampleon, the holder of this
// file:
// (1) shall keep all information contained herein confidential and shall protect
//     same in whole or in part from disclosure and dissemination to all third
//     parties and 
// (2) shall use same for operation and maintenance purposes only.
// -----------------------------------------------------------------------------
// Company:         Ampleon
// Engineer:        Jeff Cooper (JLC)
// 
// Create Date:     03/23/2016 08:52:50 AM
// Design Name:     SPI FIFO Access Arbiter
// File Name:       arbiter8.v
// Module Name:     arb8
// Project Name:    Sango
// Target Devices:  xc7a35ticsg324-1L (debug)
// Tool Versions:   Vivado 2015.1 (RMR) & 2016.2 (JLC)
// Description:     Round-Robin 8-input Arbiter
// 
// Dependencies:    
// 
// Revision 0.01 - File Created
//
// Additional Comments: General structure/sequence:
//   Fifo's at top level for: opcodes and opcode processor output
//   such as frequency, power, bias, phase, pulse, etc.
//
//   Processor modules for each item, frequency, power, phase, etc
//   will process their respective fifo data and generate SPI data
//   to be sent to hardware.
//
//   Each SPI device also has a fifo at top level. SPI data is written
//   by each subsystem processor into the correct SPI fifo. When a
//   hardware processor has finished generating SPI bytes, a request 
//   to write SPI will be written into the top level SpiQueue fifo.
//
//   An always block at top level will process the SPI queue, writing
//   bytes from a device fifo to the device.
// 
// -----------------------------------------------------------------------------

//////////////////////////////////////////////////////////////////////////////////
//------------------------------------------------------------------------------
// File name:   arbiter8.v
// Project:     Ampleon Sango S4/X7
// Author:      Jeff Cooper aa1ww.coop@gmail.com
// Purpose:     8 client round-robin (equal job size) arbiter
// -----------------------------------------------------------------------------
// Reset strategy:	   synchronous using xrst
// Clock domains:      xclk
//------------------------------------------------------------------------------
//------------------------------------------------------------------------------
// File name:   arb8.v
// Project:     Ampleon Sango S4/X7
// Author:      Jeff Cooper aa1ww.coop@gmail.com
// Purpose:     8 client round-robin (equal job size) arbiter
// -----------------------------------------------------------------------------
// Reset strategy:	   synchronous using xrst
// Clock domains:      xclk
//------------------------------------------------------------------------------

`include "timescale.v"
`include "version.v"

module arb8 #
(
    parameter Nreq           = 8
)
(
    input  wire              xclk,
    input  wire              xrst,
    input  wire              arben,         // 1 -> QPB's can arb; 0 -> not.
    input  wire  [7:0]       req,
    output reg   [7:0]       xgnt,
    output reg   [2:0]       gntidx
    );
  
    wire                     mgnull_w;
    
    wire  [7:0]              req_w;
    wire  [7:0]              mrq_w;
    wire  [7:0]              xgnt_w    = xgnt;
    wire  [7:0]              xgntr_w   = xgntr;
    wire                     anyreq_w  = |req_w;
    wire                     anymrq_w  = |mrq_w;
    wire  [7:0]              mgnt_w    = mgnt;
    wire  [7:0]              ugnt_w    = ugnt;
    wire                     killgnt_w;
    wire                     lookahead_w;
    
    wire                     diag0_w;
    wire  [7:0]              diag1_w;
    wire  [7:0]              diag2_w;
    
    reg   [7:0]              reqq;
    reg   [7:0]              ugnt;
    reg   [7:0]              xgntr;
    reg   [7:0]              mrqq;
    reg   [7:0]              mgnt;
    reg   [7:0]              mask;
    
    reg                      killgnt;
    reg                      clsd;
    
    //************************************************************
    //
    //   Arbiter
    //
    //   This is a classic round robin arbiter with two tiers:
    //   1.) Those ahead of the RR ptr (  masked req's), and
    //   2.) Those behind   the RR ptr (unmasked req's).
    //
    //   Each tier has a fixed priority decoder and the masked
    //   guys win if they have a candidate; else it goes to the
    //   unmasked winner if he exists.
    //
    //   Grants are asserted until 1 tick after causing req deasserts.
    //   Requests MUST DEASSERT for an least 1 tick between requests.
    //
    //************************************************************
    
    always @(posedge xclk)
    begin
     if (xrst)
     begin
        clsd             <= 1'b0;
        reqq             <= 8'b0;  // unmasked reqq  is captured to begin an arb epoch.
        ugnt             <= 8'b0;  // proposed grant if there are no   masked grants.
        mrqq             <= 8'b0;  //   masked mrqq  is captured to begin an arb epoch.
        mgnt             <= 8'b0;  // proposed grant if there are some masked grants.
        killgnt          <= 1'b0;  // indicates deassertion of causing request.
        mask             <= 8'b0;  // the current mask giving preference to some reqs
        xgnt             <= 8'b0;  // actual issued output grant vector.
        xgntr            <= 8'b0;  // one-tick delay of xgnt.
        gntidx           <= 8'b0;  // actual issued grant index (used for spi_mux selector)
     end  // if (xrst) then portion
     else
     begin
        clsd             <= anyreq_w;
        killgnt          <= (|((~req_w) & xgnt_w)) & (~killgnt);  // killgnt asserts if causing req deasserts.
    
        // Only sample new req's if:
        //    1.) There are req's    _AND_
        //    2.) you aren't granting anyone
        if ( (anyreq_w & ~clsd) | killgnt )
        begin
           reqq          <= req_w;         
           mrqq          <= mrq_w;
        end
    
        // Compute the unmasked grant vector, ugnt.
        ugnt[7]          <= ~killgnt &  reqq[7];
        ugnt[6]          <= ~killgnt & ~reqq[7] &  reqq[6];
        ugnt[5]          <= ~killgnt & ~reqq[7] & ~reqq[6] &  reqq[5];
        ugnt[4]          <= ~killgnt & ~reqq[7] & ~reqq[6] & ~reqq[5] &  reqq[4];
        ugnt[3]          <= ~killgnt & ~reqq[7] & ~reqq[6] & ~reqq[5] & ~reqq[4] &  reqq[3];
        ugnt[2]          <= ~killgnt & ~reqq[7] & ~reqq[6] & ~reqq[5] & ~reqq[4] & ~reqq[3] &  reqq[2];
        ugnt[1]          <= ~killgnt & ~reqq[7] & ~reqq[6] & ~reqq[5] & ~reqq[4] & ~reqq[3] & ~reqq[2] &  reqq[1];
        ugnt[0]          <= ~killgnt & ~reqq[7] & ~reqq[6] & ~reqq[5] & ~reqq[4] & ~reqq[3] & ~reqq[2] & ~reqq[1] &  reqq[0];
    
        // Compute the   masked grant vector, mgnt.
        mgnt[7]          <= ~killgnt &  mrqq[7];
        mgnt[6]          <= ~killgnt & ~mrqq[7] &  mrqq[6];
        mgnt[5]          <= ~killgnt & ~mrqq[7] & ~mrqq[6] &  mrqq[5];
        mgnt[4]          <= ~killgnt & ~mrqq[7] & ~mrqq[6] & ~mrqq[5] &  mrqq[4];
        mgnt[3]          <= ~killgnt & ~mrqq[7] & ~mrqq[6] & ~mrqq[5] & ~mrqq[4] &  mrqq[3];
        mgnt[2]          <= ~killgnt & ~mrqq[7] & ~mrqq[6] & ~mrqq[5] & ~mrqq[4] & ~mrqq[3] &  mrqq[2];
        mgnt[1]          <= ~killgnt & ~mrqq[7] & ~mrqq[6] & ~mrqq[5] & ~mrqq[4] & ~mrqq[3] & ~mrqq[2] &  mrqq[1];
        mgnt[0]          <= ~killgnt & ~mrqq[7] & ~mrqq[6] & ~mrqq[5] & ~mrqq[4] & ~mrqq[3] & ~mrqq[2] & ~mrqq[1] &  mrqq[0];
    
        xgnt             <= ({8{mgnull_w}} & ugnt_w | {8{~mgnull_w}} & mgnt_w) & ({8{~killgnt}});  // 
        xgntr            <= xgnt_w;
    
        // Update the mask sometime after granting but before killgnt.
        if (lookahead_w)
        begin
           mask[7]       <= 1'b0;
           mask[6]       <= |{xgnt[7:7]};
           mask[5]       <= |{xgnt[7:6]};
           mask[4]       <= |{xgnt[7:5]};
           mask[3]       <= |{xgnt[7:4]};
           mask[2]       <= |{xgnt[7:3]};
           mask[1]       <= |{xgnt[7:2]};
           mask[0]       <= |{xgnt[7:1]};
        end

        if(xgnt != 8'h00)
        begin
            // 27-Jul-2016 write output index value too, used for mux selector
            if(xgnt & 8'h01)
                gntidx <= 3'd0;
            else if(xgnt & 8'h02)
                gntidx <= 3'd1;
            else if(xgnt & 8'h04)
                gntidx <= 3'd2;
            else if(xgnt & 8'h08)
                gntidx <= 3'd3;
            else if(xgnt & 8'h10)
                gntidx <= 3'd4;
            else if(xgnt & 8'h20)
                gntidx <= 3'd5;
            else if(xgnt & 8'h40)
                gntidx <= 3'd6;
            else if(xgnt & 8'h80)
                gntidx <= 3'd7;
        end
     end  // if (xrst) else portion
    end  // always @(posedge xclk)
    
    
    assign mgnull_w                = ~(|mgnt_w);    // asserted if there are no masked grants.
    
    assign req_w                   =        req & {8{arben}};
    assign mrq_w                   = mask & req & {8{arben}};
    
    assign killgnt_w               = killgnt;
    assign lookahead_w             = (|((~req_w) & xgnt_w)) & ~killgnt_w;
    assign diag0_w                 = |((~req_w) & xgnt_w);
    assign diag1_w                 = (~req_w);
    assign diag2_w                 = (~req_w) & xgnt_w;

  
endmodule // spi_arb




//module spi_arb #
//(
//   parameter NQpb           = 8,
//   parameter NSeq           = 4
//)
//(
//   input  wire              xclk,
//   input  wire              xrst,
//   input  wire              arben,         // 1 -> QPB's can arb; 0 -> not.
//   input  wire [7:0]        qreq,
//   input  wire [7:0]        qdir,
//   output wire              xgnting,
//   output wire              xgntingr,
//   output reg  [7:0]        xgnt,
//   output reg  [7:0]        xgntr1,
//   output reg  [7:0]        xgntr2,
//   // input  wire              xdone,         // sdram write/read (this grant cycle) is done.
//   output reg               xgntq2x,       // 1 -> grant is q2x; 0 -> x2q
//   output reg               reqq2x_ever,   // 1 -> at least one q2x request seen since xrst.
//   output reg               gntq2x_ever,   // 1 -> at least one q2x grant   seen since xrst.
//   output reg  [7:0]        diag_bus00w,
//   output reg  [7:0]        diag_bus01w,
//   output reg  [7:0]        diag_bus10w,
//   output reg  [7:0]        diag_bus11w
//  );


//   localparam XMEM_ARB_Q2X_DUR          = 5'h13;
//   localparam XMEM_ARB_X2Q_DUR          = 5'h0D;

//   wire                                 mgnull;

//   wire [7:0] 				qreq_w;
//   wire [7:0] 				qmrq_w;

//   reg                                  killgnt1;
//   reg                                  killgnt1r;
//   reg                                  killgnt1rr;
//   reg                                  killgnt1rrr;
//   reg                                  killgnt1rrrr;
//   reg                                  killgntstretch;

//   // SPI Side (xclk)           Arb regs
//   reg  [7:0]                           reqq;
//   reg  [7:0]                           ugnt;
//   reg  [7:0]                           mrqq;
//   reg  [7:0]                           mgnt;
//   reg  [7:0]                           mask;

//   reg                                  clsd;
//   reg                                  clsdr;
//   reg                                  clsdrr;
//   reg                                  clsdrrr;
//   reg                                  clsdstretch;
//   reg                                  gnting;      // grant is in-progress.
//   reg                                  gntingr;     // grant is in-progress.
//   reg  [4:0]                           gnttmr;

//   reg                                  gntq2xr;

   
//   //************************************************************
//   //
//   //   Arbiter
//   //
//   //   This is a classic round robin arbiter with two tiers:
//   //   1.) Those ahead of the RR ptr (  masked req's), and
//   //   2.) Those behind   the RR ptr (unmasked req's).
//   //
//   //   Each tier has a fixed priority decoder and the masked
//   //   guys win if they have a candidate; else it goes to the
//   //   unmasked winner if he exists.
//   //
//   //   Grants are statically timed.
//   //     q2x grants (SDRAM writes) are ~22 xclk ticks long;
//   //     x2q grants (SDRAM reads)  are ~17 xclk ticks long;
//   //     reqi's get killed at q2xram's upon gnt rcv'd.
//   //
//   //************************************************************

//   always @(posedge xclk) begin
//      if (xrst) begin
//         clsd             <= 1'b0;
//         clsdr            <= 1'b0;
//         clsdrr           <= 1'b0;
//         clsdrrr          <= 1'b0;
//         clsdstretch      <= 1'b0;
//         reqq             <= 8'b0;  // reqq  is captured to begin an arb epoch.
//         ugnt             <= 8'b0;
//         mrqq             <= 8'b0;
//         mgnt             <= 8'b0;
//         mask             <= 8'b0;
//         xgnt             <= 8'b0;
//         xgntr1           <= 8'b0;
//         xgntr2           <= 8'b0;
//         xgntq2x          <= 1'b0;
//         gntq2xr          <= 1'b0;
//         reqq2x_ever      <= 1'b0;
//         gntq2x_ever      <= 1'b0;
//         gnting           <= 1'b0;
//         gntingr          <= 1'b0;
//         gnttmr           <= 5'b0_0000;
//         killgnt1         <= 1'b0;
//         killgnt1r        <= 1'b0;
//         killgnt1rr       <= 1'b0;
//         killgnt1rrr      <= 1'b0;
//         killgnt1rrrr     <= 1'b0;
//         killgntstretch   <= 1'b0;
//         killgntstretch   <= 1'b0;
//         end  // if (xrst) then portion
//      else begin
//         clsd             <= |qreq_w;
//         clsdr            <= clsd;
//         clsdrr           <= clsdr;
//         clsdrrr          <= clsdrr;
//         killgnt1r        <= killgnt1;
//         killgnt1rr       <= killgnt1r;
//         killgnt1rrr      <= killgnt1rr;
//         killgnt1rrrr     <= killgnt1rrr;
//         killgntstretch   <= killgnt1 | killgnt1r | killgnt1rr | killgnt1rrr;

//         // Only sample new qreq's if you're not granting anyone
//         // if (!gnting & !killgntstretch | killgnt1rr) begin
//         clsdstretch      <= clsd | clsdr | clsdrr | clsdrrr | gnting;
//         // if (!clsd & !clsdstretch | killgnt1rr) begin  <-- this was open for more than 1 tick (changed in 0c203A/0003).
//         if (clsd & !clsdstretch | killgnt1rr) begin
//            reqq          <= qreq_w;         
//            mrqq          <= qmrq_w;
//            end
  
//         ugnt[7]          <= !killgntstretch &  reqq[7];
//         ugnt[6]          <= !killgntstretch & !reqq[7] &  reqq[6];
//         ugnt[5]          <= !killgntstretch & !reqq[7] & !reqq[6] &  reqq[5];
//         ugnt[4]          <= !killgntstretch & !reqq[7] & !reqq[6] & !reqq[5] &  reqq[4];
//         ugnt[3]          <= !killgntstretch & !reqq[7] & !reqq[6] & !reqq[5] & !reqq[4] &  reqq[3];
//         ugnt[2]          <= !killgntstretch & !reqq[7] & !reqq[6] & !reqq[5] & !reqq[4] & !reqq[3] &  reqq[2];
//         ugnt[1]          <= !killgntstretch & !reqq[7] & !reqq[6] & !reqq[5] & !reqq[4] & !reqq[3] & !reqq[2] &  reqq[1];
//         ugnt[0]          <= !killgntstretch & !reqq[7] & !reqq[6] & !reqq[5] & !reqq[4] & !reqq[3] & !reqq[2] & !reqq[1] &  reqq[0];

//         mgnt[7]          <= !killgntstretch &  mrqq[7];
//         mgnt[6]          <= !killgntstretch & !mrqq[7] &  mrqq[6];
//         mgnt[5]          <= !killgntstretch & !mrqq[7] & !mrqq[6] &  mrqq[5];
//         mgnt[4]          <= !killgntstretch & !mrqq[7] & !mrqq[6] & !mrqq[5] &  mrqq[4];
//         mgnt[3]          <= !killgntstretch & !mrqq[7] & !mrqq[6] & !mrqq[5] & !mrqq[4] &  mrqq[3];
//         mgnt[2]          <= !killgntstretch & !mrqq[7] & !mrqq[6] & !mrqq[5] & !mrqq[4] & !mrqq[3] &  mrqq[2];
//         mgnt[1]          <= !killgntstretch & !mrqq[7] & !mrqq[6] & !mrqq[5] & !mrqq[4] & !mrqq[3] & !mrqq[2] &  mrqq[1];
//         mgnt[0]          <= !killgntstretch & !mrqq[7] & !mrqq[6] & !mrqq[5] & !mrqq[4] & !mrqq[3] & !mrqq[2] & !mrqq[1] &  mrqq[0];

//         //mgnt             <= 8'b0;
	 
//         xgnt             <= ({8{mgnull}} & ugnt | {8{!mgnull}} & mgnt) & {8{!killgntstretch}};  // 
//         xgntr1           <= xgnt;
//         xgntr2           <= xgnt;
//         xgntq2x          <= |(({8{mgnull}} & ugnt | {8{!mgnull}} & mgnt) & qdir);
//         gntq2xr          <= xgntq2x;
//         gnting           <= (!killgnt1) & (gnting | (!gnting & !gntingr & |xgnt & arben));
//         gntingr          <= gnting;
//         reqq2x_ever      <= (|(qreq_w & qdir)) | reqq2x_ever;
//         gntq2x_ever      <= xgntq2x | gntq2x_ever;

//         // Update the mask sometime after capturing reqq & mrqq but before killgnt1rr.
//         if (killgnt1) begin
//            mask[7]       <= 1'b0;
//            mask[6]       <= |{xgnt[7:7]};
//            mask[5]       <= |{xgnt[7:6]};
//            mask[4]       <= |{xgnt[7:5]};
//            mask[3]       <= |{xgnt[7:4]};
//            mask[2]       <= |{xgnt[7:3]};
//            mask[1]       <= |{xgnt[7:2]};
//            mask[0]       <= |{xgnt[7:1]};
//            end


//         // Every tick defaults:
//         //
//         gnttmr        <= 5'b0_0000;
//         killgnt1      <= 1'b0;
	 
//         // meter out duration of grant based on q2x vs. x2q.
//         //
//         if (gnting) begin 
//            if (!gntingr) begin
//	        // 1st xclk tick of new grant.
//	        gnttmr     <= ({5{gntq2xr}} & XMEM_ARB_Q2X_DUR) | ({5{!gntq2xr}} & XMEM_ARB_X2Q_DUR);
//            end
//         else begin
//	        // Subsequent xclk tick of grant.
//	        gnttmr     <= gnttmr - 5'b0_0001;
//	        end
//	     if (gnttmr == 5'b0_0001) begin
//            killgnt1   <= 1'b1;
//	        end
//	     end // if (gnting)
//      end  // if (xrst) else portion
//   end  // always @(posedge xclk)


//   assign mgnull                  = !(|mgnt);

//   assign qreq_w                  = qreq        & {8{arben}};
//   assign qmrq_w                  = mask & qreq & {8{arben}};

//   assign xgnting                 = gnting;
//   assign xgntingr                = gntingr;

//endmodule // spi_arb
