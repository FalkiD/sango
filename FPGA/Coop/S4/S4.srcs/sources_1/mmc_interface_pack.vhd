--------------------------------------------------------------------------
--------------------------------------------------------------------------
-- Package containing SD Card interface
--
--
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library work;
use work.sd_card_pack.all;

package mmc_interface_pack is

  component mmc_interface
  generic (
    SYS_CLK_RATE        : real; -- The clock rate at which the FPGA runs
    EXT_CSD_INIT_FILE   : string; -- Initial contents of EXT_CSD
    MMC_FIFO_DEPTH      : integer;
    MMC_FILL_LEVEL_BITS : integer; -- Should be at least int(floor(log2(FIFO_DEPTH))+1.0)
    MMC_RAM_ADR_BITS    : integer
  );
  port (

    -- Asynchronous reset
    sys_rst_n      : in  std_logic;
    sys_clk        : in  std_logic;

    -- Asynchronous serial interface
    cmd_i          : in  std_logic;
    resp_o         : out std_logic;

    -- SD/MMC card signals
    mmc_clk_i      : in  std_logic;
    mmc_cmd_i      : in  std_logic;
    mmc_cmd_o      : out std_logic;
    mmc_cmd_oe_o   : out std_logic;
    mmc_dat_i      : in  unsigned(7 downto 0);
    mmc_dat_o      : out unsigned(7 downto 0);
    mmc_dat_oe_o   : out std_logic;
    mmc_od_mode_o  : out std_logic; -- Open drain mode
    mmc_dat_siz_o  : out unsigned(1 downto 0);

    -- Debug SPI signals
    dbg_spi_data0_o     : out unsigned(7 downto 0);
    dbg_spi_data1_o     : out unsigned(7 downto 0);
    dbg_spi_data2_o     : out unsigned(7 downto 0);
    dbg_spi_data3_o     : out unsigned(7 downto 0);
    dbg_spi_data4_o     : out unsigned(7 downto 0);
    dbg_spi_data5_o     : out unsigned(7 downto 0);
    dbg_spi_data6_o     : out unsigned(7 downto 0);
    dbg_spi_data7_o     : out unsigned(7 downto 0);
    dbg_spi_data8_o     : out unsigned(7 downto 0);
    dbg_spi_data9_o     : out unsigned(7 downto 0);
    dbg_spi_dataA_o     : out unsigned(7 downto 0);
    dbg_spi_dataB_o     : out unsigned(7 downto 0);
    dbg_spi_dataC_o     : out unsigned(7 downto 0);
    dbg_spi_dataD_o     : out unsigned(7 downto 0);
    dbg_spi_bytes_io    : inout unsigned(3 downto 0); --bytes to send
    dbg_spi_start_o     : out std_logic;
    dbg_spi_device_o    : out unsigned(2 downto 0); --1=VGA, 2=SYN, 3=DDS, 4=ZMON
    dbg_spi_busy_i      : in  std_logic;
    dbg_enables_o       : out unsigned(15 downto 0);  --toggle various enables/wires

    ------ Connect MMC fifos to opcode processor ----------
    -- Read from MMC fifo connections
    opc_fif_dat_o       : out unsigned( 7 downto 0);    -- MMC opcode fifo
    opc_fif_ren_i       : in  std_logic;                -- mmc fifo read enable
    opc_fif_mt_o        : out std_logic;                -- mmc opcode fifo empty
    opc_rd_cnt_o        : out unsigned(MMC_FILL_LEVEL_BITS-1 downto 0); -- mmc opcode fifo fill level 
    opc_rd_reset_i      : in  std_logic;                -- Synchronous mmc opcode fifo reset
    -- Write to MMC fifo connections
    opc_rspf_dat_i      : in  unsigned( 7 downto 0);    -- MMC response fifo
    opc_rspf_we_i       : in  std_logic;                -- response fifo write line             
    opc_rspf_mt_o       : out std_logic;                -- response fifo empty
    opc_rspf_fl_o       : out std_logic;                -- response fifo full
    opc_rspf_reset_i    : in std_logic;                 -- Synchronous mmc response fifo reset
    opc_rspf_cnt_o      : out unsigned(MMC_FILL_LEVEL_BITS-1 downto 0); -- mmc response fifo fill level 

    -- UART debugger can show these values
    opc_oc_cnt_i        : in  unsigned(31 downto 0);    -- count of opcodes processed
    opc_status1_i       : in  unsigned(31 downto 0);    -- LS 16 bits=opc status, MS 16-bits=opc_state
    opc_status2_i       : in  unsigned(31 downto 0);    -- rsp_fifo_count__opc_fifo_count    
    opc_status3_i       : in  unsigned(31 downto 0);    -- LS 16 bits=MS 8 bits=RSP fifo level, LS 8 bits=OPC fifo level
    sys_status4_i       : in  unsigned(31 downto 0);    -- system frequency setting in Hertz
    sys_status5_i       : in  unsigned(31 downto 0);    -- MS 16 bits=SYN_STAT pin,1=PLL_LOCK, 0=not, LS 12 bits=system power, dBm x 10
    sys_status6_i       : in  unsigned(31 downto 0)     -- LS 16 bits: PTN_Status__PTN_Busy(running) 
  );
  end component;

