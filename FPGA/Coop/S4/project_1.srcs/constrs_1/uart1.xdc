## This file is a general .xdc for the ARTY Rev. A
## To use it in a project:
## - uncomment the lines corresponding to used pins
## - rename the used ports (in each line, after get_ports) according to the top level signal names in the project


set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property CFGBVS VCCO [current_design]

# Clock signal

set_property -dict {PACKAGE_PIN E3 IOSTANDARD LVCMOS33} [get_ports CLK]
create_clock -period 10.000 -name sys_clk_pin -waveform {0.000 5.000} -add [get_ports CLK]


#Switches

set_property -dict {PACKAGE_PIN A8 IOSTANDARD LVCMOS33} [get_ports {sw[0]}]
set_property -dict {PACKAGE_PIN C11 IOSTANDARD LVCMOS33} [get_ports {sw[1]}]
set_property -dict {PACKAGE_PIN C10 IOSTANDARD LVCMOS33} [get_ports {sw[2]}]
set_property -dict {PACKAGE_PIN A10 IOSTANDARD LVCMOS33} [get_ports {sw[3]}]


# LEDs

#set_property -dict { PACKAGE_PIN E1    IOSTANDARD LVCMOS33 } [get_ports { MSYN_SSN }]; #RGB0_Blue }]; #IO_L18N_T2_35 Sch=led0_b
#set_property -dict { PACKAGE_PIN F6    IOSTANDARD LVCMOS33 } [get_ports { SYN_MISO }]; #RGB0_Green }]; #IO_L19N_T3_VREF_35 Sch=led0_g
set_property -dict {PACKAGE_PIN F6 IOSTANDARD LVCMOS33} [get_ports RGB0_Green]
#set_property -dict { PACKAGE_PIN G6    IOSTANDARD LVCMOS33 } [get_ports { SYN_MOSI }]; #RGB0_Red }]; #IO_L19P_T3_35 Sch=led0_r
#set_property -dict { PACKAGE_PIN G4    IOSTANDARD LVCMOS33 } [get_ports { SYN_SCLK }]; #RGB1_Blue }]; #IO_L20P_T3_35 Sch=led1_b
#set_property -dict { PACKAGE_PIN J4    IOSTANDARD LVCMOS33 } [get_ports { DDS_SSN }]; #RGB1_Green }]; #IO_L21P_T3_DQS_35 Sch=led1_g
set_property -dict {PACKAGE_PIN J4 IOSTANDARD LVCMOS33} [get_ports RGB1_Green]
#set_property -dict { PACKAGE_PIN G3    IOSTANDARD LVCMOS33 } [get_ports { FR_SSN }]; #RGB1_Red }]; #IO_L20N_T3_35 Sch=led1_r
#set_property -dict { PACKAGE_PIN H4    IOSTANDARD LVCMOS33 } [get_ports { RSYN_SSN }]; #RGB2_Blue }]; #IO_L21N_T3_DQS_35 Sch=led2_b
#set_property -dict { PACKAGE_PIN J2    IOSTANDARD LVCMOS33 } [get_ports { MBW_SSN }]; #RGB2_Green }]; #IO_L22N_T3_35 Sch=led2_g
set_property -dict {PACKAGE_PIN J2 IOSTANDARD LVCMOS33} [get_ports RGB2_Green]
#set_property -dict { PACKAGE_PIN J3    IOSTANDARD LVCMOS33 } [get_ports { RGB2_Red }]; #IO_L22P_T3_35 Sch=led2_r
#set_property -dict { PACKAGE_PIN K2    IOSTANDARD LVCMOS33 } [get_ports { RGB3_Blue }]; #IO_L23P_T3_35 Sch=led3_b
#set_property -dict { PACKAGE_PIN H6    IOSTANDARD LVCMOS33 } [get_ports { RGB3_Green }]; #IO_L24P_T3_35 Sch=led3_g
set_property -dict {PACKAGE_PIN H6 IOSTANDARD LVCMOS33} [get_ports RGB3_Green]
#set_property -dict { PACKAGE_PIN K1    IOSTANDARD LVCMOS33 } [get_ports { RGB3_Red }]; #IO_L23N_T3_35 Sch=led3_r
set_property -dict {PACKAGE_PIN H5 IOSTANDARD LVCMOS33} [get_ports {led[0]}]
set_property -dict {PACKAGE_PIN J5 IOSTANDARD LVCMOS33} [get_ports {led[1]}]
set_property -dict {PACKAGE_PIN T9 IOSTANDARD LVCMOS33} [get_ports {led[2]}]
set_property -dict {PACKAGE_PIN T10 IOSTANDARD LVCMOS33} [get_ports {led[3]}]


#Buttons

set_property -dict {PACKAGE_PIN D9 IOSTANDARD LVCMOS33} [get_ports {btn[0]}]
set_property -dict {PACKAGE_PIN C9 IOSTANDARD LVCMOS33} [get_ports {btn[1]}]
set_property -dict {PACKAGE_PIN B9 IOSTANDARD LVCMOS33} [get_ports {btn[2]}]
set_property -dict {PACKAGE_PIN B8 IOSTANDARD LVCMOS33} [get_ports {btn[3]}]


#USB-UART Interface

set_property -dict {PACKAGE_PIN D10 IOSTANDARD LVCMOS33} [get_ports UART_RXD]
set_property -dict {PACKAGE_PIN A9 IOSTANDARD LVCMOS33} [get_ports UART_TXD]


##Pmod Header JD

set_property -dict {PACKAGE_PIN D4 IOSTANDARD LVCMOS33} [get_ports JD_GPIO1]
set_property -dict {PACKAGE_PIN D3 IOSTANDARD LVCMOS33} [get_ports JD_GPIO7]
set_property -dict {PACKAGE_PIN F4 IOSTANDARD LVCMOS33} [get_ports JD_GPIO5]
set_property -dict {PACKAGE_PIN F3 IOSTANDARD LVCMOS33} [get_ports JD_GPIO3]
set_property -dict {PACKAGE_PIN E2 IOSTANDARD LVCMOS33} [get_ports JD_GPIO0]
set_property -dict {PACKAGE_PIN D2 IOSTANDARD LVCMOS33} [get_ports JD_GPIO6]
set_property -dict {PACKAGE_PIN H2 IOSTANDARD LVCMOS33} [get_ports JD_GPIO4]
set_property -dict {PACKAGE_PIN G2 IOSTANDARD LVCMOS33} [get_ports JD_GPIO2]



create_clock -period 20.000 -name CLK50 -waveform {0.000 10.000} -add
