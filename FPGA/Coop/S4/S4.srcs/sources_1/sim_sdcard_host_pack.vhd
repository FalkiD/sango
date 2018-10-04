--------------------------------------------------------------------------
--------------------------------------------------------------------------
-- Package containing SD Card host module, for simulation support.
--
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library work;
use work.sd_host_pack.all;

package sim_sdcard_host_pack is

  component sim_sdcard_host
  generic (
    -- relating to file I/O
    INPUT_FILE          : string  := "./bus_sim_in.txt";
    OUTPUT_FILE         : string  := "./bus_sim_out.txt";
    -- relating to the sdcard_host
    HOST_RAM_INIT_FILE  : string  := "./host_ram_init.txt";
    HOST_RAM_ADR_BITS   : natural := 14          -- Determines amount of BRAM for sdcard_host
  );
  port (

    -- Asynchronous system reset and system clock
    sys_rst_n      : in  std_logic;
    sys_clk        : in  std_logic;

    -- SD/MMC card signals
    mmc_clk_o      : out std_logic;
    mmc_cmd_i      : in  std_logic;
    mmc_cmd_o      : out std_logic;
    mmc_cmd_oe_o   : out std_logic;
    mmc_dat_i      : in  unsigned(7 downto 0);
    mmc_dat_o      : out unsigned(7 downto 0);
    mmc_dat_oe_o   : out std_logic;
    mmc_dat_siz_o  : out unsigned(1 downto 0)

  );
  end component;

end sim_sdcard_host_pack;

package body sim_sdcard_host_pack is
end sim_sdcard_host_pack;


--------------------------------------------------------------------------------
--
-- Author: John Clayton
-- Date  : July 27, 2018
-- Update: 07/27/18 Wrote the description, began writing code
--
-- Description
--------------------------------------------------------------------------------
-- This is a collection of modules gleaned from the mmc_tester module, and 
-- married with a sim_bus_control_port, for use in simulation.  The modules
-- which were selected from the mmc_tester, are those related to the
-- sdcard_host, since the purpose of this unit is to act as a surrogate for a
-- microcontroller SD Card host port.
--
-- In order to interact with this sdcard_host in simulation, a bus_control_port
-- is provided, having a 32-bit-- address and a 32-bit data bus.
--
-- It is helpful to summarize the memory map here:
--
-- Address          Length     Function
-- --------------   --------   --------------------------------------------
-- 0x0300_0000      0x10       MMC host registers
-- 0x0400_0000      0x4000     MMC host RAM
--
-- Note that the size of the MMC host RAM can be modified by setting the
-- constant HOST_RAM_ADR_BITS.
--
-- For a description of the MMC host registers, please refer to the
-- description given in the sd_controller_8bit_bram entity.
-- The code is contained in the "sd_host_pack.vhd" file.
--
-- There are no "buried tri-states" present within this module.  Therefore,
-- each signal, or related bus of signals, has a drive signal provided to allow
-- the tri-state connections to be made at the top level.  The one for the
-- mmc_clk had to be provided because this module can both give and receive an
-- MMC clock signal.
--

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library work;
use work.convert_pack.all;
use work.sd_host_pack.all;
use work.block_ram_pack.all;
use work.sim_bus_control_port_pack.all;

  entity sim_sdcard_host is
  generic (
    -- relating to file I/O
    INPUT_FILE          : string  := "./bus_sim_in.txt";
    OUTPUT_FILE         : string  := "./bus_sim_out.txt";
    -- relating to the sdcard_host
    HOST_RAM_INIT_FILE  : string  := "./host_ram_init.txt";
    HOST_RAM_ADR_BITS   : natural := 14          -- Determines amount of BRAM for sdcard_host
  );
  port (

    -- Asynchronous system reset and system clock
    sys_rst_n      : in  std_logic;
    sys_clk        : in  std_logic;

    -- SD/MMC card signals
    mmc_clk_o      : out std_logic;
    mmc_cmd_i      : in  std_logic;
    mmc_cmd_o      : out std_logic;
    mmc_cmd_oe_o   : out std_logic;
    mmc_dat_i      : in  unsigned(7 downto 0);
    mmc_dat_o      : out unsigned(7 downto 0);
    mmc_dat_oe_o   : out std_logic;
    mmc_dat_siz_o  : out unsigned(1 downto 0)

  );
  end sim_sdcard_host;

