// Copyright 1986-2015 Xilinx, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2015.4 (win64) Build 1412921 Wed Nov 18 09:43:45 MST 2015
// Date        : Thu Jul 14 09:50:15 2016
// Host        : PHGCUBPS01NB914 running 64-bit Service Pack 1  (build 7601)
// Command     : write_verilog -force -mode synth_stub
//               C:/Work/sango/fpga/arty_evalboard/project_1/project_1.srcs/sources_1/ip/clkgen/clkgen_stub.v
// Design      : clkgen
// Purpose     : Stub declaration of top-level module interface
// Device      : xc7a35ticsg324-1L
// --------------------------------------------------------------------------------

// This empty module with port declaration file causes synthesis tools to infer a black box for IP.
// The synthesis directives are for Synopsys Synplify support to prevent IO buffer insertion.
// Please paste the declaration into a Verilog source file or add the file as an additional source.
module clkgen(clk_in, clk, clk50, reset)
/* synthesis syn_black_box black_box_pad_pin="clk_in,clk,clk50,reset" */;
  input clk_in;
  output clk;
  output clk50;
  input reset;
endmodule
