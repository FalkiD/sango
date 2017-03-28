//------------------------------------------------------------------------


  assign UART_RSP_o = SW[3]?mmc_tlm:syscon_rsp;


  // Implement MMC card tri-state drivers at the top level
    // Drive the clock output when needed
  assign MMC_CLK_io = mmc_clk_oe?mmc_clk:1'bZ;
    // Select which data vector to use
  assign mmc_dat_choice1 = mmc_od_mode?mmc_dat_zzz:mmc_dat;
  assign mmc_dat_choice2 = mmc_dat_oe?mmc_dat_choice1:8'bZ;
    // Create mmc command signals
  assign mmc_cmd_zzz    = mmc_cmd?1'bZ:1'b0;
  assign mmc_cmd_choice = mmc_od_mode?mmc_cmd_zzz:mmc_cmd;
  assign MMC_CMD_io = mmc_cmd_oe?mmc_cmd_choice:1'bZ;
    // Create "open drain" data vector
  genvar j;
  for(j=0;j<8;j=j+1) begin
    assign mmc_dat_zzz[j] = mmc_dat[j]?1'bZ:1'b0;
  end
    // Select which data vector to use
  assign mmc_dat_choice1 = mmc_od_mode?mmc_dat_zzz:mmc_dat;
  assign mmc_dat_choice2 = mmc_dat_oe?mmc_dat_choice1:8'bZ;
    // Use always block for readability
  always @(mmc_dat_siz, mmc_dat_choice2)
         if (mmc_dat_siz==0) mmc_dat_choice3 <= {7'bZ,mmc_dat_choice2[0]};
    else if (mmc_dat_siz==1) mmc_dat_choice3 <= {4'bZ,mmc_dat_choice2[3:0]};
    else                     mmc_dat_choice3 <= mmc_dat_choice2;

  assign MMC_DAT_io = mmc_dat_choice3;

  // Map the MMC I/O proxies to actual I/O signals
  assign jb[6] = MMC_CLK_io;
  assign jb[2] = MMC_CMD_io;
  assign jc[4] = MMC_DAT_io[0];
  assign jc[0] = MMC_DAT_io[1];
  assign jc[7] = MMC_DAT_io[2];
  assign jc[3] = MMC_DAT_io[3];
  assign jc[6] = MMC_DAT_io[4];
  assign jc[2] = MMC_DAT_io[5];
  assign jc[5] = MMC_DAT_io[6];
  assign jc[1] = MMC_DAT_io[7];

  // Map the MMC input proxies to actual I/O signals
  assign MMC_CLK_i = jb[6];
  assign MMC_CMD_i = jb[2];
  assign MMC_DAT_i = {jc[1], jc[5], jc[2], jc[6], jc[3], jc[7], jc[0], jc[4]};

endmodule
