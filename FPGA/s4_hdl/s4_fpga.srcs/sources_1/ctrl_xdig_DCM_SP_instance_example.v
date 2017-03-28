//   double 100MHz input clock to internal 200MHz clock
  DCM_SP #(.CLKDV_DIVIDE(10), .CLKIN_PERIOD("10ns"), .CLK_FEEDBACK("1X"), .PHASE_SHIFT(0),
           .CLKOUT_PHASE_SHIFT("FIXED"), .STARTUP_WAIT("TRUE"), .CLKIN_DIVIDE_BY_2("FALSE"))
  DCM_clk (.CLK0(clk0), .CLKDV(clkdv), .CLKFB(clk), .CLKIN(clkin), .CLK2X(clk2x), .RST(RST),
           .LOCKED(GPIO519));
