--
-- Test Bench
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.sd_host_pack.all;
use work.convert_pack.all;
use work.pull_pack_sim.all;
use work.block_ram_pack.all;
use work.sim_bus_control_port_pack.all;

--library xil_defaultlib;
--use xil_defaultlib.sim_control_pack.all;

entity testbench is
--
--the testbench is a closed entity
--
end testbench;

architecture struct of testbench is

  ----------------------------------------------------------------------
  -- NOTE: Some of these constants are duplicated inside the modules under test.
  --       Synthesizable code should not depend on simulation constants.
  ----------------------------------------------------------------------
  -- System Constants and Settings
  constant TEST_CLKRATE : integer := 500000000; -- The clock rate at which the stimulus logic runs
  constant DUT_CLKRATE  : integer := 100000000; -- The clock rate at which the test device runs

  ----------------------------------------------------------------------

  -- Component Declarations
  -----------------------------------
  component x7_main
  port (
    -- 100MHz clock from synthesiser
    FPGA_CLKP_i  : in    std_logic; -- 100 MHz input clock
    FPGA_CLKN_i  : in    std_logic;
    -- Asynchronous reset
    RESETN_i     : in    std_logic;
    -- signals between MCU and FPGA
    MISO_o       : out   std_logic;
    MOSI_i       : in    std_logic;
    SCLK_i       : in    std_logic;
    SPI_SSN_i    : in    std_logic;
    FLASH_SEL_i  : in    std_logic;
    MCU_CLK_i    : in    std_logic; -- currently unused
    -- SPI to synthesiser
    SYN_MISO_i   : in    std_logic;
    SYN_MOSI_o   : out   std_logic;
    SYN_SCLK_o   : out   std_logic;
    DDS_SSN_o    : out   std_logic;
    RSYN_SSN_o   : out   std_logic;
    FR_SSN_o     : out   std_logic;
    MSYN_SSN_o   : out   std_logic;
    MBW_SSN_o    : out   std_logic;
    -- DDS interface
    DDS_IORST_o  : out   std_logic;
    DDS_IOUP_o   : out   std_logic;
    DDS_SYNC_i   : in    std_logic;
    DDS_PS_o     : out   unsigned(2 downto 0);
    -- output module SPI interfaces
    CH_MISO_i    : in    unsigned(4 downto 1);
    CH_MOSI_o    : out   unsigned(4 downto 1);
    CH_SCLK_o    : out   unsigned(4 downto 1);
    CH_SSN_o     : out   unsigned(4 downto 1);
    CH_GATE_o    : out   unsigned(4 downto 1);
    BIASON_o     : out   unsigned(4 downto 1);
    CH_CTRL1_io  : inout unsigned(4 downto 1); -- currently unused
    CH_CTRL0_io  : inout unsigned(4 downto 1); -- currently unused
    -- interlocks, front panel
    EXT_UNLOCK_i : in    std_logic;
    RF_LED_GRN_o : out   std_logic;
    RF_LED_RED_o : out   std_logic;
    -- 667kHz switching regulator sync clock
    PSYNC_o      : out   std_logic;
    -- 24MHz clock output to USB hub XIN
    USB_CLK_o    : out   std_logic; -- currently unused
    -- RF on signals
    RF_IS_ON_o   : out   std_logic;
    RF_ON_i      : in    std_logic;
    -- external interfaces
    SYNCINX_i    : in    std_logic; -- Currently unused
    SYNCOUTX_o   : out   std_logic;
    -- PA interfaces
    CONV_o       : out   unsigned(4 downto 1);
    SCK_F_o      : out   unsigned(4 downto 1);
    SCK_R_o      : out   unsigned(4 downto 1);
    SDO_F_i      : in    unsigned(4 downto 1);
    SDO_R_i      : in    unsigned(4 downto 1);
    VBUS_EN_o    : out   unsigned(4 downto 1);
    TRIGX_i      : in    unsigned(4 downto 1);
    -- DDR3 interface
    A_o          : out   unsigned(14 downto 0);
    BA_o         : out   unsigned(2 downto 0);
    DQ_i         : inout unsigned(15 downto 0);
    DM_o         : out   unsigned(1 downto 0);
    DQS_o        : out   unsigned(1 downto 0);
    DQSN_o       : out   unsigned(1 downto 0);
    CSN_o        : out   std_logic;
    WEN_o        : out   std_logic;
    CASN_o       : out   std_logic;
    RASN_o       : out   std_logic;
    CK_o         : out   std_logic;
    CKN_o        : out   std_logic;
    CKE_o        : out   std_logic;
    ODT_o        : out   std_logic;
    -- MMC interface (FPGA acts as MMC slave)
    MMC_DAT_io   : inout unsigned(7 downto 0);
    MMC_CMD_io   : inout std_logic;
    MMC_CLK_i    : in    std_logic;
    MMC_IRQN_o   : out   std_logic
  );
