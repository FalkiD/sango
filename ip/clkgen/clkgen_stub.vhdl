-- Copyright 1986-2015 Xilinx, Inc. All Rights Reserved.
-- --------------------------------------------------------------------------------
-- Tool Version: Vivado v.2015.4 (win64) Build 1412921 Wed Nov 18 09:43:45 MST 2015
-- Date        : Thu Jul 14 09:50:15 2016
-- Host        : PHGCUBPS01NB914 running 64-bit Service Pack 1  (build 7601)
-- Command     : write_vhdl -force -mode synth_stub
--               C:/Work/sango/fpga/arty_evalboard/project_1/project_1.srcs/sources_1/ip/clkgen/clkgen_stub.vhdl
-- Design      : clkgen
-- Purpose     : Stub declaration of top-level module interface
-- Device      : xc7a35ticsg324-1L
-- --------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity clkgen is
  Port ( 
    clk_in : in STD_LOGIC;
    clk : out STD_LOGIC;
    clk50 : out STD_LOGIC;
    reset : in STD_LOGIC
  );

end clkgen;

architecture stub of clkgen is
attribute syn_black_box : boolean;
attribute black_box_pad_pin : string;
attribute syn_black_box of stub : architecture is true;
attribute black_box_pad_pin of stub : architecture is "clk_in,clk,clk50,reset";
begin
end;
