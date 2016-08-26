#/usr/bin/bash
fuse --incremental -v -d SYNTHESIS -L "unisims_ver" -i "../rtl" -prj "reg_test.prj" "work.glbl" "work.reg_test" -o "reg_test.exe" && ./reg_test.exe -tclbatch emc_test.do
