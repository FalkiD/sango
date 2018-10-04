--
-- Test Bench for S4
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.convert_pack.all;
use work.pull_pack_sim.all;
use work.sim_sdcard_host_pack.all;
use work.sim_uart_control_port_pack.all;

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
  constant TST_CLK_RATE : integer := 100000000; -- The clock rate at which the stimulus logic runs
  constant DUT_CLK_RATE : integer := 100000000; -- (Not used in this testbench.)

  ----------------------------------------------------------------------

  -- Component Declarations
  -----------------------------------
component s4
port (
  -- Comment these lines out to use FPGA_MCLK
  --FPGA_CLK      : in  std_logic;      --  P10   I        + Diff FPGA CLK From S4 Board U34/Si53307
  --FPGA_CLKn     : in  std_logic;      --  N10   I        - and A3/100MHx Oscillator can.

  ACTIVE_LEDn   : out std_logic;        --  T14   O

  MMC_CLK       : inout std_logic;      --  N11   I        MCU<-->MMC-Slave I/F 
  MMC_IRQn      : out std_logic;        --  P8    O        MCU SDIO_SD pin, low==MMC card present       
  MMC_CMD       : inout std_logic;      --  R7    I       

  MMC_DAT7      : inout std_logic;      --  R6    IO      
  MMC_DAT6      : inout std_logic;      --  T5    IO      
  MMC_DAT5      : inout std_logic;      --  T10   IO      
  MMC_DAT4      : inout std_logic;      --  T9    IO      
  MMC_DAT3      : inout std_logic;      --  T8    IO      
  MMC_DAT2      : inout std_logic;      --  T7    IO      
  MMC_DAT1      : inout std_logic;      --  R8    IO      
  MMC_DAT0      : inout std_logic;      --  P8    IO      

  TRIG_OUT      : out std_logic;        --  M16   O       
  TRIG_IN       : in  std_logic;        --  N13   I  

  FPGA_TXD      : out std_logic;        --  N16   O        MMC UART
  FPGA_RXD      : in  std_logic;        --  P15   I        MMC UART

                                        --     FPGA_MCLK is temporarily 102MHz LVCMOS33 FPGA Clk Input.  <JLC_TEMP_NO_L12>
  FPGA_MCLK     : in  std_logic;        --  R13   I                       
                                        --     FPGA_M*   is HW DBG I/F
  FPGA_MCU1     : out std_logic;        --  P10   I 
  FPGA_MCU2     : out std_logic;        --  P11   O
  FPGA_MCU3     : out std_logic;        --  R12   O    
  FPGA_MCU4     : out std_logic;        --  R13   O        
  MCU_TRIG      : in  std_logic;        --  T13   I       

  VGA_MOSI      : out std_logic;        --  B7    O        RF Power Setting SPI
  VGA_SCLK      : out std_logic;        --  B6    O        I/F
  VGA_SSn       : out std_logic;        --  B5    O       
  VGA_VSW       : out std_logic;        --  A5    O       
  VGA_VSWn      : out std_logic;        --  A3    O       

  SYN_MOSI      : out std_logic;        --  B2    O        LTC6946 RF Synth SPI I/F
  SYN_MISO      : in  std_logic;        --  A2    I       
  SYN_SCLK      : out std_logic;        --  C1    O       
  SYN_SSn       : out std_logic;        --  C1    O
  SYN_STAT      : in  std_logic;        --  B1    O
  SYN_MUTEn     : out std_logic;        --  E2    O

  DDS_MOSI      : out std_logic;        --  F2    O        AD9954 DDS SPI+ I/F
  DDS_MISO      : in  std_logic;        --  E1    I
  DDS_SSn       : out std_logic;        --  G2    O
  DDS_SCLK      : out std_logic;        --  G1    O       
  DDS_IORST     : out std_logic;        --  H2    O       
  DDS_IOUP      : out std_logic;        --  H1    O       
  DDS_SYNC      : out std_logic;        --  K1    O
  DDS_PS0       : out std_logic;        --  J1    O
  DDS_PS1       : out std_logic;        --  L2    O

  RF_GATE       : out std_logic;        --  C2    O        RF On/Off Keying/Biasing
  RF_GATE2      : out std_logic;        --  C3    O       
  DRV_BIAS_EN   : out std_logic;        --  A3    O                 
  PA_BIAS_EN    : out std_logic;        --  K2    O                 

  ZMON_EN       : out std_logic;        --  T2    O        ZMon SPI Cnvrt & Read I/F
  CONV          : out std_logic;        --  M1    O
  ADC_SCLK      : out std_logic;        --  R1    O
  ADCF_SDO      : in  std_logic;        --  N1    I
  ADCR_SDO      : in  std_logic;        --  P1    I
  ADCTRIG       : out std_logic;        --  T12   I        Trigger MCU ADC's

  FPGA_TXD2     : out std_logic;        --  R11   O        HW DBG UART
  FPGA_RXD2     : in  std_logic         --  R10   I        HW DBG UART
);
end component;

  -----------------------------------------------------------------------------
  -- Internal signal declarations

    -- Common Signals
  signal dut_clk       : std_logic := '0';
    -- Signals from unit under test, so they show up in testbench
  signal FPGA_CLK      : std_logic;      --  R13   I                       
  signal FPGA_CLKn     : std_logic;      --  N10   I        - and A3/100MHx Oscillator can.

  signal MMC_CLK       : std_logic;      --  N11   I        MCU<-->MMC-Slave I/F 
  signal MMC_IRQn      : std_logic := '0';     --  P8    O        MCU SDIO_SD pin, low==MMC card present       
  signal MMC_CMD       : std_logic;      --  R7    I       

  signal MMC_DAT7      : std_logic;      --  R6    IO      
  signal MMC_DAT6      : std_logic;      --  T5    IO      
  signal MMC_DAT5      : std_logic;      --  T10   IO      
  signal MMC_DAT4      : std_logic;      --  T9    IO      
  signal MMC_DAT3      : std_logic;      --  T8    IO      
  signal MMC_DAT2      : std_logic;      --  T7    IO      
  signal MMC_DAT1      : std_logic;      --  R8    IO      
  signal MMC_DAT0      : std_logic;      --  P8    IO      

  signal UART_RSP_o    : std_logic;      --  N16   O        MMC UART
  signal UART_CMD_i    : std_logic;      --  P15   I        MMC UART

  signal TRIG_IN       : std_logic;      -- External trigger input

                                         --     FPGA_MCLK is temporarily 102MHz LVCMOS33 FPGA Clk Input.  <JLC_TEMP_NO_L12>
  signal FPGA_MCLK     : std_logic;                        --  R13   I                       
                                         --     FPGA_M*   is HW DBG I/F
  signal FPGA_MCU1     : std_logic := '0';                --  P10   I 
  signal FPGA_MCU2     : std_logic := '0';                --  P11   O
  signal FPGA_MCU3     : std_logic := '0';                --  R12   O    
  signal FPGA_MCU4     : std_logic := '0';                --  R13   O        
  signal MCU_TRIG      : std_logic := '0';                --  T13   I       

  signal VGA_MOSI      : std_logic := '0';                --  B7    O        RF Power Setting SPI
  signal VGA_SCLK      : std_logic := '0';                --  B6    O        I/F
  signal VGA_SSn       : std_logic := '0';                --  B5    O       
  signal VGA_VSW       : std_logic := '0';                --  A5    O       
  signal VGA_VSWn      : std_logic := '0';                --  A3    O       

  signal SYN_MOSI      : std_logic := '0';                --  B2    O        LTC6946 RF Synth SPI I/F
  signal SYN_MISO      : std_logic := '0';                --  A2    I       
  signal SYN_SCLK      : std_logic := '0';                --  C1    O       
  signal SYN_SSn       : std_logic := '0';                --  C1    O
  signal SYN_STAT      : std_logic := '0';                --  B1    O
  signal SYN_MUTEn     : std_logic := '0';                --  E2    O

  signal DDS_MOSI      : std_logic := '0';                --  F2    O        AD9954 DDS SPI+ I/F
  signal DDS_MISO      : std_logic := '0';                --  E1    I
  signal DDS_SSn       : std_logic := '0';                --  G2    O
  signal DDS_SCLK      : std_logic := '0';                --  G1    O       
  signal DDS_IORST     : std_logic := '0';                --  H2    O       
  signal DDS_IOUP      : std_logic := '0';                --  H1    O       
  signal DDS_SYNC      : std_logic := '0';                --  K1    O
  signal DDS_PS0       : std_logic := '0';                --  J1    O
  signal DDS_PS1       : std_logic := '0';                --  L2    O

  signal RF_GATE       : std_logic := '0';                --  C2    O        RF On/Off Keying/Biasing
  signal RF_GATE2      : std_logic := '0';                --  C3    O       
  signal DRV_BIAS_EN   : std_logic := '0';                --  A3    O                 
  signal PA_BIAS_EN    : std_logic := '0';                --  K2    O                 

  signal ZMON_EN       : std_logic := '0';                --  T2    O        ZMon SPI Cnvrt & Read I/F
  signal CONV          : std_logic := '0';                --  M1    O
  signal ADC_SCLK      : std_logic := '0';                --  R1    O
  signal ADCF_SDO      : std_logic := '0';                --  N1    I
  signal ADCR_SDO      : std_logic := '0';                --  P1    I
  signal ADCTRIG       : std_logic := '0';                --  T12   I        CPU ZMon Req


  -- sim_sdcard_host signals
  signal mmc_cmd_o     : std_logic;
  signal mmc_cmd_i     : std_logic;
  signal mmc_cmd_oe    : std_logic;
  signal mmc_dat_o     : unsigned(7 downto 0);
  signal mmc_dat_i     : unsigned(7 downto 0);
  signal mmc_dat_oe    : std_logic := '0';

  -- uart_sim_control_port signals:
  signal sys_rst_n     : std_logic := '0'; 
  signal sys_clk       : std_logic := '0';