end mmc_interface_pack;

package body mmc_interface_pack is
end mmc_interface_pack;


---------------------------------------------------------------------------------------
--
-- Author: John Clayton
-- Update: 04/07/18 Wrote the description, began writing code
--
-- Description
---------------------------------------------------------------------------------------
-- This is a collection of modules put together which augment the basic "mmc_data_pipe"
-- with a serial-based system bus controller ("async_syscon") and some registers which
-- can enable status read and debug I/O.
--
-- More Detailed Technical Description
-- -----------------------------------
-- In order to interact with this collection of modules in hardware, an 
-- "async_syscon" serial terminal command interpreter is provided, having a 32-bit
-- address bus and a 32-bit data bus.  There is an automatic baud rate synchronization
-- unit, which synchronizes by looking for the 0x0D character, so that simply
-- pressing "Enter" in a serial terminal program should bring up the link at the
-- correct speed, anything in the range 19200 to 921600 Baud should work.
-- The parity setting is "None" and hardware handshaking is not supported.
--
-- Because of the different modules present in this MMC tester, it is helpful to
-- summarize the memory map here:
--
-- Address          Length     Function
-- --------------   --------   --------------------------------------------
-- 0x0300_0010      0x10       MMC slave registers
-- 0x0500_0000      0x10000    MMC slave RAM
--
-- Note that the size of the MMC slave RAM can be modified by setting the
-- constant MMC_RAM_ADR_BITS within this module.
--
-- For a description of the MMC slave registers, please refer to the
-- description given in the sd_card_emulator, which is an entity instantiated
-- inside the mmc_data_pipe unit.
-- The code is contained in the "sd_card_pack.vhd" file.
--
-- A detailed description of the local registers is given here, below.
--
-- Wouldn't it be nice to have a block diagram showing all of the modules
-- or cores instantiated within this one?  Yes, I believe it would be nice.
-- However, in lieu of a nice ASCII-art pictorial drawing, a few lines of
-- descriptive text will be better than nothing.  Here goes!
------------------------------------------------------------------------------
-- Brief Description of local test functions:
--
--   Within this unit, there is steering logic that selects how the SD/MMC bus
--   is driven and used, with regard to the tri-state output enables.  Actual
--   tri-state buffers are to be implemented at the top level of the FPGA
--   by means of the output enable signals.
--
--   This module is set up so that an external SD/MMC host can talk
--   to the local mmc_data_pipe unit, which emulates an actual SD/eMMC card.
--
------------------------------------------------------------------------------
-- Local Registers
--
--
-- 0x0300_002C  R12  S4 Enables/lines
--
-- 0x0300_002D  R13  MMC_data_pipe write data FIFO fill level (READ/WRITE)
--                   Reading this register returns the number of bytes in
--                   the MMC slave write data FIFO.  The FIFO holds data
--                   that are meant to flow from the MMC slave to the host.
--                   Writing to this register clears the MMC slave
--                   write data FIFO.
--
-- 0x0300_002E  R14  MMC_data_pipe read data FIFO fill level (READ/WRITE)
--                   Reading this register returns the number of bytes in
--                   the MMC slave read data FIFO.  The FIFO holds data
--                   that have been sent from the host to the MMC slave.
--                   Writing to this register clears the MMC slave
--                   read data FIFO.
--
-- 0x0300_002F  R15  MMC_data_pipe FIFO data (READ/WRITE)
--                   Writing to this address loads another byte into
--                   the MMC slave write data FIFO, thereby enqueueing
--                   it to be read by the host from the MMC slave.
--                   However, if the write data FIFO is full, then nothing
--                   happens, and the byte is thrown into the "bit bucket."
--                   Reading from this address removes another byte
--                   of data from the MMC slave read data FIFO, which
--                   was previously delivered from the host to the
--                   MMC slave.
--                   However, if the read data FIFO is empty, then no valid
--                   data is actually delivered.
--
-- 0x0300_0030  R16  Rd:Opcode processor status, 8 lsbs, Wr:SPI data, device, #bytes, 14 bytes data
--
-- 0x3000_0031  R17  Opcode processor opcode counter, 32 bits
--
-- 0x3000_0032  R18  Opcode processor internal state, 8 bits
--
-- 0x3000_0033  R19  Opcode processor overall system state, 16 bits
--
-- 0x3000_0034  R20  Opcode processor overall system mode, 32 bits
--
-- 0x3000_0035  R21  Frequency processor status, 16 msbs, power processor status, 16 lsbs
--
-- 0x3000_0036  R22  Phase processor status, 16 msbs, pulse processor status, 16 lsbs
--
-- 0x3000_0037  R23  Pattern processor status, 16 msbs, opc_response_ready flag, 16 lsbs 
--
--

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library work;
use work.dds_pack.all;
use work.fifo_pack.all;
use work.convert_pack.all;
use work.sd_card_pack.all;
use work.flancter_pack.all; -- Is this really still needed?
use work.block_ram_pack.all;
use work.auto_baud_pack.all;
use work.uart_sqclk_pack.all;
use work.async_syscon_pack.all;

  entity mmc_interface is
  generic (
    SYS_CLK_RATE        : real    := 50000000.0; -- The clock rate at which the FPGA runs
    EXT_CSD_INIT_FILE   : string  := "ext_csd_init.txt"; -- Initial contents of EXT_CSD
    MMC_FIFO_DEPTH      : integer := 2048;
    MMC_FILL_LEVEL_BITS : integer := 14; -- Should be at least int(floor(log2(FIFO_DEPTH))+1.0)
    MMC_RAM_ADR_BITS    : integer := 14  -- 16 Kilobytes
  );
  port (

    -- Asynchronous reset
    sys_rst_n      : in  std_logic;
    sys_clk        : in  std_logic;

    -- Asynchronous serial interface
    cmd_i          : in  std_logic;
    resp_o         : out std_logic;

    -- SD/MMC card signals
    mmc_clk_i      : in  std_logic;
    mmc_cmd_i      : in  std_logic;
    mmc_cmd_o      : out std_logic;
    mmc_cmd_oe_o   : out std_logic;
    mmc_dat_i      : in  unsigned( 7 downto 0);
    mmc_dat_o      : out unsigned( 7 downto 0);
    mmc_dat_oe_o   : out std_logic;
    mmc_od_mode_o  : out std_logic; -- Open drain mode
    mmc_dat_siz_o  : out unsigned(1 downto 0);
    
    -- Debug SPI signals
    dbg_spi_data0_o     : out unsigned(7 downto 0);
    dbg_spi_data1_o     : out unsigned(7 downto 0);
    dbg_spi_data2_o     : out unsigned(7 downto 0);
    dbg_spi_data3_o     : out unsigned(7 downto 0);
    dbg_spi_data4_o     : out unsigned(7 downto 0);
    dbg_spi_data5_o     : out unsigned(7 downto 0);
    dbg_spi_data6_o     : out unsigned(7 downto 0);
    dbg_spi_data7_o     : out unsigned(7 downto 0);
    dbg_spi_data8_o     : out unsigned(7 downto 0);
    dbg_spi_data9_o     : out unsigned(7 downto 0);
    dbg_spi_dataA_o     : out unsigned(7 downto 0);
    dbg_spi_dataB_o     : out unsigned(7 downto 0);
    dbg_spi_dataC_o     : out unsigned(7 downto 0);
    dbg_spi_dataD_o     : out unsigned(7 downto 0);
    dbg_spi_bytes_io    : inout unsigned(3 downto 0); --bytes to send
    dbg_spi_start_o     : out std_logic;
    dbg_spi_device_o    : out unsigned(2 downto 0); --1=VGA, 2=SYN, 3=DDS, 4=ZMON
    dbg_spi_busy_i      : in  std_logic;            --top level is writing SPI bytes
    dbg_enables_o       : out unsigned(15 downto 0); --toggle various enables/wires

    -- connect opcode processor to mmc fifo's    
    -- MMC read fifo to opcode processor
    opc_fif_dat_o       : out unsigned( 7 downto 0);     -- MMC opcode fifo
    opc_fif_ren_i       : in std_logic;                  -- mmc fifo read enable
    opc_fif_mt_o        : out std_logic;                 -- mmc opcode fifo empty
    opc_rd_cnt_o        : out unsigned(MMC_FILL_LEVEL_BITS-1 downto 0); -- mmc opcode fifo fill level 
    opc_rd_reset_i      : in std_logic;                  -- Synchronous mmc opcode fifo reset
    -- MMC write fifo from opcode processor
    opc_rspf_dat_i      : in  unsigned( 7 downto 0);     -- MMC response fifo
    opc_rspf_we_i       : in std_logic;                  -- response fifo write line             
    opc_rspf_mt_o       : out std_logic;                 -- response fifo empty
    opc_rspf_fl_o       : out std_logic;                 -- response fifo full
    opc_rspf_reset_i    : in std_logic;                  -- Synchronous mmc response fifo reset
    opc_rspf_cnt_o      : out unsigned(MMC_FILL_LEVEL_BITS-1 downto 0); -- mmc response fifo fill level 

    -- Debugging
    opc_oc_cnt_i   : in  unsigned(31 downto 0);         -- LS 16 bits=count of opcodes processed, MS 16 bits=opc fifo level
    opc_status1_i  : in  unsigned(31 downto 0);         -- LS 16 bits=opc status, MS 16-bits=opc_state
    opc_status2_i  : in  unsigned(31 downto 0);         -- rsp_fifo_count__opc_fifo_count
    opc_status3_i  : in  unsigned(31 downto 0);         -- MS 16 bits=MS 8 bits=RSP fifo level, LS 8 bits=OPC fifo level
    sys_status4_i  : in  unsigned(31 downto 0);         -- system frequency setting in Hertz
    sys_status5_i  : in  unsigned(31 downto 0);         -- MS 16 bits=SYN_STAT pin,1=PLL_LOCK, 0=not, LS 12 bits=system power, dBm x 10
    sys_status6_i  : in  unsigned(31 downto 0)          -- LS 16 bits: PTN_Status__PTN_Busy(running) 
  );
  end mmc_interface;

