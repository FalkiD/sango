## This file is a general constraints(.xdc) file for the S4 plasma ignition FPGA
## To use it in a project:
## - uncomment the lines corresponding to used pins
## - rename the used ports (in each line, after get_ports) according to the top level signal names in the project
##
## 25-Jun-2018  Begin adding missing timing constraints
##              Showed up as MMC offline when MCU/FPGA heat up, but still 20 degrees below max temp.
## 19-Jan-2018  Added multiboot support. Uncomment section for updated image build or 'golden' original
## 18-Mar-2018  Copied S4 file to create S6 file
##

# ---------------------------------------------------------------------------
# Master FPGA Clock Input
# ---------------------------------------------------------------------------

# Comment these lines to use FPGA_MCLK as main clock
#FPGA_CLK / FPGA_CLKn
#set_property -dict {PACKAGE_PIN D4 IOSTANDARD LVDS_25} [get_ports FPGA_CLK]
#create_clock -period 10.000 -name FPGA_CLK_pin -waveform {0.000 5.000} -add [get_ports FPGA_CLK]
#set_property -dict {PACKAGE_PIN C4 IOSTANDARD LVDS_25} [get_ports FPGA_CLKn]

# ---------------------------------------------------------------------------
# Multiboot config settings, golden image settings. Added 19-Jan-2018
# ---------------------------------------------------------------------------
#set_property BITSTREAM.CONFIG.CONFIGFALLBACK ENABLE [current_design]
#set_property BITSTREAM.CONFIG.NEXT_CONFIG_ADDR 0x0800000 [current_design]
#set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
#set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]

# ---------------------------------------------------------------------------
# Multiboot config settings, updated image settings. Added 19-Jan-2018
# ---------------------------------------------------------------------------
set_property BITSTREAM.CONFIG.CONFIGFALLBACK ENABLE [current_design]
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]

# ---------------------------------------------------------------------------
# MMC Interface I/Os
# ---------------------------------------------------------------------------

# 25-Jun-2018 Refactor to add missing constraints
set_property PACKAGE_PIN N11 [get_ports MMC_CLK]
set_property IOSTANDARD LVCMOS33 [get_ports MMC_CLK]
create_clock -period 19.231 -name mmc_clk -add [get_ports MMC_CLK]
# MMC clock signal -- The use of this property was "highly discouraged"    zzm01
#set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets {jb_IBUF[6]}]

set_property PACKAGE_PIN R7 [get_ports MMC_CMD]
set_property IOSTANDARD LVCMOS33 [get_ports MMC_CMD]

set_property PACKAGE_PIN R8 [get_ports MMC_DAT0]
set_property IOSTANDARD LVCMOS33 [get_ports MMC_DAT0]
set_property PACKAGE_PIN T7 [get_ports MMC_DAT1]
set_property IOSTANDARD LVCMOS33 [get_ports MMC_DAT1]
set_property PACKAGE_PIN T8 [get_ports MMC_DAT2]
set_property IOSTANDARD LVCMOS33 [get_ports MMC_DAT2]
set_property PACKAGE_PIN T9 [get_ports MMC_DAT3]
set_property IOSTANDARD LVCMOS33 [get_ports MMC_DAT3]
set_property PACKAGE_PIN T10 [get_ports MMC_DAT4]
set_property IOSTANDARD LVCMOS33 [get_ports MMC_DAT4]
set_property PACKAGE_PIN R5 [get_ports MMC_DAT5]
set_property IOSTANDARD LVCMOS33 [get_ports MMC_DAT5]
set_property PACKAGE_PIN T5 [get_ports MMC_DAT6]
set_property IOSTANDARD LVCMOS33 [get_ports MMC_DAT6]
set_property PACKAGE_PIN R6 [get_ports MMC_DAT7]
set_property IOSTANDARD LVCMOS33 [get_ports MMC_DAT7]