begin

  ------------------------------------------------------------------------
  -- Instantiate a serial control port
  -- In simulation, this takes the place of the UART debugger interface
  -- This unit also supplies the system clock "CLK"
  cp0 : sim_uart_control_port
  generic map(
    INPUT_FILE      =>  "uart_sim_in.txt",
    OUTPUT_FILE     => "uart_sim_out.txt",
    MSG_PREFIX      =>  "Serial debugger", -- Prefix of console output messages from this unit
    POR_DURATION    =>             500 ns, -- Duration of internal reset signal activity
    POR_ASSERT_LOW  =>               true, -- Determines polarity of reset output
    CLKRATE         =>       TST_CLK_RATE, -- Control Port clock rate default.
    UART_BAUDRATE   =>             921600, -- UART Speed, in bits per second.
    UART_PARITY     =>                  0, -- no parity
    LINE_LENGTH     =>                 64  -- Length of buffer to hold file input bytes
  )
  port map(
    -- Clock and reset stimulus
    test_rst => sys_rst_n,
    test_clk => sys_clk,
    -- UART I/O
    uart_tx  => UART_CMD_i,  -- HS async. Serial line to FPGA
    uart_rx  => UART_RSP_o   -- HS async. Serial line from FPGA
  );

  ------------------------------------------------------------------------
  -- Instantiate an sdcard_host control port
  -- In simulation, this takes the place of the MCU which normally acts as MMC host
  mmc_host1 : sim_sdcard_host
  generic map(
    -- relating to file I/O
    INPUT_FILE         => "./sdcard_host_sim_in.txt",
    OUTPUT_FILE        => "./sdcard_host_sim_out.txt",
    -- relating to the sdcard_host
    HOST_RAM_INIT_FILE => "./host_ram_init.txt",
    HOST_RAM_ADR_BITS  => 14            -- Determines amount of BRAM for sdcard_host
  )
  port map(

    -- Asynchronous system reset and system clock
    sys_rst_n      => sys_rst_n,
    sys_clk        => sys_clk,

    -- SD/MMC card signals
    mmc_clk_o      => MMC_CLK,
    mmc_cmd_i      => mmc_cmd_i,
    mmc_cmd_o      => mmc_cmd_o,
    mmc_cmd_oe_o   => mmc_cmd_oe,
    mmc_dat_i      => mmc_dat_i,
    mmc_dat_o      => mmc_dat_o,
    mmc_dat_oe_o   => mmc_dat_oe,
    mmc_dat_siz_o  => open

  );
  -- Connect the MMC bus between the sdcard_host and the unit under test
  mmc_cmd_i <= MMC_CMD;
  MMC_CMD   <= mmc_cmd_o when mmc_cmd_oe='1' else 'Z';
  mmc_dat_i <= MMC_DAT7 & MMC_DAT6 & MMC_DAT5 & MMC_DAT4 & MMC_DAT3 & MMC_DAT2 & MMC_DAT1 & MMC_DAT0;
  MMC_DAT0  <= mmc_dat_o(0) when mmc_dat_oe='1' else 'Z';
  MMC_DAT1  <= mmc_dat_o(1) when mmc_dat_oe='1' else 'Z';
  MMC_DAT2  <= mmc_dat_o(2) when mmc_dat_oe='1' else 'Z';
  MMC_DAT3  <= mmc_dat_o(3) when mmc_dat_oe='1' else 'Z';
  MMC_DAT4  <= mmc_dat_o(4) when mmc_dat_oe='1' else 'Z';
  MMC_DAT5  <= mmc_dat_o(5) when mmc_dat_oe='1' else 'Z';
  MMC_DAT6  <= mmc_dat_o(6) when mmc_dat_oe='1' else 'Z';
  MMC_DAT7  <= mmc_dat_o(7) when mmc_dat_oe='1' else 'Z';

  ------------------------------------------------------------------------
  -- Instantiate Unit Under Test
  dut_0 : s4
  port map(
      -- Comment these two lines when using FPGA_MCLK
      --FPGA_CLK    => CLK,
      --FPGA_CLKn   => not CLK,

      ACTIVE_LEDn =>  open,         --  T14   O
    
      MMC_CLK     => MMC_CLK,       --  N11   IO       MCU<-->MMC-Slave I/F 
      MMC_IRQn    => MMC_IRQn,      --  P8    O        MCU SDIO_SD pin, low==MMC card present       
      MMC_CMD     => MMC_CMD,       --  R7    IO       
    
      MMC_DAT7    => MMC_DAT7,      --  R6    IO      
      MMC_DAT6    => MMC_DAT6,      --  T5    IO      
      MMC_DAT5    => MMC_DAT5,      --  T10   IO      
      MMC_DAT4    => MMC_DAT4,      --  T9    IO      
      MMC_DAT3    => MMC_DAT3,      --  T8    IO      
      MMC_DAT2    => MMC_DAT2,      --  T7    IO      
      MMC_DAT1    => MMC_DAT1,      --  R8    IO      
      MMC_DAT0    => MMC_DAT0,      --  P8    IO      
    
      TRIG_OUT    => open,          --  M16   O       
      TRIG_IN     => TRIG_IN,       --  N13   I  
    
      FPGA_TXD    => UART_RSP_o,    --  N16   O        MMC UART
      FPGA_RXD    => UART_CMD_i,    --  P15   I        MMC UART

                                    --     FPGA_MCLK is temporarily 102MHz LVCMOS33 FPGA Clk Input.  <JLC_TEMP_NO_L12>
      FPGA_MCLK   => sys_clk,       --  R13   I                       
                                    --     FPGA_M*   is HW DBG I/F
      FPGA_MCU1   => FPGA_MCU1,     --  P10   I 
      FPGA_MCU2   => FPGA_MCU2,     --  P11   O
      FPGA_MCU3   => FPGA_MCU3,     --  R12   O    
      FPGA_MCU4   => FPGA_MCU4,     --  R13   O        
      MCU_TRIG    => MCU_TRIG,      --  T13   I       
    
      VGA_MOSI    => VGA_MOSI,      --  B7    O        RF Power Setting SPI
      VGA_SCLK    => VGA_SCLK,      --  B6    O        I/F
      VGA_SSn     => VGA_SSn,       --  B5    O       
      VGA_VSW     => VGA_VSW,       --  A5    O       
      VGA_VSWn    => VGA_VSWn,      --  A3    O       
    
      SYN_MOSI    => SYN_MOSI,      --  B2    O        LTC6946 RF Synth SPI I/F
      SYN_MISO    => SYN_MISO,      --  A2    I       
      SYN_SCLK    => SYN_SCLK,      --  C1    O       
      SYN_SSn     => SYN_SSn,       --  C1    O
      SYN_STAT    => SYN_STAT,      --  B1    O
      SYN_MUTEn   => SYN_MUTEn,     --  E2    O
    
      DDS_MOSI    => DDS_MOSI,      --  F2    O        AD9954 DDS SPI+ I/F
      DDS_MISO    => DDS_MISO,      --  E1    I
      DDS_SSn     => DDS_SSn,       --  G2    O
      DDS_SCLK    => DDS_SCLK,      --  G1    O       
      DDS_IORST   => DDS_IORST,     --  H2    O       
      DDS_IOUP    => DDS_IOUP,      --  H1    O       
      DDS_SYNC    => DDS_SYNC,      --  K1    O
      DDS_PS0     => DDS_PS0,       --  J1    O
      DDS_PS1     => DDS_PS1,       --  L2    O
    
      RF_GATE     => RF_GATE,       --  C2    O        RF On/Off Keying/Biasing
      RF_GATE2    => RF_GATE2,      --  C3    O       
      DRV_BIAS_EN => DRV_BIAS_EN,   --  A3    O                 
      PA_BIAS_EN  => PA_BIAS_EN,    --  K2    O                 
    
      ZMON_EN     => ZMON_EN,       --  T2    O        ZMon SPI Cnvrt & Read I/F
      CONV        => CONV,          --  M1    O
      ADC_SCLK    => ADC_SCLK,      --  R1    O
      ADCF_SDO    => ADCF_SDO,      --  N1    I
      ADCR_SDO    => ADCR_SDO,      --  P1    I
      ADCTRIG     => ADCTRIG,       --  T12   I        CPU ZMon Req
    
      FPGA_TXD2   => open,          --  R11   O        HW DBG UART
      FPGA_RXD2   => '1'            --  R10   I        HW DBG UART

  );