end component;

  -----------------------------------------------------------------------------
  -- Internal signal declarations

    -- Common Signals
  signal sys_rst       : std_logic;
  signal sys_rst_n     : std_logic;
  signal sys_clk       : std_logic;
  signal dut_clk       : std_logic := '0';

    -- Signals from the bus control port
  signal ack     : std_logic;
  signal err     : std_logic;
  signal dat_rd  : unsigned(31 downto 0);
  signal dat_wr  : unsigned(31 downto 0);
  signal rst     : std_logic;
  signal stb     : std_logic;
  signal cyc     : std_logic;
  signal adr     : unsigned(31 downto 0);
  signal we      : std_logic;

  signal mmc_ram_we      : std_logic;
  signal mmc_ram_sel     : std_logic;
  signal mmc_ram_ack     : std_logic;
  signal mmc_ram_dat_rd  : unsigned(7 downto 0);

  -- Signals from unit under test, so they show up in testbench
  -- 100MHz clock from synthesiser
  signal FPGA_CLKP  : std_logic; -- 100 MHz input clock
  signal FPGA_CLKN  : std_logic;
  -- signals between MCU and FPGA
  signal MISO       : std_logic;
  signal MOSI       : std_logic;
  signal SCLK       : std_logic;
  signal SPI_SSN    : std_logic;
  signal FLASH_SEL  : std_logic;
  signal MCU_CLK    : std_logic;
  -- SPI to synthesiser
  signal SYN_MISO   : std_logic;
  signal SYN_MOSI   : std_logic;
  signal SYN_SCLK   : std_logic;
  signal DDS_SSN    : std_logic;
  signal RSYN_SSN   : std_logic;
  signal FR_SSN     : std_logic;
  signal MSYN_SSN   : std_logic;
  signal MBW_SSN    : std_logic;
  -- DDS interface
  signal DDS_IORST  : std_logic;
  signal DDS_IOUP   : std_logic;
  signal DDS_SYNC   : std_logic;
  signal DDS_PS     : unsigned(2 downto 0);
  -- output module SPI interfaces
  signal CH_MISO    : unsigned(4 downto 1);
  signal CH_MOSI    : unsigned(4 downto 1);
  signal CH_SCLK    : unsigned(4 downto 1);
  signal CH_SSN     : unsigned(4 downto 1);
  signal CH_GATE    : unsigned(4 downto 1);
  signal BIASON     : unsigned(4 downto 1);
  signal CH_CTRL1   : unsigned(4 downto 1); -- currently unused
  signal CH_CTRL0   : unsigned(4 downto 1); -- currently unused
    -- interlocks, front panel
  signal EXT_UNLOCK : std_logic;
  signal RF_LED_GRN : std_logic;
  signal RF_LED_RED : std_logic;
    -- 667kHz switching regulator sync clock
  signal PSYNC      : std_logic;
    -- 24MHz clock output to USB hub XIN
  signal USB_CLK    : std_logic; -- currently unused
    -- RF on signals
  signal RF_IS_ON   : std_logic;
  signal RF_ON      : std_logic;
    -- external interfaces
  signal SYNCINX    : std_logic; -- Currently unused
  signal SYNCOUTX   : std_logic;
    -- PA interfaces
  signal CONV       : unsigned(4 downto 1);
  signal SCK_F      : unsigned(4 downto 1);
  signal SCK_R      : unsigned(4 downto 1);
  signal SDO_F      : unsigned(4 downto 1);
  signal SDO_R      : unsigned(4 downto 1);
  signal VBUS_EN    : unsigned(4 downto 1);
  signal TRIGX      : unsigned(4 downto 1);
  -- DDR3 interface
  signal A          : unsigned(14 downto 0);
  signal BA         : unsigned(2 downto 0);
  signal DQ         : unsigned(15 downto 0);
  signal DM         : unsigned(1 downto 0);
  signal DQS        : unsigned(1 downto 0);
  signal DQSN       : unsigned(1 downto 0);
  signal CSN        : std_logic;
  signal WEN        : std_logic;
  signal CASN       : std_logic;
  signal RASN       : std_logic;
  signal CK         : std_logic;
  signal CKN        : std_logic;
  signal CKE        : std_logic;
  signal ODT        : std_logic;
  -- MMC interface (FPGA acts as MMC slave)
  signal MMC_DAT    : unsigned(7 downto 0);
  signal MMC_CMD    : std_logic;
  signal MMC_CLK    : std_logic;
  signal MMC_IRQN   : std_logic;

  -- Signals for mmc_0 card controller unit
    -- register access port
  signal mmc_0_reg_sel    : std_logic;
  signal mmc_0_reg_ack    : std_logic;
  signal mmc_0_reg_dat_rd : unsigned(31 downto 0);
    -- controller data port
  signal mmc_0_ctrlr_clk    : std_logic;
  signal mmc_0_ctrlr_dat_wr : unsigned(7 downto 0);
  signal mmc_0_ctrlr_dat_rd : unsigned(7 downto 0);
  signal mmc_0_ctrlr_adr    : unsigned(31 downto 0);
  signal mmc_0_ctrlr_we     : std_logic;
  signal mmc_0_ctrlr_cyc    : std_logic;
    --SD BUS
  signal mmc_cmd_wr       : std_logic;
  signal mmc_cmd_oe       : std_logic;
    --card_detect
  signal mmc_dat_wr       : unsigned(7 downto 0);
  signal mmc_dat_oe       : std_logic;
  signal mmc_dat_sz       : unsigned(1 downto 0);
  signal mmc_int_cmd      : std_logic;
  signal mmc_int_data     : std_logic;