set_input_delay -max -clock mmc_clk 7.2 [get_ports MMC_DAT*]
set_input_delay -min -clock mmc_clk 5.2 [get_ports MMC_DAT*]
set_output_delay -max -clock mmc_clk 3.5 [get_ports MMC_DAT*]
set_output_delay -min -clock mmc_clk 15.9 [get_ports MMC_DAT*]

set_input_delay -max -clock mmc_clk 6.0 [get_ports MMC_CMD]
set_input_delay -min -clock mmc_clk 7.0 [get_ports MMC_CMD]
set_output_delay -max -clock mmc_clk 3.5 [get_ports MMC_CMD]
set_output_delay -min -clock mmc_clk 15.7 [get_ports MMC_CMD]

set_property PACKAGE_PIN P8 [get_ports MMC_IRQn]
set_property IOSTANDARD LVCMOS33 [get_ports MMC_IRQn]

# ---------------------------------------------------------------------------
# LPCMCU <--> FPGA Interface I/Os
# ---------------------------------------------------------------------------

set_property -dict {PACKAGE_PIN N14 IOSTANDARD LVCMOS33} [get_ports FPGA_MCLK]
create_clock -period 10.000 -name FPGA_MCLK -waveform {0.000 5.000} -add [get_ports FPGA_MCLK]

set_clock_groups -physically_exclusive -group mmc_clk -group FPGA_MCLK

# MCU_TRIG used as sys_rst
set_property PACKAGE_PIN T13 [get_ports MCU_TRIG]
set_property IOSTANDARD LVCMOS33 [get_ports MCU_TRIG]
set_input_delay 1.0 -clock [get_clocks mmc_clk] [get_ports MCU_TRIG]
set_false_path -from [get_ports MCU_TRIG] -to [all_registers]

# MMC_TRIG used to signal MCU on FPGA error
set_property PACKAGE_PIN N6 [get_ports MMC_TRIG]
set_property IOSTANDARD LVCMOS33 [get_ports MMC_TRIG]
set_output_delay 1.0 -clock [get_clocks mmc_clk] [get_ports MMC_TRIG]
set_false_path -to [get_ports MMC_TRIG]

set_property PACKAGE_PIN N16 [get_ports FPGA_TXD]
set_property IOSTANDARD LVCMOS33 [get_ports FPGA_TXD]
set_output_delay 1.0 -clock [get_clocks mmc_clk] [get_ports FPGA_TXD]
set_false_path -to [get_ports FPGA_TXD]

set_property PACKAGE_PIN P15 [get_ports FPGA_RXD]
set_property IOSTANDARD LVCMOS33 [get_ports FPGA_RXD]
set_input_delay 1.0 -clock [get_clocks mmc_clk] [get_ports FPGA_RXD]
set_false_path -from [get_ports FPGA_RXD] -to [all_registers]

set_property PACKAGE_PIN R11 [get_ports FPGA_TXD2]
set_property IOSTANDARD LVCMOS33 [get_ports FPGA_TXD2]
set_property PACKAGE_PIN R10 [get_ports FPGA_RXD2]
set_property IOSTANDARD LVCMOS33 [get_ports FPGA_RXD2]

set_property PACKAGE_PIN P10 [get_ports FPGA_MCU1]
set_property IOSTANDARD LVCMOS33 [get_ports FPGA_MCU1]
set_property PACKAGE_PIN P11 [get_ports FPGA_MCU2]
set_property IOSTANDARD LVCMOS33 [get_ports FPGA_MCU2]
set_property PACKAGE_PIN R12 [get_ports FPGA_MCU3]
set_property IOSTANDARD LVCMOS33 [get_ports FPGA_MCU3]
set_property PACKAGE_PIN R13 [get_ports FPGA_MCU4]
set_property IOSTANDARD LVCMOS33 [get_ports FPGA_MCU4]
set_output_delay 1.0 -clock [get_clocks mmc_clk] [get_ports FPGA_MCU*]
set_false_path -to [get_ports FPGA_MCU*]