-- Apply pullups to unused FPGA inputs
--multi_pu_loop1: for i in 0 to 3 generate
--  i_pu1 : pullup1 PORT MAP (pin => SW(i));
--  i_pu2 : pullup1 PORT MAP (pin => BTN(i));
--end generate multi_pu_loop1;

-- Separate pullups
pu1  : pullup1 port map(pin => MMC_CLK);
pu2  : pullup1 port map(pin => MMC_CMD);
pu3  : pullup1 port map(pin => MMC_DAT0);
pu4  : pullup1 port map(pin => MMC_DAT1);
pu5  : pullup1 port map(pin => MMC_DAT2);
pu6  : pullup1 port map(pin => MMC_DAT3);
pu7  : pullup1 port map(pin => MMC_DAT4);
pu8  : pullup1 port map(pin => MMC_DAT5);
pu9  : pullup1 port map(pin => MMC_DAT6);
pu10 : pullup1 port map(pin => MMC_DAT7);

  ------------------------------------------------------------------------
  -- Set up independent DUT clock
  dut_clk_proc : process
    variable PS_PER_SECOND : real := 1.0E+12;
    variable half_period : time := integer(PS_PER_SECOND/(2.0*real(DUT_CLK_RATE))) * 1 ps;
    variable counter : integer := 10;    -- assert MCU_TRIG for 5 clocks at startup
    variable exttrig : integer := 200;   -- assert TRIG_IN every 100 clocks(200 half clocks)
    variable extcount: integer := 200;   -- assert TRIG_IN every 100 clocks
    variable trgwidth: integer := 0;
  begin
     --wait for 1/2 of the clock period;
     wait for half_period;
     dut_clk <= not dut_clk;
     FPGA_MCLK <= not dut_clk;
     if(counter = 10) then
       counter := counter - 1;
       MCU_TRIG <= '1';
     elsif (counter > 0) then
       counter := counter - 1;
     else
       MCU_TRIG <= '0';
     end if;
     
     if(counter <= 0) then
         extcount := extcount - 1;
         if(extcount > 0) then
           TRIG_IN <= '0';
         elsif (extcount = 0) then
           TRIG_IN <= '1';
           trgwidth := 20;
           extcount := -1;
         elsif (trgwidth > 0) then
            trgwidth := trgwidth - 1;
         elsif (trgwidth = 0) then
             extcount := exttrig;
         end if;
     end if;
     
  end process;

end struct;
