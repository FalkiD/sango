-- Copyright 1986-2015 Xilinx, Inc. All Rights Reserved.
-- --------------------------------------------------------------------------------
-- Tool Version: Vivado v.2015.4 (win64) Build 1412921 Wed Nov 18 09:43:45 MST 2015
-- Date        : Fri Jun 24 15:00:10 2016
-- Host        : PHGCUBPS01NB914 running 64-bit Service Pack 1  (build 7601)
-- Command     : write_vhdl -force -mode synth_stub
--               C:/Work/sango/fpga/arty_evalboard/project_1/project_1.srcs/sources_1/ip/mult48/mult48_stub.vhdl
-- Design      : mult48
-- Purpose     : Stub declaration of top-level module interface
-- Device      : xc7a35ticsg324-1L
-- --------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity mult48 is
  Port ( 
    CLK : in STD_LOGIC;
    A : in STD_LOGIC_VECTOR ( 55 downto 0 );
    B : in STD_LOGIC_VECTOR ( 23 downto 0 );
    CE : in STD_LOGIC;
    P : out STD_LOGIC_VECTOR ( 63 downto 0 )
  );

end mult48;

architecture stub of mult48 is
attribute syn_black_box : boolean;
attribute black_box_pad_pin : string;
attribute syn_black_box of stub : architecture is true;
attribute black_box_pad_pin of stub : architecture is "CLK,A[55:0],B[23:0],CE,P[63:0]";
attribute x_core_info : string;
attribute x_core_info of stub : architecture is "mult_gen_v12_0_10,Vivado 2015.4";
begin
end;
