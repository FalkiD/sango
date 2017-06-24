#
# V1.0
# 17-Jun-2017 Created tcl.post script
# RMR
#
# Copies s4.bit output file to bin directory off the
# main project directory.
# Executes write_cfgmem to create companion s4.mcs file
#
# For the S4 the companion memory device is:
# The companion memory device is:
# Micron n25q128-3.3v-spi-x1_x2_x4
#
set PRJDIR [get_property DIRECTORY [current_project]]
set RUNDIR [get_property DIRECTORY [current_run]]
puts $PRJDIR
puts $RUNDIR
set BITFILE $RUNDIR/s4.bit
puts $BITFILE
file copy -force $BITFILE $PRJDIR/bin
set PRMFILE $PRJDIR/bin/*.prm
puts $PRMFILE
file delete -force $PRMFILE
write_cfgmem -format mcs -size 128 -interface SPIx4 -loadbit "up 0x00000000 $PRJDIR/bin/s4.bit " -force -file "$PRJDIR/bin/s4.mcs"
