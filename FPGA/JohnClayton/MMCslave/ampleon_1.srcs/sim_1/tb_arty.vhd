--
-- Test Bench
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.convert_pack.all;
use work.pull_pack_sim.all;
use work.sim_uart_control_port_pack.all;

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
  constant TEST_CLKRATE : integer := 100000000; -- The clock rate at which the stimulus logic and FPGA runs
  constant DUT_CLKRATE  : integer := 101000000; -- (Not used in this testbench.)

  ----------------------------------------------------------------------

  -- Component Declarations
  -----------------------------------
component top
port (
  CLK        : in  std_logic;
  ck_rst     : in  std_logic;
  SW         : in  unsigned(3 downto 0);
  BTN        : in  unsigned(3 downto 0);
  UART_CMD_i : in  std_logic;
  UART_RSP_o : out std_logic;
  RGB0_Blue  : out std_logic;
  RGB0_Green : out std_logic;
  RGB0_Red   : out std_logic;
  RGB1_Blue  : out std_logic;
  RGB1_Green : out std_logic;
  RGB1_Red   : out std_logic;
  RGB2_Blue  : out std_logic;
  RGB2_Green : out std_logic;
  RGB2_Red   : out std_logic;
  RGB3_Blue  : out std_logic;
  RGB3_Green : out std_logic;
  RGB3_Red   : out std_logic;
  LED        : out unsigned(3 downto 0);
  ja         : inout unsigned(7 downto 0);
  jb         : inout unsigned(7 downto 0);
  jc         : inout unsigned(7 downto 0);
  jd         : inout unsigned(7 downto 0)
);
end component;

  -----------------------------------------------------------------------------
  -- Internal signal declarations

    -- Common Signals
  signal dut_clk       : std_logic := '0';

  -- Signals from unit under test, so they show up in testbench
  signal CLK        : std_logic;
  signal ck_rst     : std_logic;
  signal SW         : unsigned(3 downto 0);
  signal BTN        : unsigned(3 downto 0);
  signal UART_CMD_i : std_logic;
  signal UART_RSP_o : std_logic;
  signal RGB0_Blue  : std_logic;
  signal RGB0_Green : std_logic;
  signal RGB0_Red   : std_logic;
  signal RGB1_Blue  : std_logic;
  signal RGB1_Green : std_logic;
  signal RGB1_Red   : std_logic;
  signal RGB2_Blue  : std_logic;
  signal RGB2_Green : std_logic;
  signal RGB2_Red   : std_logic;
  signal RGB3_Blue  : std_logic;
  signal RGB3_Green : std_logic;
  signal RGB3_Red   : std_logic;
  signal LED        : unsigned(3 downto 0);
  signal ja         : unsigned(7 downto 0);
  signal jb         : unsigned(7 downto 0);
  signal jc         : unsigned(7 downto 0);
  signal jd         : unsigned(7 downto 0);

begin

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

  ------------------------------------------------------------------------
  -- Instantiate a control port
  cp0 : sim_uart_control_port
  generic map(
    INPUT_FILE      => "uart_sim_in.txt",
    OUTPUT_FILE     => "uart_sim_out.txt",
    POR_DURATION    =>  500 ns,  -- Duration of internal reset signal activity
    POR_ASSERT_LOW  =>    true,  -- Determines polarity of reset output
    CLKRATE         => TEST_CLKRATE, -- Control Port clock rate default.
    UART_BAUDRATE   => 921600,  -- UART Speed, in bits per second.
    UART_PARITY     =>      0,  -- no parity
    LINE_LENGTH     =>     64   -- Length of buffer to hold file input bytes
  )
  port map(
    -- Clock and reset stimulus
    test_rst => ck_rst,
    test_clk => CLK,
    -- UART I/O
    uart_tx  => UART_CMD_i,  -- HS async. Serial line to FPGA
    uart_rx  => UART_RSP_o   -- HS async. Serial line from FPGA
  );

  ------------------------------------------------------------------------
  -- Instantiate Unit Under Test
  dut_0 : top
  port map(
    CLK        => CLK,
    ck_rst     => ck_rst,
    SW         => SW,
    BTN        => BTN,
    UART_CMD_i => UART_CMD_i,
    UART_RSP_o => UART_RSP_o,
    RGB0_Blue  => RGB0_Blue,
    RGB0_Green => RGB0_Green,
    RGB0_Red   => RGB0_Red,
    RGB1_Blue  => RGB1_Blue,
    RGB1_Green => RGB1_Green,
    RGB1_Red   => RGB1_Red,
    RGB2_Blue  => RGB2_Blue,
    RGB2_Green => RGB2_Green,
    RGB2_Red   => RGB2_Red,
    RGB3_Blue  => RGB3_Blue,
    RGB3_Green => RGB3_Green,
    RGB3_Red   => RGB3_Red,
    LED        => LED,
    ja         => ja,
    jb         => jb,
    jc         => jc,
    jd         => jd
  );

-- Apply pullups to unused FPGA inputs
multi_pu_loop1: for i in 0 to 3 generate
  i_pu1 : pullup1 PORT MAP (pin => SW(i));
  i_pu2 : pullup1 PORT MAP (pin => BTN(i));
end generate multi_pu_loop1;

SW <= "0110";

-- NOTE: Add pullups on MMC_CMD and MMC_DAT, since we are through
--       benefitting from seeing the 'Z' in simulation.  The true card
--       interface has pullups...
multi_pu_loop2: for i in 0 to 7 generate
  i_pu3 : pullup1 PORT MAP (pin => ja(i));
  i_pu4 : pullup1 PORT MAP (pin => jb(i));
  i_pu5 : pullup1 PORT MAP (pin => jc(i));
  i_pu6 : pullup1 PORT MAP (pin => jd(i));
end generate multi_pu_loop2;

-- Separate pullups, showing the function of each MMC pin
--pu1  : pullup1 port map(pin => jb(2)); -- MMC clk
--pu2  : pullup1 port map(pin => jb(6)); -- MMC cmd
--pu3  : pullup1 port map(pin => jc(0)); -- MMC data[0]
--pu4  : pullup1 port map(pin => jc(1)); -- MMC data[6]
--pu5  : pullup1 port map(pin => jc(2)); -- MMC data[4]
--pu6  : pullup1 port map(pin => jc(3)); -- MMC data[2]
--pu7  : pullup1 port map(pin => jc(4)); -- MMC data[1]
--pu8  : pullup1 port map(pin => jc(5)); -- MMC data[7]
--pu9  : pullup1 port map(pin => jc(6)); -- MMC data[5]
--pu10 : pullup1 port map(pin => jc(7)); -- MMC data[3]



end struct;