# ---------------------------------------------------------------------------
# Board-Level GPIOs
# ---------------------------------------------------------------------------

set_property PACKAGE_PIN N13 [get_ports TRIG_IN]
set_property IOSTANDARD LVCMOS33 [get_ports TRIG_IN]
set_input_delay 1.0 -clock [get_clocks mmc_clk] [get_ports TRIG_IN]
set_false_path -from [get_ports TRIG_IN] -to [all_registers]
set_property PACKAGE_PIN M16 [get_ports TRIG_OUT]
set_property IOSTANDARD LVCMOS33 [get_ports TRIG_OUT]
set_output_delay 1.0 -clock [get_clocks mmc_clk] [get_ports TRIG_OUT]
set_false_path -to [get_ports TRIG_OUT]
set_property PACKAGE_PIN T14 [get_ports ACTIVE_LEDn]
set_property IOSTANDARD LVCMOS33 [get_ports ACTIVE_LEDn]
set_output_delay 1.0 -clock [get_clocks mmc_clk] [get_ports ACTIVE_LEDn]
set_false_path -to [get_ports ACTIVE_LEDn]

# ---------------------------------------------------------------------------
# Z_Mon I/Os
# ---------------------------------------------------------------------------

set_property PACKAGE_PIN T2 [get_ports ZMON_EN]
set_property IOSTANDARD LVCMOS33 [get_ports ZMON_EN]
set_output_delay 1.0 -clock [get_clocks mmc_clk] [get_ports ZMON_EN]
set_false_path -to [get_ports ZMON_EN]

set_property PACKAGE_PIN T12 [get_ports ADCTRIG]
set_property IOSTANDARD LVCMOS33 [get_ports ADCTRIG]
set_output_delay 1.0 -clock [get_clocks mmc_clk] [get_ports ADCTRIG]
set_false_path -to [get_ports ADCTRIG]

set_property PACKAGE_PIN M1 [get_ports CONV]
set_property IOSTANDARD LVCMOS33 [get_ports CONV]
set_output_delay 1.0 -clock [get_clocks mmc_clk] [get_ports CONV]
set_false_path -to [get_ports CONV]

set_property PACKAGE_PIN R1 [get_ports ADC_SCLK]
set_property IOSTANDARD LVCMOS33 [get_ports ADC_SCLK]
set_output_delay 1.0 -clock [get_clocks mmc_clk] [get_ports ADC_SCLK]
set_false_path -to [get_ports ADC_SCLK]

set_property PACKAGE_PIN N1 [get_ports ADCF_SDO]
set_property IOSTANDARD LVCMOS33 [get_ports ADCF_SDO]
set_input_delay 1.0 -clock [get_clocks mmc_clk] [get_ports ADCF_SDO]
set_false_path -from [get_ports ADCF_SDO] -to [all_registers]

set_property PACKAGE_PIN P1 [get_ports ADCR_SDO]
set_property IOSTANDARD LVCMOS33 [get_ports ADCR_SDO]
set_input_delay 1.0 -clock [get_clocks mmc_clk] [get_ports ADCR_SDO]
set_false_path -from [get_ports ADCR_SDO] -to [all_registers]

# ---------------------------------------------------------------------------
# Variable Gain I/Os
# ---------------------------------------------------------------------------

set_property PACKAGE_PIN B5 [get_ports VGA_SSn]
set_property IOSTANDARD LVCMOS33 [get_ports VGA_SSn]
set_output_delay 1.0 -clock [get_clocks mmc_clk] [get_ports VGA_SSn]
set_false_path -to [get_ports VGA_SSn]

set_property PACKAGE_PIN B6 [get_ports VGA_SCLK]
set_property IOSTANDARD LVCMOS33 [get_ports VGA_SCLK]
set_output_delay 1.0 -clock [get_clocks mmc_clk] [get_ports VGA_SCLK]
set_false_path -to [get_ports VGA_SCLK]

