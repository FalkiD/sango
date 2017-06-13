## This file is a general .xdc for the Ampleon S4 FPGA
## To use it in a project:
## - uncomment the lines corresponding to used pins
## - rename the used ports (in each line, after get_ports) according to the top level signal names in the project


# ---------------------------------------------------------------------------
# Master FPGA Clock Input
# ---------------------------------------------------------------------------

#FPGA_CLK / FPGA_CLKn
//set_property -dict {PACKAGE_PIN D4 IOSTANDARD LVDS_25} [get_ports FPGA_CLK]
//create_clock -period 10.000 -name FPGA_CLK_pin -waveform {0.000 5.000} -add [get_ports FPGA_CLK]
//set_property -dict {PACKAGE_PIN C4 IOSTANDARD LVDS_25} [get_ports FPGA_CLKn]

# ---------------------------------------------------------------------------
# MMC Interface I/Os
# ---------------------------------------------------------------------------

set_property PACKAGE_PIN R8 [get_ports {MMC_DAT0}]
set_property IOSTANDARD LVCMOS33 [get_ports {MMC_DAT0}]
set property PULLUP [get_ports {MMC_DAT0}]
set_property PACKAGE_PIN T7 [get_ports {MMC_DAT1}]
set_property IOSTANDARD LVCMOS33 [get_ports {MMC_DAT1}]
set property PULLUP [get_ports {MMC_DAT1}]
set_property PACKAGE_PIN T8 [get_ports {MMC_DAT2}]
set_property IOSTANDARD LVCMOS33 [get_ports {MMC_DAT2}]
set property PULLUP [get_ports {MMC_DAT2}]
set_property PACKAGE_PIN T9 [get_ports {MMC_DAT3}]
set_property IOSTANDARD LVCMOS33 [get_ports {MMC_DAT3}]
set property PULLUP [get_ports {MMC_DAT3}]
set_property PACKAGE_PIN T10 [get_ports {MMC_DAT4}]
set_property IOSTANDARD LVCMOS33 [get_ports {MMC_DAT4}]
set property PULLUP [get_ports {MMC_DAT4}]
set_property PACKAGE_PIN R5 [get_ports {MMC_DAT5}]
set_property IOSTANDARD LVCMOS33 [get_ports {MMC_DAT5}]
set property PULLUP [get_ports {MMC_DAT5}]
set_property PACKAGE_PIN T5 [get_ports {MMC_DAT6}]
set_property IOSTANDARD LVCMOS33 [get_ports {MMC_DAT6}]
set property PULLUP [get_ports {MMC_DAT6}]
set_property PACKAGE_PIN R6 [get_ports {MMC_DAT7}]
set_property IOSTANDARD LVCMOS33 [get_ports {MMC_DAT7}]
set property PULLUP [get_ports {MMC_DAT7}]

set_property PACKAGE_PIN R7 [get_ports {MMC_CMD}]
set_property IOSTANDARD LVCMOS33 [get_ports {MMC_CMD}]

set_property PACKAGE_PIN P8 [get_ports {MMC_IRQn}]
set_property IOSTANDARD LVCMOS33 [get_ports {MMC_IRQn}]

set_property PACKAGE_PIN N11 [get_ports {MMC_CLK}]
set_property IOSTANDARD LVCMOS33 [get_ports {MMC_CLK}]
# MMC clock signal -- The use of this property was "highly discouraged"    zzm01
#set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets {jb_IBUF[6]}]


# ---------------------------------------------------------------------------
# LPCMCU <--> FPGA Interface I/Os
# ---------------------------------------------------------------------------

set_property -dict {PACKAGE_PIN N14 IOSTANDARD LVCMOS33} [get_ports FPGA_MCLK]
//create_clock -period 10.000 -name FPGA_MCLK -waveform {0.000 5.000} -add [get_ports FPGA_MCLK]

set_property PACKAGE_PIN T13 [get_ports {MCU_TRIG}]
set_property IOSTANDARD LVCMOS33 [get_ports {MCU_TRIG}]

set_property PACKAGE_PIN N16 [get_ports {FPGA_TXD}]
set_property IOSTANDARD LVCMOS33 [get_ports {FPGA_TXD}]
set_property PACKAGE_PIN P15 [get_ports {FPGA_RXD}]
set_property IOSTANDARD LVCMOS33 [get_ports {FPGA_RXD}]