architecture beh of sim_sdcard_host is

  -- Constants
    -- sim_bus_control_port related
  constant CMD_LINE_SIZE   : natural :=       128; -- Number of bytes in CMD buffer
  constant ADR_DIGITS      : natural :=         8;
  constant DAT_DIGITS      : natural :=         8;
  constant QTY_DIGITS      : natural :=         4;
  constant WATCHDOG_VALUE  : natural :=      2000; -- # of sys_clks before ack is expected
  constant DAT_SIZE        : natural := 4*DAT_DIGITS;
  constant ADR_SIZE        : natural := 4*ADR_DIGITS;
  constant DISPLAY_FIELDS  : natural :=         4;  -- # of fields/line

  -- Signals

    -- sim_bus_control_port related
  signal syscon_rst       : std_logic;
  signal fpga_rst_n       : std_logic;
  signal fpga_rst         : std_logic;
  signal syscon_dat_rd    : unsigned(DAT_SIZE-1 downto 0);
  signal syscon_dat_wr    : unsigned(DAT_SIZE-1 downto 0);
  signal syscon_cyc       : std_logic;
  signal syscon_err       : std_logic;
  signal syscon_ack       : std_logic;
  signal syscon_adr       : unsigned(ADR_SIZE-1 downto 0);
  signal syscon_we        : std_logic;

    -- related to decoding the address bus
  signal h_reg_sel        : std_logic;
  signal h_reg_ack        : std_logic;
  signal h_reg_dat_rd     : unsigned(31 downto 0);
  signal h_ram_sel        : std_logic;
  signal h_ram_ack        : std_logic;
  signal h_ram_dat_rd     : unsigned(7 downto 0);

    -- relating to system side access
  signal h_ram_we           : std_logic;

    -- sdcard_host BRAM interface related
  signal host_bram_clk    : std_logic;
  signal host_bram_dat_wr : unsigned(7 downto 0);
  signal host_bram_dat_rd : unsigned(7 downto 0);
  signal host_bram_adr    : unsigned(31 downto 0);
  signal host_bram_we     : std_logic;
  signal host_bram_cyc    : std_logic;

    -- sdcard_host related
  signal host_cmd_i       : std_logic;
  signal host_cmd_o       : std_logic;
  signal host_cmd_oe_o    : std_logic;
  signal host_dat_i       : unsigned(7 downto 0);
  signal host_dat_o       : unsigned(7 downto 0);
  signal host_dat_oe_o    : std_logic;
  signal host_dat_siz_o   : unsigned(1 downto 0);

begin

  buscon1 : sim_bus_control_port
  generic map(
    -- relating to file I/O
    INPUT_FILE      =>            INPUT_FILE,
    OUTPUT_FILE     =>           OUTPUT_FILE,
    MSG_PREFIX      =>        "SD card host", -- Prefix of console output messages from this unit
    -- relating to the bus controller
    POR_DURATION    =>                500 ns,  -- Duration of internal reset signal activity
    POR_ASSERT_LOW  =>                 false,  -- Determines polarity of reset output
    CLKRATE         =>               1000000,  -- Set frequency of test_clk (not used here)
    LINE_LENGTH     =>       CMD_LINE_SIZE+8,  -- Length of buffer to hold file input bytes
    ADR_DIGITS      =>            ADR_DIGITS, -- # of hex digits for address
    DAT_DIGITS      =>            DAT_DIGITS, -- # of hex digits for data
    QTY_DIGITS      =>            QTY_DIGITS, -- # of hex digits for quantity
    CMD_BUFFER_SIZE =>         CMD_LINE_SIZE, -- # of chars in the command buffer
    WATCHDOG_VALUE  =>        WATCHDOG_VALUE, -- # of sys_clks before ack is expected
    DISPLAY_FIELDS  =>        DISPLAY_FIELDS  -- # of fields/line
  )
  port map(
    -- Clock and reset stimulus
    test_rst => open,  -- Programmable polarity
    test_clk => open,  -- Programmable frequency

    -- System Bus IO
    ack_i        => syscon_ack,
    err_i        => syscon_err,
    dat_i        => syscon_dat_rd,
    dat_o        => syscon_dat_wr,
    rst_o        => syscon_rst,
    stb_o        => open,
    cyc_o        => syscon_cyc,
    adr_o        => syscon_adr,
    we_o         => syscon_we
  );

  -- Combine the input reset with the async_syscon bus reset
  fpga_rst_n <= '0' when (sys_rst_n='0' or syscon_rst='1') else '1';
  fpga_rst   <= '1' when (sys_rst_n='0' or syscon_rst='1') else '0';

  h_reg_sel <= '1' when syscon_cyc='1' and syscon_adr(31 downto 4)=16#0300000# else '0';
  h_ram_sel <= '1' when syscon_cyc='1' and syscon_adr(31 downto 24)=16#04# and syscon_adr(23 downto HOST_RAM_ADR_BITS)=0 else '0';

  syscon_dat_rd <= h_reg_dat_rd              when h_reg_sel='1' else
                   u_resize(h_ram_dat_rd,32) when h_ram_sel='1' else
                   str2u("12340000",32);

  syscon_ack <= h_reg_ack when h_reg_sel='1' else
                h_ram_ack when h_ram_sel='1' else
                '0';

  syscon_err <= '0' when h_reg_sel='1' or h_ram_sel='1' else '1';

  -------------------------------------------------------------------------
  -- Create a Block RAM which the SD/MMC controller uses as a data
  -- storage area.
  -- The 'A' port is attached to the simulation bus controller
  -- The 'B' port is attached to the mmc controller
  h_ram_we <= '1' when h_ram_sel='1' and syscon_we='1' else '0';
  host_0_bram_0 : swiss_army_ram
    generic map(
      USE_BRAM  => 1, -- Set to nonzero value for BRAM, zero for distributed RAM
      WRITETHRU => 1, -- Set to nonzero value for writethrough mode
      USE_FILE  => 1, -- Set to nonzero value to use INIT_FILE
      INIT_VAL  => 16#00#, -- Value used when INIT_FILE is not used
      INIT_SEL  => 0, -- Selects which segment of (larger) INIT_FILE to use
      INIT_FILE => HOST_RAM_INIT_FILE, -- ASCII hexadecimal initialization file name
      FIL_WIDTH => 32, -- Bit width of init file lines
      ADR_WIDTH => HOST_RAM_ADR_BITS,
      DAT_WIDTH =>  8
    )
    port map(
      clk_a    => sys_clk,
      adr_a_i  => syscon_adr(13 downto 0),
      we_a_i   => h_ram_we,
      en_a_i   => std_logic'('1'),
      dat_a_i  => syscon_dat_wr(7 downto 0),
      dat_a_o  => h_ram_dat_rd,

      clk_b    => host_bram_clk,
      adr_b_i  => host_bram_adr(HOST_RAM_ADR_BITS-1 downto 0),
      we_b_i   => host_bram_we,
      en_b_i   => std_logic'('1'),
      dat_b_i  => host_bram_dat_wr,
      dat_b_o  => host_bram_dat_rd
    );