set_property PACKAGE_PIN B7 [get_ports VGA_MOSI]
set_property IOSTANDARD LVCMOS33 [get_ports VGA_MOSI]
set_output_delay 1.0 -clock [get_clocks mmc_clk] [get_ports VGA_MOSI]
set_false_path -to [get_ports VGA_MOSI]

set_property PACKAGE_PIN A5 [get_ports VGA_VSW]
set_property IOSTANDARD LVCMOS33 [get_ports VGA_VSW]
set_output_delay 1.0 -clock [get_clocks mmc_clk] [get_ports VGA_VSW]
set_false_path -to [get_ports VGA_VSW]

set_property PACKAGE_PIN A4 [get_ports VGA_VSWn]
set_property IOSTANDARD LVCMOS33 [get_ports VGA_VSWn]
set_output_delay 1.0 -clock [get_clocks mmc_clk] [get_ports VGA_VSWn]
set_false_path -to [get_ports VGA_VSWn]

# ---------------------------------------------------------------------------
# RF Gate & Enable I/Os
# ---------------------------------------------------------------------------

set_property PACKAGE_PIN A3 [get_ports DRV_BIAS_EN]
set_property IOSTANDARD LVCMOS33 [get_ports DRV_BIAS_EN]
set_output_delay 1.0 -clock [get_clocks mmc_clk] [get_ports DRV_BIAS_EN]
set_false_path -to [get_ports DRV_BIAS_EN]

set_property PACKAGE_PIN K2 [get_ports PA_BIAS_EN]
set_property IOSTANDARD LVCMOS33 [get_ports PA_BIAS_EN]
set_output_delay 1.0 -clock [get_clocks mmc_clk] [get_ports PA_BIAS_EN]
set_false_path -to [get_ports DRV_BIAS_EN]

set_property PACKAGE_PIN C2 [get_ports RF_GATE]
set_property IOSTANDARD LVCMOS33 [get_ports RF_GATE]
set_output_delay 1.0 -clock [get_clocks mmc_clk] [get_ports RF_GATE]
set_false_path -to [get_ports RF_GATE]

set_property PACKAGE_PIN C3 [get_ports RF_GATE2]
set_property IOSTANDARD LVCMOS33 [get_ports RF_GATE2]
set_output_delay 1.0 -clock [get_clocks mmc_clk] [get_ports RF_GATE2]
set_false_path -to [get_ports RF_GATE2]

# ---------------------------------------------------------------------------
# DDS (AD9954) SPI I/Os
# ---------------------------------------------------------------------------

set_property PACKAGE_PIN G1 [get_ports DDS_SSn]
set_property IOSTANDARD LVCMOS33 [get_ports DDS_SSn]
set_output_delay 1.0 -clock [get_clocks mmc_clk] [get_ports DDS_SSn]
set_false_path -to [get_ports DDS_SSn]

set_property PACKAGE_PIN G2 [get_ports DDS_SCLK]
set_property IOSTANDARD LVCMOS33 [get_ports DDS_SCLK]
set_output_delay 1.0 -clock [get_clocks mmc_clk] [get_ports DDS_SCLK]
set_false_path -to [get_ports DDS_SCLK]

set_property PACKAGE_PIN F2 [get_ports DDS_MOSI]
set_property IOSTANDARD LVCMOS33 [get_ports DDS_MOSI]
set_output_delay 1.0 -clock [get_clocks mmc_clk] [get_ports DDS_MOSI]
set_false_path -to [get_ports DDS_MOSI]

set_property PACKAGE_PIN E1 [get_ports DDS_MISO]
set_property IOSTANDARD LVCMOS33 [get_ports DDS_MISO]
set_input_delay 1.0 -clock [get_clocks mmc_clk] [get_ports DDS_MISO]
set_false_path -from [get_ports DDS_MISO] -to [all_registers]

