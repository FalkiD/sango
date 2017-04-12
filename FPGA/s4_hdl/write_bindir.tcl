#set PROJECT [get_property DIRECTORY [current_project]]
# $PROJECT doesn't seem to work, evaluates to .
file copy -force C:/work/sango/s4-ctrl/hdl/s4_fpga.runs/impl_1/s4.bit C:/work/sango/s4-ctrl/hdl/bin
file delete -force C:/work/sango/s4-ctrl/hdl/bin/*.prm
write_cfgmem  -format mcs -size 128 -interface SPIx4 -loadbit "up 0x00000000 C:/work/sango/s4-ctrl/hdl/bin/s4.bit " -force -file "C:/work/sango/s4-ctrl/hdl/bin/s4.mcs"