begin

  ------------------------------------------------------------------------
  -- Set up low asserted reset
  sys_rst_n <= not sys_rst;

  ------------------------------------------------------------------------
  -- Set up independent DUT clock
  dut_clk_proc : process
    variable PS_PER_SECOND : real := 1.0E+12;
    variable half_period : time := integer(PS_PER_SECOND/(2.0*real(DUT_CLKRATE))) * 1 ps;
  begin
     --wait for 1/2 of the clock period;
     wait for half_period;
     dut_clk <= not dut_clk;
  end process;
  FPGA_CLKP <= dut_clk;
  FPGA_CLKN <= not dut_clk;

  ------------------------------------------------------------------------
  -- Instantiate a bus control port
  cp0 : sim_bus_control_port
  generic map(
    -- relating to file I/O
    INPUT_FILE      => "bus_sim_in.txt",
    OUTPUT_FILE     => "bus_sim_out.txt",
    POR_DURATION    => 500 ns,  -- Duration of internal reset signal activity
    POR_ASSERT_LOW  => false,  -- Determines polarity of reset output
    CLKRATE         => TEST_CLKRATE, -- Control Port clock rate default.
    LINE_LENGTH     => 80,  -- Length of buffer to hold file input bytes
    -- relating to the bus controller
    ADR_DIGITS      =>   8, -- # of hex digits for address
    DAT_DIGITS      =>   8, -- # of hex digits for data
    QTY_DIGITS      =>   2, -- # of hex digits for quantity
    CMD_BUFFER_SIZE =>  32, -- # of chars in the command buffer
    WATCHDOG_VALUE  => 200, -- # of sys_clks before ack is expected
    DISPLAY_FIELDS  =>   8  -- # of fields/line
  )
  port map(
    -- Clock and reset stimulus
    test_rst => sys_rst,
    test_clk => sys_clk,

    -- System Bus IO
    ack_i    => ack,
    err_i    => err,
    dat_i    => dat_rd,
    dat_o    => dat_wr,
    rst_o    => rst,
    stb_o    => stb,
    cyc_o    => cyc,
    adr_o    => adr,
    we_o     => we
  );

  mmc_0_reg_sel <= '1' when cyc='1' and adr(31 downto 4)=16#0300000# else '0';
  mmc_ram_sel   <= '1' when cyc='1' and adr(31 downto 16)=16#0400# and adr(15 downto 13)=0 else '0';

  dat_rd <= mmc_0_reg_dat_rd            when mmc_0_reg_sel='1' else
            u_resize(mmc_ram_dat_rd,32) when mmc_ram_sel='1'   else
            str2u("12340000",32);

  ack <= mmc_0_reg_ack when mmc_0_reg_sel='1' else 
         mmc_ram_ack when mmc_ram_sel='1' else
         '0';
  err <= '0' when mmc_0_reg_sel='1' or mmc_ram_sel='1' else '1';


  -- Create a Block RAM which the SD/MMC controller uses as a data
  -- storage area.
  -- The 'A' port is attached to the simulation bus controller
  -- The 'B' port is attached to the mmc controller
  mmc_ram_we <= '1' when mmc_ram_sel='1' and we='1' else '0';
  mmc_ram_0 : swiss_army_ram
    generic map(
      USE_BRAM  => 1, -- Set to nonzero value for BRAM, zero for distributed RAM
      WRITETHRU => 0, -- Set to nonzero value for writethrough mode
      USE_FILE  => 1, -- Set to nonzero value to use INIT_FILE
      INIT_VAL  => 16#00#, -- Value used when INIT_FILE is not used
      INIT_SEL  => 0, -- Selects which segment of (larger) INIT_FILE to use
      INIT_FILE => "mmc_ram_init.txt", -- ASCII hexadecimal initialization file name
      FIL_WIDTH =>  8, -- Bit width of init file lines
      ADR_WIDTH => 13,
      DAT_WIDTH =>  8
    )
    port map(
      clk_a    => sys_clk,
      adr_a_i  => adr(12 downto 0),
      we_a_i   => mmc_ram_we,
--      en_a_i   => mmc_ram_sel,
      en_a_i   => '1',
      dat_a_i  => dat_wr(7 downto 0),
      dat_a_o  => mmc_ram_dat_rd,
       
      clk_b    => mmc_0_ctrlr_clk,
      adr_b_i  => mmc_0_ctrlr_adr(12 downto 0),
      we_b_i   => mmc_0_ctrlr_we,
--      en_b_i   => mmc_0_ctrlr_cyc,
      en_b_i   => '1',
      dat_b_i  => mmc_0_ctrlr_dat_wr,
      dat_b_o  => mmc_0_ctrlr_dat_rd
    );