-- system side BRAM ack signal needs to be delayed by 1 cycle,
-- to allow for the BRAM to respond to the given address.
process(sys_rst_n,sys_clk)
begin
  if (sys_rst_n='0') then
    h_ram_ack <= '0';
  elsif (sys_clk'event and sys_clk='1') then
    h_ram_ack <= h_ram_sel;
  end if;
end process;

  sd_host_0 : sd_controller_8bit_bram
  port map(
    -- WISHBONE common
    wb_clk_i     => sys_clk,
    wb_rst_i     => fpga_rst,
    -- WISHBONE slave (register interface)
    wb_dat_i     => syscon_dat_wr,
    wb_dat_o     => h_reg_dat_rd,
    wb_adr_i     => syscon_adr(3 downto 0),
    wb_we_i      => syscon_we,
    wb_cyc_i     => h_reg_sel,
    wb_ack_o     => h_reg_ack,
    -- Dedicated BRAM port without acknowledge.
    -- Access cycles must complete immediately.
    -- (data to cross clock domains by this dual-ported BRAM)
    bram_clk_o   => host_bram_clk, -- Same as sd_clk_o_pad
    bram_dat_o   => host_bram_dat_wr,
    bram_dat_i   => host_bram_dat_rd,
    bram_adr_o   => host_bram_adr,
    bram_we_o    => host_bram_we,
    bram_cyc_o   => host_bram_cyc,
    --SD Card Interface
    sd_cmd_i     => host_cmd_i,
    sd_cmd_o     => host_cmd_o,
    sd_cmd_oe_o  => host_cmd_oe_o,
    sd_dat_i     => host_dat_i,
    sd_dat_o     => host_dat_o,
    sd_dat_oe_o  => host_dat_oe_o,
    sd_dat_siz_o => host_dat_siz_o,
    sd_clk_o_pad => mmc_clk_o,
    -- Interrupt outputs
    int_cmd_o    => open,
    int_data_o   => open
  );

  -- Create MMC signaling
  mmc_cmd_o     <= host_cmd_o;
  mmc_cmd_oe_o  <= host_cmd_oe_o;
  mmc_dat_o     <= host_dat_o when host_dat_oe_o='1' else (others=>'1');
  mmc_dat_oe_o  <= host_dat_oe_o;
  mmc_dat_siz_o <= host_dat_siz_o when host_dat_oe_o='1' else (others=>'0');

  host_cmd_i  <= mmc_cmd_i when host_cmd_oe_o='0' else '1';
  host_dat_i  <= mmc_dat_i when host_dat_oe_o='0' else (others=>'1');

end beh;
