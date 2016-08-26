#/usr/bin/bash
fuse --incremental -d SYNTHESIS -L "unisims_ver" -i "../rtl" -prj "tg_test.prj" "work.glbl" "work.tg_test" -o "tg_test.exe" && ./tg_test.exe -tclbatch emc_test.do