set_property PACKAGE_PIN H2 [get_ports DDS_IORST]
set_property IOSTANDARD LVCMOS33 [get_ports DDS_IORST]
set_output_delay 1.0 -clock [get_clocks mmc_clk] [get_ports DDS_IORST]
set_false_path -to [get_ports DDS_IORST]

set_property PACKAGE_PIN H1 [get_ports DDS_IOUP]
set_property IOSTANDARD LVCMOS33 [get_ports DDS_IOUP]
set_output_delay 1.0 -clock [get_clocks mmc_clk] [get_ports DDS_IOUP]
set_false_path -to [get_ports DDS_IOUP]

set_property PACKAGE_PIN K1 [get_ports DDS_SYNC]
set_property IOSTANDARD LVCMOS33 [get_ports DDS_SYNC]
set_output_delay 1.0 -clock [get_clocks mmc_clk] [get_ports DDS_SYNC]
set_false_path -to [get_ports DDS_SYNC]

set_property PACKAGE_PIN J1 [get_ports DDS_PS0]
set_property IOSTANDARD LVCMOS33 [get_ports DDS_PS0]
set_output_delay 1.0 -clock [get_clocks mmc_clk] [get_ports DDS_PS0]
set_false_path -to [get_ports DDS_PS0]

set_property PACKAGE_PIN L2 [get_ports DDS_PS1]
set_property IOSTANDARD LVCMOS33 [get_ports DDS_PS1]
set_output_delay 1.0 -clock [get_clocks mmc_clk] [get_ports DDS_PS1]
set_false_path -to [get_ports DDS_PS1]

# ---------------------------------------------------------------------------
# Synth (LTC6946) SPI I/Os
# ---------------------------------------------------------------------------

set_property PACKAGE_PIN B1 [get_ports SYN_SSn]
set_property IOSTANDARD LVCMOS33 [get_ports SYN_SSn]
set_output_delay 1.0 -clock [get_clocks mmc_clk] [get_ports SYN_SSn]
set_false_path -to [get_ports SYN_SSn]

set_property PACKAGE_PIN C1 [get_ports SYN_SCLK]
set_property IOSTANDARD LVCMOS33 [get_ports SYN_SCLK]
set_output_delay 1.0 -clock [get_clocks mmc_clk] [get_ports SYN_SCLK]
set_false_path -to [get_ports SYN_SCLK]

set_property PACKAGE_PIN B2 [get_ports SYN_MOSI]
set_property IOSTANDARD LVCMOS33 [get_ports SYN_MOSI]
set_output_delay 1.0 -clock [get_clocks mmc_clk] [get_ports SYN_MOSI]
set_false_path -to [get_ports SYN_MOSI]

set_property PACKAGE_PIN A2 [get_ports SYN_MISO]
set_property IOSTANDARD LVCMOS33 [get_ports SYN_MISO]
set_input_delay 1.0 -clock [get_clocks mmc_clk] [get_ports SYN_MISO]
set_false_path -from [get_ports SYN_MISO] -to [all_registers]

set_property PACKAGE_PIN E2 [get_ports SYN_STAT]
set_property IOSTANDARD LVCMOS33 [get_ports SYN_STAT]
set_input_delay 1.0 -clock [get_clocks mmc_clk] [get_ports SYN_STAT]
set_false_path -from [get_ports SYN_STAT] -to [all_registers]

set_property PACKAGE_PIN D1 [get_ports SYN_MUTEn]
set_property IOSTANDARD LVCMOS33 [get_ports SYN_MUTEn]
set_output_delay 1.0 -clock [get_clocks mmc_clk] [get_ports SYN_MUTEn]
set_false_path -to [get_ports SYN_MUTEn]

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

set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 33 [current_design]
set_property CONFIG_MODE SPIx4 [current_design]
