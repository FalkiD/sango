//------------------------------------------------------------------------------
// (C) Copyright 2014, NXP Semiconductors
//     All rights reserved.
//
// PROPRIETARY INFORMATION
//
// The information contained in this file is the property of NXP Semiconductors.
// Except as specifically authorized in writing by NXP, the holder of this
// file: (1) shall keep all information contained herein confidential and
// shall protect same in whole or in part from disclosure and dissemination to
// all third parties and (2) shall use same for operation and maintenance
// purposes only.
// -----------------------------------------------------------------------------
// File name:		ctrl4_trig.v
// Project:		Use the Ctrl4 trigger interface adapter
// 			as a sequential 4-channel trigger generator
// Author: 		Roger Williams <roger.williams@nxp.com> (RAW)
// -----------------------------------------------------------------------------
// 1  2014-04-24 (RAW) Initial design entry
//------------------------------------------------------------------------------

module trig_gen
   (
    input wire 		TRIGIN,
    output wire [4:1]	TRIGOUT,
    output wire		LEDOUT
    );

   reg [4:1] 		trigsel = 4'b0001;
   always @(negedge TRIGIN)
     trigsel[4:1] <= {trigsel[3:1],trigsel[4]};

   assign 		TRIGOUT = {4{TRIGIN}} & trigsel;
   assign 		LEDOUT = ~TRIGIN;

endmodule