architecture beh of mmc_interface is

  -- Constants
  
    -- async_syscon related
  constant FPGA_PARITY     : integer :=         0; -- 0=none, 1=even, 2=odd
  constant CMD_LINE_SIZE   : natural :=       128; -- Number of bytes in CMD buffer
  constant ADR_DIGITS      : natural :=         8;
  constant DAT_DIGITS      : natural :=         8;
  constant QTY_DIGITS      : natural :=         4;
  constant WDOG_VALUE      : natural :=      2000;
  constant DAT_SIZE        : natural := 4*DAT_DIGITS;
  constant ADR_SIZE        : natural := 4*ADR_DIGITS;

  -- Signals

    -- autobaud related
  signal baud_clk         : std_logic;
  signal baud_lock        : std_logic;
  signal parity           : unsigned(1 downto 0);
  
    -- async_syscon related
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

  signal master_bg        : std_logic;
  signal master_adr       : unsigned(ADR_SIZE-1 downto 0);
  signal master_cyc       : std_logic;
  signal master_we        : std_logic;
  signal master_dat_wr    : unsigned(DAT_SIZE-1 downto 0);

    -- related to decoding the address bus
  signal s_reg_sel        : std_logic;
  signal s_reg_ack        : std_logic;
  signal s_reg_dat_rd     : unsigned(31 downto 0);
  signal s_ram_sel        : std_logic;
  signal s_ram_ack        : std_logic;
  signal s_ram_dat_rd     : unsigned(7 downto 0);
  signal s_ram_we         : std_logic;

    -------------------------------------------------------
    -- mmc data pipe to opcode processor interface fifo's
  --signal s_fif_dat_rd     : unsigned(7 downto 0);       -- opcode fifo data from mmc
  --signal s_fif_rd         : std_logic;                  -- opcode fifo read enable
  --signal s_fif_rd_empty   : std_logic;
  --signal s_fif_rd_full    : std_logic;
  --signal s_fif_dat_wr     : unsigned(7 downto 0);       -- response fifo to mmc
  signal s_fif_wr         : std_logic;                  -- response fifo write enable
  --signal s_fif_wr_empty   : std_logic;
  --signal s_fif_wr_full    : std_logic;
    ------------------------------------------------------

  signal o_reg_sel        : std_logic; -- Opcode processor registers
  signal o_reg_ack        : std_logic; -- Opcode processor register ack
  signal o_reg_dat_rd     : unsigned(31 downto 0); -- Opcode processor register read data
  signal r_reg_sel        : std_logic; -- SPI debug registers
  signal r_reg_ack        : std_logic; -- SPI debug register ack
  signal r_reg_dat_rd     : unsigned(31 downto 0); -- SPI debug register read data
  
    -- MMC related
  signal slave_cmd_i      : std_logic;
  signal slave_cmd_oe_o   : std_logic;
  signal slave_dat_i      : unsigned(7 downto 0);
  signal slave_dat_o      : unsigned(7 downto 0);
  signal slave_dat_oe_o   : std_logic;
  signal slave_dat_siz_o  : unsigned(1 downto 0);

  -- SPI debugging
  signal dbg_spi_count    : unsigned(3 downto 0); --down counter
  signal dbg_spi_state    : integer;
  signal dbg_spi_start_l  : std_logic; -- local copy of dbg_spi_start_o

