
 add_fsm_encoding \
       {async_rx_sqclk.rx_state} \
       { }  \
       {{000 000} {001 001} {010 010} {011 011} {100 100} }

 add_fsm_encoding \
       {sd_cmd_host.serial_state} \
       { }  \
       {{000 000} {001 001} {010 010} {011 011} {100 100} {101 101} {110 110} }

 add_fsm_encoding \
       {s4.spi_state} \
       { }  \
       {{0000 000} {0010 001} {0011 010} {0100 011} {1111 100} }