set_property PACKAGE_PIN R11 [get_ports {FPGA_TXD2}]
set_property IOSTANDARD LVCMOS33 [get_ports {FPGA_TXD2}]
set_property PACKAGE_PIN R10 [get_ports {FPGA_RXD2}]
set_property IOSTANDARD LVCMOS33 [get_ports {FPGA_RXD2}]

set_property PACKAGE_PIN P10 [get_ports {FPGA_MCU1}]
set_property IOSTANDARD LVCMOS33 [get_ports {FPGA_MCU1}]
create_clock -period 100.000 -name FPGA_CLK_pin -waveform {0.000 50.000} -add [get_ports FPGA_MCU1]
set_property PACKAGE_PIN P11 [get_ports {FPGA_MCU2}]
set_property IOSTANDARD LVCMOS33 [get_ports {FPGA_MCU2}]
set_property PACKAGE_PIN R12 [get_ports {FPGA_MCU3}]
set_property IOSTANDARD LVCMOS33 [get_ports {FPGA_MCU3}]
set_property PACKAGE_PIN R13 [get_ports {FPGA_MCU4}]
set_property IOSTANDARD LVCMOS33 [get_ports {FPGA_MCU4}]

# ---------------------------------------------------------------------------
# Board-Level GPIOs
# ---------------------------------------------------------------------------

set_property PACKAGE_PIN N13 [get_ports {TRIG_IN}]
set_property IOSTANDARD LVCMOS33 [get_ports {TRIG_IN}]
set_property PACKAGE_PIN M16 [get_ports {TRIG_OUT}]
set_property IOSTANDARD LVCMOS33 [get_ports {TRIG_OUT}]
set_property PACKAGE_PIN T14 [get_ports {ACTIVE_LEDn}]
set_property IOSTANDARD LVCMOS33 [get_ports {ACTIVE_LEDn}]


# ---------------------------------------------------------------------------
# Z_Mon I/Os
# ---------------------------------------------------------------------------

set_property PACKAGE_PIN T2 [get_ports {ZMON_EN}]
set_property IOSTANDARD LVCMOS33 [get_ports {ZMON_EN}]
set_property PACKAGE_PIN T12 [get_ports {ADCTRIG}]
set_property IOSTANDARD LVCMOS33 [get_ports {ADCTRIG}]
set_property PACKAGE_PIN M1 [get_ports {CONV}]
set_property IOSTANDARD LVCMOS33 [get_ports {CONV}]
set_property PACKAGE_PIN R1 [get_ports {ADC_SCLK}]
set_property IOSTANDARD LVCMOS33 [get_ports {ADC_SCLK}]
set_property PACKAGE_PIN N1 [get_ports {ADCF_SDO}]
set_property IOSTANDARD LVCMOS33 [get_ports {ADCF_SDO}]
set_property PACKAGE_PIN P1 [get_ports {ADCR_SDO}]
set_property IOSTANDARD LVCMOS33 [get_ports {ADCR_SDO}]


# ---------------------------------------------------------------------------
# Variable Gain I/Os
# ---------------------------------------------------------------------------

set_property PACKAGE_PIN B5 [get_ports {VGA_SSn}]
set_property IOSTANDARD LVCMOS33 [get_ports {VGA_SSn}]
set_property PACKAGE_PIN B6 [get_ports {VGA_SCLK}]
set_property IOSTANDARD LVCMOS33 [get_ports {VGA_SCLK}]
set_property PACKAGE_PIN B7 [get_ports {VGA_MOSI}]
set_property IOSTANDARD LVCMOS33 [get_ports {VGA_MOSI}]
set_property PACKAGE_PIN A5 [get_ports {VGA_VSW}]
set_property IOSTANDARD LVCMOS33 [get_ports {VGA_VSW}]
set_property PACKAGE_PIN A4 [get_ports {VGA_VSWn}]
set_property IOSTANDARD LVCMOS33 [get_ports {VGA_VSWn}]


# ---------------------------------------------------------------------------
# RF Gate & Enable I/Os
# ---------------------------------------------------------------------------

set_property PACKAGE_PIN A3 [get_ports {DRV_BIAS_EN}]
set_property IOSTANDARD LVCMOS33 [get_ports {DRV_BIAS_EN}]
set_property PACKAGE_PIN K2 [get_ports {PA_BIAS_EN}]
set_property IOSTANDARD LVCMOS33 [get_ports {PA_BIAS_EN}]
set_property PACKAGE_PIN C2 [get_ports {RF_GATE}]
set_property IOSTANDARD LVCMOS33 [get_ports {RF_GATE}]
set_property PACKAGE_PIN C3 [get_ports {RF_GATE2}]
set_property IOSTANDARD LVCMOS33 [get_ports {RF_GATE2}]


