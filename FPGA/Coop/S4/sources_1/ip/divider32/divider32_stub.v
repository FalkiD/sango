// Copyright 1986-2015 Xilinx, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2015.4 (win64) Build 1412921 Wed Nov 18 09:43:45 MST 2015
// Date        : Fri Jun 24 14:32:18 2016
// Host        : PHGCUBPS01NB914 running 64-bit Service Pack 1  (build 7601)
// Command     : write_verilog -force -mode synth_stub
//               C:/Work/sango/fpga/arty_evalboard/project_1/project_1.srcs/sources_1/ip/divider32/divider32_stub.v
// Design      : divider32
// Purpose     : Stub declaration of top-level module interface
// Device      : xc7a35ticsg324-1L
// --------------------------------------------------------------------------------

// This empty module with port declaration file causes synthesis tools to infer a black box for IP.
// The synthesis directives are for Synopsys Synplify support to prevent IO buffer insertion.
// Please paste the declaration into a Verilog source file or add the file as an additional source.
(* x_core_info = "div_gen_v5_1_9,Vivado 2015.4" *)
module divider32(aclk, s_axis_divisor_tvalid, s_axis_divisor_tready, s_axis_divisor_tdata, s_axis_dividend_tvalid, s_axis_dividend_tready, s_axis_dividend_tdata, m_axis_dout_tvalid, m_axis_dout_tdata)
/* synthesis syn_black_box black_box_pad_pin="aclk,s_axis_divisor_tvalid,s_axis_divisor_tready,s_axis_divisor_tdata[47:0],s_axis_dividend_tvalid,s_axis_dividend_tready,s_axis_dividend_tdata[63:0],m_axis_dout_tvalid,m_axis_dout_tdata[79:0]" */;
  input aclk;
  input s_axis_divisor_tvalid;
  output s_axis_divisor_tready;
  input [47:0]s_axis_divisor_tdata;
  input s_axis_dividend_tvalid;
  output s_axis_dividend_tready;
  input [63:0]s_axis_dividend_tdata;
  output m_axis_dout_tvalid;
  output [79:0]m_axis_dout_tdata;
endmodule