-- system side BRAM ack signal needs to be delayed by 1 cycle,
-- to allow for the BRAM to respond to the given address.
process(sys_rst_n,sys_clk)
begin
  if (sys_rst_n='0') then
    mmc_ram_ack <= '0';
  elsif (sys_clk'event and sys_clk='1') then
    mmc_ram_ack <= mmc_ram_sel;
  end if;
end process;

  -- Instantiate an MMC Card controller
  mmc_ctrlr_0 : sd_controller_8bit_bram
  port map(
    -- WISHBONE common
    wb_clk_i     => sys_clk,
    wb_rst_i     => sys_rst,
    -- WISHBONE slave
    wb_dat_i     => dat_wr,
    wb_dat_o     => mmc_0_reg_dat_rd,
    wb_adr_i     => adr(3 downto 0),
    wb_we_i      => we,
    wb_cyc_i     => mmc_0_reg_sel,
    wb_ack_o     => mmc_0_reg_ack,
    -- Dedicated BRAM port without acknowledge.
    -- Access cycles must complete immediately.
    -- (data to cross clock domains by this dual-ported BRAM)
    bram_clk_o   => mmc_0_ctrlr_clk, -- Same as wb_clk_i
    bram_dat_o   => mmc_0_ctrlr_dat_wr,
    bram_dat_i   => mmc_0_ctrlr_dat_rd,
    bram_adr_o   => mmc_0_ctrlr_adr,
    bram_we_o    => mmc_0_ctrlr_we,
    bram_cyc_o   => mmc_0_ctrlr_cyc,
    --SD Card Interface
    sd_cmd_i     => mmc_cmd,
    sd_cmd_o     => mmc_cmd_wr,
    sd_cmd_oe_o  => mmc_cmd_oe,
    sd_dat_i     => mmc_dat,
    sd_dat_o     => mmc_dat_wr,
    sd_dat_oe_o  => mmc_dat_oe,
    sd_dat_siz_o => mmc_dat_sz,
    sd_clk_o_pad => mmc_clk,
    -- Interrupt outputs
    int_cmd_o    => mmc_int_cmd,
    int_data_o   => mmc_int_data
  );

  -- Drive MMC command, a tri-state signal
  mmc_cmd <= mmc_cmd_wr when mmc_cmd_oe='1' else 'Z';

  -- Drive MMC data, a tri-state signal bus
  mmc_dat(0) <= mmc_dat_wr(0) when mmc_dat_oe='1' else 'Z';
  mmc_dat(3 downto 1) <= mmc_dat_wr(3 downto 1) when mmc_dat_oe='1' and mmc_dat_sz>0 else (others=>'Z');
  mmc_dat(7 downto 4) <= mmc_dat_wr(7 downto 4) when mmc_dat_oe='1' and mmc_dat_sz>1 else (others=>'Z');

  ------------------------------------------------------------------------
  -- Instantiate Unit Under Test
  dut0: x7_main
  port map(
    -- 100MHz clock from synthesiser
    FPGA_CLKP_i  => FPGA_CLKP, -- 100 MHz input clock
    FPGA_CLKN_i  => FPGA_CLKN,
    -- Asynchronous reset
    RESETN_i     => sys_rst_n,
    -- signals between MCU and FPGA
    MISO_o       => MISO,
    MOSI_i       => MOSI,
    SCLK_i       => SCLK,
    SPI_SSN_i    => SPI_SSN,
    FLASH_SEL_i  => FLASH_SEL,
    MCU_CLK_i    => MCU_CLK, -- currently unused
    -- SPI to synthesiser
    SYN_MISO_i   => SYN_MISO,
    SYN_MOSI_o   => SYN_MOSI,
    SYN_SCLK_o   => SYN_SCLK,
    DDS_SSN_o    => DDS_SSN,
    RSYN_SSN_o   => RSYN_SSN,
    FR_SSN_o     => FR_SSN,
    MSYN_SSN_o   => MSYN_SSN,
    MBW_SSN_o    => MBW_SSN,
    -- DDS interface
    DDS_IORST_o  => DDS_IORST,
    DDS_IOUP_o   => DDS_IOUP,
    DDS_SYNC_i   => DDS_SYNC,
    DDS_PS_o     => DDS_PS,
    -- output module SPI interfaces
    CH_MISO_i    => CH_MISO,
    CH_MOSI_o    => CH_MOSI,
    CH_SCLK_o    => CH_SCLK,
    CH_SSN_o     => CH_SSN,
    CH_GATE_o    => CH_GATE,
    BIASON_o     => BIASON,
    CH_CTRL1_io  => CH_CTRL1, -- currently unused
    CH_CTRL0_io  => CH_CTRL0, -- currently unused
    -- interlocks, front panel
    EXT_UNLOCK_i => EXT_UNLOCK,
    RF_LED_GRN_o => RF_LED_GRN,
    RF_LED_RED_o => RF_LED_RED,
    -- 667kHz switching regulator sync clock
    PSYNC_o      => PSYNC,
    -- 24MHz clock output to USB hub XIN
    USB_CLK_o    => USB_CLK, -- currently unused
    -- RF on signals
    RF_IS_ON_o   => RF_IS_ON,
    RF_ON_i      => RF_ON,
    -- external interfaces
    SYNCINX_i    => SYNCINX, -- Currently unused
    SYNCOUTX_o   => SYNCOUTX,
    -- PA interfaces
    CONV_o       => CONV,
    SCK_F_o      => SCK_F,
    SCK_R_o      => SCK_R,
    SDO_F_i      => SDO_F,
    SDO_R_i      => SDO_R,
    VBUS_EN_o    => VBUS_EN,
    TRIGX_i      => TRIGX,
    -- DDR3 interface
    A_o          => A,
    BA_o         => BA,
    DQ_i         => DQ,
    DM_o         => DM,
    DQS_o        => DQS,
    DQSN_o       => DQSN,
    CSN_o        => CSN,
    WEN_o        => WEN,
    CASN_o       => CASN,
    RASN_o       => RASN,
    CK_o         => CK,
    CKN_o        => CKN,
    CKE_o        => CKE,
    ODT_o        => ODT,
    -- MMC interface (FPGA acts as MMC slave)
    MMC_DAT_io   => MMC_DAT,
    MMC_CMD_io   => MMC_CMD,
    MMC_CLK_i    => MMC_CLK,
    MMC_IRQN_o   => MMC_IRQN
  );

-- Apply pullups to unused FPGA inputs
pu0 : pullup1 port map(pin => MOSI);
pu1 : pullup1 port map(pin => SCLK);
pu2 : pullup1 port map(pin => SPI_SSN);
pu3 : pullup1 port map(pin => FLASH_SEL);
pu4 : pullup1 port map(pin => MCU_CLK);
pu5 : pullup1 port map(pin => SYN_MISO);
pu6 : pullup1 port map(pin => DDS_SYNC);

multi_pu_loop: for i in 4 downto 1 GENERATE
  i_pu  : pullup1 PORT MAP (pin => CH_MISO(i));
  i_pd  : pulldn1 PORT MAP (pin => SDO_F(i));
  i_pd2 : pulldn1 PORT MAP (pin => SDO_R(i));
  i_pd3 : pulldn1 PORT MAP (pin => TRIGX(i));
END GENERATE multi_pu_loop;

pu7 : pullup1 port map(pin => EXT_UNLOCK);
pu8 : pullup1 port map(pin => RF_ON);
pu9 : pullup1 port map(pin => SYNCINX);

-- NOTE: Add pullups on MMC_CMD and MMC_DAT, since we are through
--       benefitting from seeing the 'Z' in simulation.  The true card
--       interface has pullups...
pu10 : pullup1 port map(pin => MMC_CMD);
multi_pu_loop2: for i in 0 to 7 GENERATE
  i_pu  : pullup1 PORT MAP (pin => MMC_DAT(i));
END GENERATE multi_pu_loop2;

end struct;