begin

  ------------------------------
  -- This module generates a serial BAUD clock automatically.
  -- The unit synchronizes on the carriage return character, so the user
  -- only needs to press the "enter" key for serial communications to start
  -- working, no matter what BAUD rate and clk_i frequency are used!
  auto_baud1 : auto_baud_with_tracking
    generic map(
      CLOCK_FACTOR    =>            1,  -- Output is this factor times the baud rate
      FPGA_CLKRATE    => SYS_CLK_RATE,  -- FPGA system clock rate
      MIN_BAUDRATE    =>       9600.0,  -- Minimum expected incoming Baud rate
      DELTA_THRESHOLD =>          200   -- Measurement filter constraint.  Smaller = tougher.
    )
    port map( 
       
      sys_rst_n    => sys_rst_n,
      sys_clk      => sys_clk,
      sys_clk_en   => '1',

      -- rate and parity
      rx_parity_i  => parity, -- 0=none, 1=even, 2=odd

      -- serial input
      rx_stream_i  => cmd_i,

      -- Output
      baud_lock_o  => baud_lock,
      baud_clk_o   => baud_clk
    );

  parity <= to_unsigned(FPGA_PARITY,parity'length);

  syscon1 : async_syscon
    generic map (
      ECHO_COMMANDS   =>               1, -- set nonzero to echo back command characters
      ADR_DIGITS      =>      ADR_DIGITS, -- # of hex digits for address
      DAT_DIGITS      =>      DAT_DIGITS, -- # of hex digits for data
      QTY_DIGITS      =>      QTY_DIGITS, -- # of hex digits for quantity
      CMD_BUFFER_SIZE =>   CMD_LINE_SIZE, -- # of chars in the command buffer
      WATCHDOG_VALUE  =>      WDOG_VALUE, -- # of sys_clks before ack is expected
      DISPLAY_FIELDS  =>               4  -- # of fields/line
    )
    port map ( 
       
      sys_rst_n    => sys_rst_n,
      sys_clk      => sys_clk,
      sys_clk_en   => '1',

      -- rate and parity
      parity_i     => parity,
      baud_clk_i   => baud_clk,
      baud_lock_i  => baud_lock,

      -- Serial IO
      cmd_i        => cmd_i,
      resp_o       => resp_o,
      cmd_done_o   => open,

      -- Master Bus IO
      master_bg_i  => master_bg,
      master_adr_i => master_adr,
      master_dat_i => master_dat_wr,
      master_dat_o => open, -- There is no other master to read data...
      master_stb_i => master_cyc,
      master_we_i  => master_we,
      master_br_o  => open, -- async_syscon is the only master in this design.

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

  -- Since there is no bus master besides the async_syscon, take care of those signals
  master_bg     <= '1';
  master_cyc    <= '0';
  master_dat_wr <= (others=>'0');
  master_we     <= '0';
  master_adr    <= (others=>'0');

  s_reg_sel <= '1' when syscon_cyc='1' and syscon_adr(31 downto 4)=16#0300001# else '0';
  o_reg_sel <= '1' when syscon_cyc='1' and syscon_adr(31 downto 4)=16#0300003# else '0';
  r_reg_sel <= '1' when syscon_cyc='1' and syscon_adr(31 downto 4)=16#0300004# else '0';
  s_ram_sel <= '1' when syscon_cyc='1' and syscon_adr(31 downto 24)=16#05# and syscon_adr(23 downto MMC_RAM_ADR_BITS)=0 else '0';

  syscon_dat_rd <= 
                   s_reg_dat_rd              when s_reg_sel='1' else
                   o_reg_dat_rd              when o_reg_sel='1' else
                   r_reg_dat_rd              when r_reg_sel='1' else
                   u_resize(s_ram_dat_rd,32) when s_ram_sel='1' else
                   str2u("12340000",32);

  syscon_ack <= 
                s_reg_ack when s_reg_sel='1' else
                o_reg_ack when o_reg_sel='1' else
                r_reg_ack when r_reg_sel='1' else
                s_ram_ack when s_ram_sel='1' else
                '0';

  syscon_err <= '0' when s_reg_sel='1' or o_reg_sel='1' or r_reg_sel='1' or
                         s_ram_sel='1' else '1';

  -- Select data for Local Register Reads
  with to_integer(syscon_adr(3 downto 0)) select
  o_reg_dat_rd <=
    sys_status6_i                                  when 16#9#,      -- LS 16 bits=
    sys_status5_i                                  when 16#A#,      -- LS 12 bits=system power, dBm x 10
    sys_status4_i                                  when 16#B#,      -- system frequency setting in Hertz
    opc_status3_i                                  when 16#C#,      -- 1st_opcode__last_opcode in lower 16 bits
    opc_status2_i                                  when 16#D#,      -- rsp_fifo_count__opc_fifo_count
    opc_status1_i                                  when 16#E#,      -- opc_state__opc_status
    u_resize(opc_oc_cnt_i,32)                      when 16#F#,      -- opcodes processed
  str2u("51514343",32)                             when others;
  
 -- Handle Local Register Writes
  process(sys_rst_n,sys_clk)
  begin
    if (sys_rst_n='0') then
      -- SPI debugging
      dbg_spi_bytes_io <= to_unsigned(0, dbg_spi_bytes_io'length);
      dbg_spi_start_l <= '0';
      dbg_spi_device_o <= to_unsigned(0, dbg_spi_device_o'length);
      dbg_enables_o <= to_unsigned(0, dbg_enables_o'length);
      dbg_spi_state <= 0;
      
    elsif (sys_clk'event and sys_clk='1') then
      -- Default values

      -- Register writes have the highest priority
      -- spi debug, SPI debug register writes, 03000040 x y z ...
      if (r_reg_sel='1' and syscon_we='1') then
        case to_integer(syscon_adr(3 downto 0)) is
          when 16#0# =>
            dbg_spi_device_o <= syscon_dat_wr(2 downto 0);
            dbg_spi_start_l <= '0';
          when 16#1# =>
            dbg_spi_bytes_io <= syscon_dat_wr(3 downto 0);
            dbg_spi_count <= to_unsigned(1, dbg_spi_count'length);
          when 16#2# =>
            dbg_spi_data0_o <= syscon_dat_wr(7 downto 0);
            if(dbg_spi_count = dbg_spi_bytes_io) then
              dbg_spi_start_l <= '1';
            else
              dbg_spi_count <= dbg_spi_count + 1;
            end if;
          when 16#3# =>
            dbg_spi_data1_o <= syscon_dat_wr(7 downto 0);
            if(dbg_spi_count = dbg_spi_bytes_io) then
              dbg_spi_start_l <= '1';
            else
              dbg_spi_count <= dbg_spi_count + 1;
            end if;
          when 16#4# =>
            dbg_spi_data2_o <= syscon_dat_wr(7 downto 0);
            if(dbg_spi_count = dbg_spi_bytes_io) then
              dbg_spi_start_l <= '1';
            else
              dbg_spi_count <= dbg_spi_count + 1;
            end if;
          when 16#5# =>
            dbg_spi_data3_o <= syscon_dat_wr(7 downto 0);
            if(dbg_spi_count = dbg_spi_bytes_io) then
              dbg_spi_start_l <= '1';
            else
              dbg_spi_count <= dbg_spi_count + 1;
            end if;
          when 16#6# =>
            dbg_spi_data4_o <= syscon_dat_wr(7 downto 0);
            if(dbg_spi_count = dbg_spi_bytes_io) then
              dbg_spi_start_l <= '1';
            else
              dbg_spi_count <= dbg_spi_count + 1;
            end if;
          when 16#7# =>
            dbg_spi_data5_o <= syscon_dat_wr(7 downto 0);
            if(dbg_spi_count = dbg_spi_bytes_io) then
              dbg_spi_start_l <= '1';
            else
              dbg_spi_count <= dbg_spi_count + 1;
            end if;
          when 16#8# =>
            dbg_spi_data6_o <= syscon_dat_wr(7 downto 0);
            if(dbg_spi_count = dbg_spi_bytes_io) then
              dbg_spi_start_l <= '1';
            else
              dbg_spi_count <= dbg_spi_count + 1;
            end if;
          when 16#9# =>
            dbg_spi_data7_o <= syscon_dat_wr(7 downto 0);
            if(dbg_spi_count = dbg_spi_bytes_io) then
              dbg_spi_start_l <= '1';
            else
              dbg_spi_count <= dbg_spi_count + 1;
            end if;
          when 16#A# =>
            dbg_spi_data8_o <= syscon_dat_wr(7 downto 0);
            if(dbg_spi_count = dbg_spi_bytes_io) then
              dbg_spi_start_l <= '1';
            else
              dbg_spi_count <= dbg_spi_count + 1;
            end if;
          when 16#B# =>
            dbg_spi_data9_o <= syscon_dat_wr(7 downto 0);
            if(dbg_spi_count = dbg_spi_bytes_io) then
              dbg_spi_start_l <= '1';
            else
              dbg_spi_count <= dbg_spi_count + 1;
            end if;
          when 16#C# =>
            dbg_spi_dataA_o <= syscon_dat_wr(7 downto 0);
            if(dbg_spi_count = dbg_spi_bytes_io) then
              dbg_spi_start_l <= '1';
            else
              dbg_spi_count <= dbg_spi_count + 1;
            end if;
          when 16#D# =>
            dbg_spi_dataB_o <= syscon_dat_wr(7 downto 0);
            if(dbg_spi_count = dbg_spi_bytes_io) then
              dbg_spi_start_l <= '1';
            else
              dbg_spi_count <= dbg_spi_count + 1;
            end if;
          when 16#E# =>
            dbg_spi_dataC_o <= syscon_dat_wr(7 downto 0);
            if(dbg_spi_count = dbg_spi_bytes_io) then
              dbg_spi_start_l <= '1';
            else
              dbg_spi_count <= dbg_spi_count + 1;
            end if;
          when 16#F# =>
            dbg_spi_dataD_o <= syscon_dat_wr(7 downto 0);
            dbg_spi_start_l <= '1';
          when others =>
            null;
          end case;
      end if;            

      --If Debug SPI just started, clear start pulse, device #
      if(dbg_spi_start_l = '1' and dbg_spi_busy_i = '1') then
        dbg_spi_start_l <= '0';     -- clear start
      end if;

    end if;
  end process;
  -- Provide test register acknowledge
  o_reg_ack <= o_reg_sel;
  r_reg_ack <= r_reg_sel;

  -- assign output based on local value
  dbg_spi_start_o <= dbg_spi_start_l;


  mmc_slave : mmc_data_pipe
  generic map(
    EXT_CSD_INIT_FILE => "ext_csd_init.txt", -- Initial contents of EXT_CSD
    FIFO_DEPTH        => MMC_FIFO_DEPTH,
    FILL_LEVEL_BITS   => MMC_FILL_LEVEL_BITS, --s_fif_dat_wr_level'length, -- Should be at least int(floor(log2(FIFO_DEPTH))+1.0)
    RAM_ADR_WIDTH     => MMC_RAM_ADR_BITS
  )
  port map(

    -- Asynchronous reset
    sys_rst_n     => fpga_rst_n,
    sys_clk       => sys_clk,

    -- Bus interface
    adr_i         => syscon_adr(3 downto 0),
    sel_i         => s_reg_sel,
    we_i          => syscon_we,
    dat_i         => syscon_dat_wr,
    dat_o         => s_reg_dat_rd,
    ack_o         => s_reg_ack,

    -- SD/MMC card signals
    mmc_clk_i     => mmc_clk_i,
    mmc_cmd_i     => slave_cmd_i,
    mmc_cmd_o     => mmc_cmd_o,
    mmc_cmd_oe_o  => slave_cmd_oe_o,
    mmc_od_mode_o => mmc_od_mode_o, -- Open drain mode
    mmc_dat_i     => slave_dat_i,
    mmc_dat_o     => slave_dat_o,
    mmc_dat_oe_o  => slave_dat_oe_o,
    mmc_dat_siz_o => slave_dat_siz_o,

    -- Data Pipe FIFOs
    wr_clk_i      => sys_clk,
    wr_clk_en_i   => '1',
    wr_reset_i    => opc_rspf_reset_i,      -- Synchronous
    wr_en_i       => opc_rspf_we_i,
    wr_dat_i      => opc_rspf_dat_i,
    wr_fifo_level => opc_rspf_cnt_o,
    wr_fifo_full  => opc_rspf_fl_o,
    wr_fifo_empty => opc_rspf_mt_o,

    rd_clk_i      => sys_clk,
    rd_clk_en_i   => '1',
    rd_reset_i    => opc_rd_reset_i,        -- Synchronous
    rd_en_i       => opc_fif_ren_i,
    rd_dat_o      => opc_fif_dat_o,
    rd_fifo_level => opc_rd_cnt_o,
    rd_fifo_full  => open,
    rd_fifo_empty => opc_fif_mt_o,

    -- Data Pipe RAM
    ram_clk_i     => sys_clk,
    ram_clk_en_i  => '1',
    ram_adr_i     => syscon_adr(MMC_RAM_ADR_BITS-1 downto 0),
    ram_we_i      => s_ram_we,
    ram_dat_i     => syscon_dat_wr(7 downto 0),
    ram_dat_o     => s_ram_dat_rd
  );
  s_ram_we  <= '1' when syscon_we='1' and s_ram_sel='1' else '0';

-- system side BRAM ack signal needs to be delayed by 1 cycle,
-- to allow for the BRAM to respond to the given address.
process(sys_rst_n,sys_clk)
begin
  if (sys_rst_n='0') then
    s_ram_ack <= '0';
  elsif (sys_clk'event and sys_clk='1') then
    s_ram_ack <= s_ram_sel;
  end if;
end process;

-- Use output enables to steer MMC signaling

  mmc_cmd_oe_o  <= slave_cmd_oe_o;
  mmc_dat_o     <= slave_dat_o  when slave_dat_oe_o='1' else (others=>'1');
  mmc_dat_oe_o  <= slave_dat_oe_o;
  mmc_dat_siz_o <= slave_dat_siz_o when slave_dat_oe_o='1' else (others=>'0');

  slave_cmd_i <= mmc_cmd_i when slave_cmd_oe_o='0' else '1';
  slave_dat_i <= mmc_dat_i when slave_dat_oe_o='0' else (others=>'1');

end beh;
