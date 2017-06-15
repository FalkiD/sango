#set PROJECT [get_property DIRECTORY [current_project]]
# $PROJECT doesn't seem to work, evaluates to .
file copy -force C:/Work/FPGA/FPGA/Coop/S4/s4.runs/impl_1/s4.bit C:/Work/FPGA/FPGA/Coop/S4
file delete -force C:/Work/FPGA/FPGA/Coop/S4/*.prm
write_cfgmem  -format mcs -size 128 -interface SPIx4 -loadbit "up 0x00000000 C:/Work/FPGA/FPGA/Coop/S4/s4.bit " -force -file "C:/Work/FPGA/FPGA/Coop/S4/s4.mcs"