# ---------------------------------------------------------------------------
# DDS (AD9954) SPI I/Os
# ---------------------------------------------------------------------------

set_property PACKAGE_PIN G1 [get_ports {DDS_SSn}]
set_property IOSTANDARD LVCMOS33 [get_ports {DDS_SSn}]
set_property PACKAGE_PIN G2 [get_ports {DDS_SCLK}]
set_property IOSTANDARD LVCMOS33 [get_ports {DDS_SCLK}]
set_property PACKAGE_PIN F2 [get_ports {DDS_MOSI}]
set_property IOSTANDARD LVCMOS33 [get_ports {DDS_MOSI}]
set_property PACKAGE_PIN E1 [get_ports {DDS_MISO}]
set_property IOSTANDARD LVCMOS33 [get_ports {DDS_MISO}]
set_property PACKAGE_PIN H2 [get_ports {DDS_IORST}]
set_property IOSTANDARD LVCMOS33 [get_ports {DDS_IORST}]
set_property PACKAGE_PIN J1 [get_ports {DDS_IOUP}]
set_property IOSTANDARD LVCMOS33 [get_ports {DDS_IOUP}]
set_property PACKAGE_PIN K1 [get_ports {DDS_SYNC}]
set_property IOSTANDARD LVCMOS33 [get_ports {DDS_SYNC}]
set_property PACKAGE_PIN L2 [get_ports {DDS_PS0}]
set_property IOSTANDARD LVCMOS33 [get_ports {DDS_PS0}]
set_property PACKAGE_PIN H1 [get_ports {DDS_PS1}]
set_property IOSTANDARD LVCMOS33 [get_ports {DDS_PS1}]


# ---------------------------------------------------------------------------
# Synth (LTC6946) SPI I/Os
# ---------------------------------------------------------------------------

set_property PACKAGE_PIN B1 [get_ports {SYN_SSn}]
set_property IOSTANDARD LVCMOS33 [get_ports {SYN_SSn}]
set_property PACKAGE_PIN C1 [get_ports {SYN_SCLK}]
set_property IOSTANDARD LVCMOS33 [get_ports {SYN_SCLK}]
set_property PACKAGE_PIN A2 [get_ports {SYN_MOSI}]
set_property IOSTANDARD LVCMOS33 [get_ports {SYN_MOSI}]
set_property PACKAGE_PIN B2 [get_ports {SYN_MISO}]
set_property IOSTANDARD LVCMOS33 [get_ports {SYN_MISO}]
set_property PACKAGE_PIN E2 [get_ports {SYN_STAT}]
set_property IOSTANDARD LVCMOS33 [get_ports {SYN_STAT}]
set_property PACKAGE_PIN D1 [get_ports {SYN_MUTE}]
set_property IOSTANDARD LVCMOS33 [get_ports {SYN_MUTE}]




# ---------------------------------------------------------------------------
# Quad SPI Flash
# ---------------------------------------------------------------------------

#set_property -dict { PACKAGE_PIN L12   IOSTANDARD LVCMOS33 } [get_ports { qspi_cs }]; #IO_L6P_T0_FCS_B_14 Sch=qspi_cs
#set_property -dict { PACKAGE_PIN J13   IOSTANDARD LVCMOS33 } [get_ports { qspi_dq[0] }]; #IO_L1P_T0_D00_MOSI_14 Sch=qspi_dq[0]
#set_property -dict { PACKAGE_PIN J14   IOSTANDARD LVCMOS33 } [get_ports { qspi_dq[1] }]; #IO_L1N_T0_D01_DIN_14 Sch=qspi_dq[1]
#set_property -dict { PACKAGE_PIN K15   IOSTANDARD LVCMOS33 } [get_ports { qspi_dq[2] }]; #IO_L2P_T0_D02_14 Sch=qspi_dq[2]
#set_property -dict { PACKAGE_PIN K16   IOSTANDARD LVCMOS33 } [get_ports { qspi_dq[3] }]; #IO_L2N_T0_D03_14 Sch=qspi_dq[3]




# ---------------------------------------------------------------------------
# FPGA Chip-Level Config Constraints
# ---------------------------------------------------------------------------

set_property BITSTREAM.CONFIG.CONFIGRATE 33 [current_design]
set_property CONFIG_MODE SPIx4 [current_design]
