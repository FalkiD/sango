#/usr/bin/bash
fuse --incremental -L "unisims_ver" -prj "emc_test.prj" "work.emc_test" -o "emc_test.exe"
./emc_test.exe -tclbatch emc_test.do
