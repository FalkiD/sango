--------------------------------------------------------------------------
-- Package of simulation control port components
--

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

package sim_bus_control_port_pack is

  component sim_bus_control_port
  generic(
    -- relating to file I/O
    INPUT_FILE      :  string;
    OUTPUT_FILE     :  string;
    MSG_PREFIX      :  string; -- Prefix of console output messages from this unit
    -- relating to the bus controller
    POR_DURATION    :    time;  -- Duration of internal reset signal activity
    POR_ASSERT_LOW  : boolean;  -- Determine polarity of reset signal
    CLKRATE         : integer;  -- Control Port clock rate
    LINE_LENGTH     : integer;  -- Length of buffer to hold file input bytes
    ADR_DIGITS      : natural; -- # of hex digits for address
    DAT_DIGITS      : natural; -- # of hex digits for data
    QTY_DIGITS      : natural; -- # of hex digits for quantity
    CMD_BUFFER_SIZE : natural; -- # of chars in the command buffer
    WATCHDOG_VALUE  : natural; -- # of sys_clks before ack is expected
    DISPLAY_FIELDS  : natural  -- # of fields/line
  );
  port(
    -- Clock and reset stimulus
    test_rst : out std_logic;
    test_clk : out std_logic;

    -- System Bus IO
    ack_i    : in  std_logic;
    err_i    : in  std_logic;
    dat_i    : in  unsigned(4*DAT_DIGITS-1 downto 0);
    dat_o    : out unsigned(4*DAT_DIGITS-1 downto 0);
    rst_o    : out std_logic;
    stb_o    : out std_logic;
    cyc_o    : out std_logic;
    adr_o    : out unsigned(4*ADR_DIGITS-1 downto 0);
    we_o     : out std_logic
  );
  end component;

  component binary_file_u8_bus_port
  generic(
    -- Settings
    FNAME_MAXLEN  : natural; -- Number of characters allocated for filename
    RD_FNAME_DEF  : string;  -- Default filename
    WR_FNAME_DEF  : string;  -- Default filename
    -- Register Defaults
    DEF_R_Z : unsigned(31 downto 0) -- Value returned for unimplemented registers
  );
  port(
    -- System I/Os
    sys_rst_n  : in   std_logic;
    sys_clk    : in   std_logic;
    sys_clk_en : in   std_logic;

    -- Register Bus interface
    adr_i      : in  unsigned(3 downto 0);
    sel_i      : in  std_logic;
    we_i       : in  std_logic;
    dat_i      : in  unsigned(31 downto 0);
    dat_o      : out unsigned(31 downto 0);
    ack_o      : out std_logic;

    -- Read Bus Interface
    rd_byte_o  : out unsigned(7 downto 0);
    rd_cyc_i   : in  std_logic;
    rd_ack_o   : out std_logic; -- Bus cycle acknowledge
    rd_err_o   : out std_logic; -- Bus cycle error

    -- Write Bus Interface
    wr_byte_i  : in  unsigned(7 downto 0);
    wr_cyc_i   : in  std_logic;
    wr_ack_o   : out std_logic; -- Bus cycle acknowledge
    wr_err_o   : out std_logic  -- Bus cycle error

  );
  end component;

end sim_bus_control_port_pack;

package body sim_bus_control_port_pack is
end sim_bus_control_port_pack;


---------------------------------------------------------------------------------------
-- Bus Controller for simulation use
---------------------------------------------------------------------------------------
--
-- Author: John Clayton
-- Date  : Dec. 27, 2013
-- Update: 12/27/13 Copied code from async_syscon_pack.vhd, Wrote some description
--                  Began merging in file I/O code from "uart_ascii_control_port_sim.vhd"
--          7/27/18 Added MSG_PREFIX generic, so that multiple instances can operate,
--                  each posting messages with a unique text prefix identifier.  Is
--                  that not nifty?
--
-- Description
---------------------------------------------------------------------------------------
-- This Bus Controller for simulation use combines a "ascii_syscon" module with a
-- "uart_ascii_control_port_sim" module, resulting in a single module that can use
-- file I/O for stimulus input and response output, while providing the parameterized
-- capabilities of the async_syscon module.  The purpose for combining these modules
-- is to eliminate the serial interface between them, thereby dramatically decreasing
-- simulation run times.
--
--   DESCRIPTION OF STIMULUS FILE I/O
--   --------------------------------
-- The stimulus file I/O introduces a "wrapper" around the characters which are fed
-- as stimulus into the command processor of the bus controller.  This is done so that
-- each command, after being issued, can be followed up with the requested delay before
-- issuing the next command.  Also, the structure of the stimulus input file contains
-- provisions for different types of stimulus, although only the 'd' and 'b' types are
-- implemented here:
--
--   'b' type = binary bus command with delay
--   'd' type = delay only; no command
--
-- The related module, "sim_uart_control_port" uses the 'u' type:
--
--   'u' type = UART bus command with delay
--
--   DESCRIPTION OF ASYNC_SYSCON DERIVED FUNCTIONALITY
--   -------------------------------------------------
-- This is a state-machine driven parallel 8-bit ASCII character interface to a "Wishbone"
-- type of bus.  It is intended to be used as a "Wishbone system controller"
-- for debugging purposes.  Specifically, the unit allows the user to send
-- text commands to the unit, in order to generate read and
-- write cycles on the Wishbone compatible bus.  The command structure is
-- quite terse and spartan in nature, this is for the sake of the logic itself.
-- Because the menu-driven command structure is supported without the use of
-- dedicated memory blocks (in order to maintain cross-platform portability
-- as much as possible) the menus and command responses were kept as small
-- as possible.  In most cases, the responses from the unit to the user
-- consist of a "newline" and one or two visible characters.  The command
-- structure consists of the following commands and responses:
--
-- Command Syntax              Purpose
-- ---------------             ---------------------------------------
-- w aaaa dddd dddd dddd...    Write data items "dddd" starting at address "aaaa"
--                             using sequential addresses.
--                             (If the data field is missing, nothing is done).
-- w0 aaaa dddd dddd dddd...   Write data items "dddd" at address "aaaa"
--                             without incrementing the address.
--                             (If the data field is missing, nothing is done).
-- f aaaa dddd xx              "Fill": Write data "dddd" starting at address "aaaa"
--                             perform this "xx" times at sequential addresses.
--                             (The quantity field is optional, default is 1).
-- f0 aaaa dddd xx             "Fill": Write data "dddd" starting at address "aaaa"
--                             perform this "xx" times at the same address.
--                             (The quantity field is optional, default is 1).
-- r aaaa xx                   Read data starting from address "aaaa."
--                             Perform this "xx" times at sequential addresses.
--                             (The quantity field is optional, default is 1).
-- r0 aaaa xx                  Read data from address "aaaa."
--                             Perform this "xx" times, using the same address.
--                             (The quantity field is optional, default is 1).
-- i                           Send a reset pulse to the system. (initialize).
--
-- <COMMENT_CHAR>              "Single Line" type Comment token.  Characters
--                             after the token are ignored until <ENTER>.
--                             This enables applications which send
--                             files to the unit to include comments for
--                             display and as an aid to understanding.
--                             The comment token is a constant, change it
--                             to be whatever makes sense!
--
-- Response from               Meaning
-- --------------------------  ---------------------------------------
-- OK                          Command received and performed.  No errors.
-- ?                           Command buffer full, without receiving "enter."
-- C?                          Command not recognized.
-- A?                          Address field syntax error.
-- D?                          Data field syntax error.
-- Q?                          Quantity field syntax error.
-- !                           No "ack_i", or else "err_i" received from bus.
-- B!                          No "bg_i" received from master.
--
-- NOTES on the operation of this unit:
--
-- - The unit generates a command prompt which is "-> ".
-- - Capitalization is not important.
-- - Each command is terminated by the "enter" key (0x0d character).
--   Commands are executed as soon as "enter" is received.
-- - Trailing parameters need not be re-entered.  Their values will
--   remain the same as their previous settings.
-- - Use of the backspace key is supported, so mistakes can be corrected.
-- - The length of the command line is limited to a fixed number of
--   characters, as configured by parameter.
-- - Fields are separated by white space, including "tab" and/or "space"
-- - All numerical fields are interpreted as hexadecimal numbers.
--   Decimal is not supported.
-- - Numerical field values are retained between commands.  If a "r" is issued
--   without any fields following it, the previous values will be used.  A
--   set of "quantity" reads will take place at sequential addresses.
--   If a "f" is issued without any fields following it, the previous data
--   value will be written "quantity" times at sequential addresses, starting
--   from the next location beyond where the last command ended.
-- - If the user does not wish to use "ack" functionality, simply tie the
--   "ack_i" input to logic 1, and then the ! response will never be generated.
-- - The data which is read in by the "r" command is displayed using lines
--   which begin with the address, followed by the data fields.  The number
--   of data fields displayed per line (following the address) is adjustable
--   by setting a parameter.  No other display format adjustments can be made.
-- - There is currently only a single watchdog timer.  It begins to count at
--   the time the "enter" is received to execute a command.  If the bus is granted
--   and the ack is received before the expiration of the timer, then the
--   cycle will complete normally.  Therefore, the watchdog timeout value
--   needs to include time for the request and granting of the bus, in
--   addition to the time needed for the actual bus cycle to complete.
--
--
-- Currently, there is only a single indicator (stb_o) generated during bus
-- output cycles which are generated from this unit.
-- The user can easily implement decoding logic based upon adr_o and stb_o
-- which would serve as multiple "stb_o" type signals for different cores
-- which would be sharing the same bus.
--
-- The data bus supported by this module is separate input/output type of bus.
-- However, if a single tri-state dat_io bus is desired, it can be added
-- to the module without too much trouble.  Supposedly the only difference
-- between the two forms of data bus is that one of them avoids using tri-state
-- at the cost of doubling the number of interconnects used to carry data back
-- and forth...  Some people say that tri-state should be avoided for use
-- in internal busses in ASICs.  Maybe they are right.
-- But in FPGAs tri-state seems to work pretty well, even for internal busses.
--
-- Parameters are provided to configure the width of the different command
-- fields.  To simplify the logic for binary to hexadecimal conversion, these
-- parameters allow adjustment in units of 1 hex digit, not anything smaller.
-- If your bus has 10 bits, for instance, simply set the address width to 3
-- which produces 12 bits, and then just don't use the 2 msbs of address
-- output.
--
-- No support for the optional Wishbone "retry" (rty_i) input is provided at
-- this time.
-- No support for "tagn_o" bits is provided at this time, although a register
-- might be added external to this module in order to implement to tag bits.
-- No BLOCK or RMW cycles are supported currently, so cyc_o is equivalent to
-- stb_o...
-- The output busses are not tri-stated.  The user may add tri-state buffers
-- external to the module, using "stb_o" to enable the buffer outputs.
--
-- By changing the MSG_PREFIX, one can customize the messages that appear in
-- the simulation console, making the simulation easier to understand.
--
---------------------------------------------------------------------------------------

library IEEE ;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

library std ;
use std.textio.all;

library work;
use work.convert_pack.all;
use work.async_syscon_pack.all;

entity sim_bus_control_port is
  generic (
    -- relating to file I/O
    INPUT_FILE      : string  := "./bus_sim_in.txt";
    OUTPUT_FILE     : string  := "./bus_sim_out.txt";
    MSG_PREFIX      : string  := "Bus "; -- Prefix of console output messages from this unit
    -- relating to the bus controller
    POR_DURATION    :   time  :=    500 ns;  -- Duration of internal reset signal activity
    POR_ASSERT_LOW  : boolean :=     false;  -- Determines polarity of reset output
    CLKRATE         : integer := 100000000;  -- Control Port clock rate default.
    LINE_LENGTH     : integer :=        40;  -- Length of buffer to hold file input bytes
    ADR_DIGITS      : natural :=         4; -- # of hex digits for address
    DAT_DIGITS      : natural :=         4; -- # of hex digits for data
    QTY_DIGITS      : natural :=         2; -- # of hex digits for quantity
    CMD_BUFFER_SIZE : natural :=        32; -- # of chars in the command buffer
    WATCHDOG_VALUE  : natural :=       200; -- # of sys_clks before ack is expected
    DISPLAY_FIELDS  : natural :=         8  -- # of fields/line
  );
  port(
    -- Clock and reset stimulus
    test_rst : out std_logic;  -- Programmable polarity
    test_clk : out std_logic;  -- Programmable frequency

    -- System Bus IO
    ack_i    : in  std_logic;
    err_i    : in  std_logic;
    dat_i    : in  unsigned(4*DAT_DIGITS-1 downto 0);
    dat_o    : out unsigned(4*DAT_DIGITS-1 downto 0);
    rst_o    : out std_logic;
    stb_o    : out std_logic;
    cyc_o    : out std_logic;
    adr_o    : out unsigned(4*ADR_DIGITS-1 downto 0);
    we_o     : out std_logic
  );
end sim_bus_control_port;

architecture beh of sim_bus_control_port is
-- File I/O Constants
constant BS_CHAR_U : unsigned(7 downto 0) := str2u("08",8);
constant CR_CHAR_U : unsigned(7 downto 0) := str2u("0D",8);
constant LF_CHAR_U : unsigned(7 downto 0) := str2u("0A",8);

-- File I/O Signals
-------------------
---- State Machine
TYPE   TST_STATE_TYPE IS (IDLE, CMD_CHAR_OP);
signal tst_state        : TST_STATE_TYPE;

---- Stimulus related signals
type   cmd_bytes_array is array (integer range 0 to LINE_LENGTH-1) of unsigned(7 downto 0);
signal cmd_bytes    : cmd_bytes_array;
signal cmd_byte_cnt : integer := 0;
signal tx_length    : integer;
signal new_stim     : boolean := false;
signal stim_kind    : character;

-- Internal signals
signal ctlr_test_clk_i  : std_logic := '0';
signal nhreset_internal : std_logic := '0';

-- System Controller Signals
signal cmd_char         : unsigned(7 downto 0);
signal cmd_we           : std_logic;
signal cmd_ack          : std_logic;
signal cmd_echo         : std_logic;
signal resp_char        : unsigned(7 downto 0);
signal resp_cyc         : std_logic;
signal resp_ack         : std_logic;

---------------------------------------------------------------------------------------
begin

-- File I/O Logic Statements

  test_clk    <= ctlr_test_clk_i;

  -------------------------
  -- Controller Clock Process
  -- Generates the Control Port clock
  ctlr_clk : process
    variable PS_PER_SECOND : real := 1.0E+12;
    variable half_period : time := integer(PS_PER_SECOND/(2.0*real(CLKRATE))) * 1 ps;
  begin
     --wait for 1/2 of the clock period;
     wait for half_period;
     ctlr_test_clk_i <= not (ctlr_test_clk_i);
  end process;

-------------------------
-- Reset Process
-- Causes reset to go inactive after a given time.
  rst_gen : process
  begin
    wait for POR_DURATION; -- Maybe wait long enough for the PLL to lock...
    nhreset_internal <= '1';
  end process;
  test_rst <= nhreset_internal when (POR_ASSERT_LOW) else not nhreset_internal;

-------------------------
-- Stimulus Process
-- Reads text input file and forms stimulus needed for the simulation.
  stim_proc: process(ctlr_test_clk_i, nhreset_internal)
    file s_file : text is in INPUT_FILE;
    variable time_mark    : time := 0 ns; -- Last NOW time when file IO was parsed
    variable time_val     : time := 0 ns; -- Relative time of next file IO parsing.
    variable line_1       : line;
    variable line_2       : line;
    variable item_count   : integer;
    variable line_num     : integer;
    variable line_done    : boolean;
    variable stim_done    : boolean;
    variable good         : boolean;
    variable temp_char    : character;
    variable stim_kind_v  : character; -- variable version readable immediately in display_stim
    variable cmd_found    : boolean;

    -- returns true is the character is a valid hexadecimal character.
    function is_hex(c : character) return boolean is
    begin
      case c is
        when '0' | '1' | '2' | '3' | '4' | '5' | '6' | '7' | '8' | '9' |
             'A' | 'B' | 'C' | 'D' | 'E' | 'F' | 'a' | 'b' | 'c' | 'd' | 
             'e' | 'f' =>
          return(true);
        when others =>
          return(false);
      end case;
    end is_hex;
      
    -- This prints the time and type of stimulus
    procedure display_stim is
    begin
      if (temp_char/='-') then
        write (line_2, string'(" [line "));
        write (line_2, line_num);
        write (line_2, string'(", at "));
        write (line_2, now, unit => ns);
        write (line_2, string'("]"));
        writeline (output, line_2);
      end if;
    end display_stim;
    
  begin
    if (nhreset_internal='0') then
      tx_length <= 0;
      line_num := 0;
    elsif (ctlr_test_clk_i'event and ctlr_test_clk_i = '1') then
      -- Default Values
      new_stim <= false;
      if (tst_state/=IDLE) then
        new_stim <= false;
      end if;
      -- Simulation Stimulus
      if (NOW > (time_val+time_mark)) then
        if not(endfile(s_file)) then
          readline(s_file, line_1);
          line_num := line_num+1;
          stim_done  := false;
          cmd_found  := false;
          item_count := 0;
          stim_kind   <= 'z'; -- Default
          stim_kind_v := 'z';
          if (line_1'length=0) then
            line_done := true;
          else
            line_done  := false;
          end if;
          while (line_done = false) loop
            read(line_1, temp_char, good);
            if (temp_char = '-' or temp_char = ';') then
              line_done := true;
            elsif (item_count=0 and temp_char/=' ') then
              stim_kind   <= temp_char;
              stim_kind_v := temp_char; -- Display stim uses this.  It cannot read stim_kind immediately.
              write (line_2,MSG_PREFIX);
              if (stim_kind_v='b') then
                write (line_2, string'(" command: "));
              elsif (stim_kind_v='d') then
                write (line_2, string'(" delay token. "));
              else
                write (line_2, string'(" unknown stimulus type encountered. No Action. "));
              end if;
              item_count  := item_count+1;
            elsif (item_count=1) then -- Time field read removes leading whitespace automatically.
              time_val := 0 ns;
              read(line_1, time_val);
              time_mark := NOW;
              item_count := item_count+1;
            end if;
            if (stim_kind_v='b') then
              if (item_count>1 and not line_done) then
                if (cmd_found) then
                  cmd_bytes(item_count-2) <= asciichar2u(temp_char);
                  write(line_2, temp_char); -- Keep record of cmd characters for display
                  item_count := item_count+1;
                else
                  if not is_space(temp_char) then
                    cmd_found := true;
                    cmd_bytes(item_count-2) <= asciichar2u(temp_char);
                    write(line_2, temp_char); -- Keep record of cmd characters for display
                    item_count := item_count+1;
                  end if;
                end if;
              elsif (item_count>1 and temp_char=';') then
                cmd_bytes(item_count-2) <= CR_CHAR_U;
                item_count := item_count+1;
              end if;
            end if;
            if (good=false) then
              line_done := true;
            end if;
          end loop;
          if (stim_kind_v='b') then
            tx_length <= item_count-2;
            new_stim <= true;
          end if;
          display_stim;
        elsif not (stim_done) then
          write (line_2, string'("At "));
          write (line_2, now, unit => ns);
          write (line_2, string'(", "));
          write (line_2,MSG_PREFIX);
          write (line_2, string'(" bus control port finished reading stimulus file. "));
          writeline (output, line_2);
          stim_done := true;
        end if;
      end if;
    end if;
        
  end process;

-------------------------
-- Response Record Process
  response_proc: process(ctlr_test_clk_i)
    file o_file : text is out OUTPUT_FILE;
    variable line_1       : line;
    variable line_2       : line;
    variable good         : boolean;
    variable header_done  : boolean := false;
    
  begin
    if not header_done then
      write (line_2, string'("Simulation Results File"));
      writeline (o_file, line_2);
      header_done := true;
    end if;
    if (ctlr_test_clk_i'event and ctlr_test_clk_i = '1') then
      if (cmd_echo='1' and cmd_ack='1') then
        if (cmd_char=BS_CHAR_U) then
          write (line_2, string'("<BS>"));
        elsif (cmd_char=CR_CHAR_U) then
          write (line_2, string'("<CR>"));
        elsif (cmd_char=LF_CHAR_U) then
          write (line_2, string'("<LF>"));
          writeline (o_file, line_2);
        else
--          write (line_2, u2string(cmd_char,2)); -- For Hexadecimal output
          write (line_2, u2asciichar(cmd_char)); -- For ASCII output
        end if;
      elsif (cmd_echo='0' and resp_ack='1') then
        if (resp_char=BS_CHAR_U) then
          write (line_2, string'("<BS>"));
        elsif (resp_char=CR_CHAR_U) then
          write (line_2, string'("<CR>"));
        elsif (resp_char=LF_CHAR_U) then
          write (line_2, string'("<LF>"));
          writeline (o_file, line_2);
        else
--          write (line_2, u2string(resp_char,2)); -- For Hexadecimal output
          write (line_2, u2asciichar(resp_char)); -- For ASCII output
        end if;
      end if;
    end if;
        
  end process;

  resp_ack <= resp_cyc;

-------------------------
-- Control Port State Machine
  cp_fsm_proc: process(ctlr_test_clk_i, nhreset_internal)
  begin
    if (nhreset_internal='0') then
      tst_state      <= IDLE;
      cmd_byte_cnt   <= 0;
    elsif (ctlr_test_clk_i'event and ctlr_test_clk_i = '1') then
      -- Default Values

      -- State machine
      case tst_state is

        when IDLE =>
          cmd_byte_cnt <= 0;
          if (new_stim) then
            if (stim_kind='b') then
              tst_state <= CMD_CHAR_OP;
            end if;
          end if;
          
        when CMD_CHAR_OP => -- Send Command Character
          if (cmd_ack='1') then
            cmd_byte_cnt <= cmd_byte_cnt+1;
          else
            cmd_byte_cnt <= 0;
            tst_state <= IDLE;
          end if;

      end case;
    end if;                                      -- end if(FPGA_CLK = 1)
  end process;

  cmd_char <= cmd_bytes(cmd_byte_cnt);
  cmd_we <= '1' when tst_state=CMD_CHAR_OP and cmd_byte_cnt<tx_length else '0';

syscon1 : ascii_syscon
    generic map(
      ADR_DIGITS      => ADR_DIGITS, -- # of hex digits for address
      DAT_DIGITS      => DAT_DIGITS, -- # of hex digits for data
      QTY_DIGITS      => QTY_DIGITS, -- # of hex digits for quantity
      CMD_BUFFER_SIZE => CMD_BUFFER_SIZE, -- # of chars in the command buffer
      WATCHDOG_VALUE  => WATCHDOG_VALUE, -- # of sys_clks before ack is expected
      DISPLAY_FIELDS  => DISPLAY_FIELDS -- # of fields/line
    )
    port map(
       
      sys_rst_n    => nhreset_internal,
      sys_clk      => ctlr_test_clk_i,
      sys_clk_en   => '1',

      -- Parallel ASCII I/O
      cmd_char_i   => cmd_char,
      cmd_we_i     => cmd_we,
      cmd_ack_o    => cmd_ack,
      cmd_echo_o   => cmd_echo,
      resp_char_o  => resp_char,
      resp_cyc_o   => resp_cyc,
      resp_ack_i   => resp_ack,
      cmd_done_o   => open,

      -- Master Bus IO
      master_bg_i  => '1',
      master_adr_i => to_unsigned(0,4*ADR_DIGITS),
      master_dat_i => to_unsigned(0,4*DAT_DIGITS),
      master_dat_o => open,
      master_stb_i => '0',
      master_we_i  => '0',
      master_br_o  => open,

      -- System Bus IO
      ack_i        => ack_i,
      err_i        => err_i,
      dat_i        => dat_i,
      dat_o        => dat_o,
      rst_o        => rst_o,
      stb_o        => stb_o,
      cyc_o        => cyc_o,
      adr_o        => adr_o,
      we_o         => we_o
    );



end beh;




-------------------------------------------------------------------------------
-- binary_file_u8_bus_port - Byte wide binary file bus read/write port
-------------------------------------------------------------------------------
--
-- Author: John Clayton
-- Date  : May  28, 2015 Created this code header, updated the description.
--         May  28, 2015 Tested and refined the component in simulation.
--
-- Description
-------------------------------------------------------------------------------
-- This module contains registers that specify a filename, a filename character
-- pointer, an active bit and a data byte.  These registers can be used to
-- open a binary file for reading, one byte at a time.  The data from the
-- file can be read using the data byte register, or through the bus interface.
--
-- Another filename, filename character pointer, active bit and data byte are
-- provided for opening a binary file for writing, one byte at a time.  The
-- data going into the file can be written using the data byte register, or
-- through the bus interface.
--
-- The filename is a null terminated ASCII string.
--
-- For reads:
-- When the read_active bit is set, the file is opened.  When the end of the
-- file is reached, read_active is cleared, and the rd_err_o signal is
-- asserted along with the rd_ack_o signal for read bus accesses.
--
-- For writes:
-- when the write_active bit is set, the file is opened.  When the write_active
-- bit is cleared, the file is closed.  Attempts to write data over the write
-- bus port while the file is closed cause wr_err_o to be asserted along with
-- wr_ack_o.
-- 
--
-- Accesses to the data byte register are given priority over the bus port.
--
-- Generics set the maximum filename length, and the default file name string
-- for both files.  The filenames must be different.  Also, each time the
-- file is opened, it "rewinds" to the beginning of the file.
--
-- This module is useful in testbenches, when file I/O is desired to be used
-- with synthesizable components.  This module is, of course, not
-- synthesizable.
--
-- The registers are summarized as follows:
--
-- Address      Structure   Function
-- -------      ---------   -----------------------------------------------------
--   0x0           (N:0)    Read Filename pointer. N=bit_width(FNAME_MAXLEN+1)
--   0x1           (7:0)    Read Filename characters
--   0x2           (0:0)    rd_active bit
--   0x3           (7:0)    Read data byte register
--   0x4           (N:0)    Write Filename pointer. N=bit_width(FNAME_MAXLEN+1)
--   0x5           (7:0)    Write Filename characters
--   0x6           (0:0)    wr_active bit
--   0x7           (7:0)    Write data byte register
--
--   Notes on Registers:
--
--   (0x0) and (0x4) Filename character pointer
--
--     The pointer increments each time the filename character register is
--     written or read.  It is cleared to zero whenever the active_bit is
--     cleared.  When the pointer reaches FNAME_MAXLEN-1, it stops
--     incrementing, and new characters overwrite the previous last character.
--
--   (0x1) and (0x5) Filename character register
--
--     The binary value of the next ASCII character is read or written at
--     this address.  The storage allocated for the filename is actually
--     one byte more than FNAME_MAXLEN, to ensure that the string is always
--     null terminated.
--
--   (0x2) and (0x6) active_bit
--
--     Setting this bit opens the file.  Clearing this bit closes the file.
--     If the file cannot be opened, this bit is cleared automatically.
--     For reads, if EOF is reached, this bit is cleared automatically.
--
--   (0x3) and (0x7) data byte register
--
--     This register address is one of two ways to access the file data.
--     The other way is through the associated bus port.
--
---------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library std ;
use std.textio.all;

library work;
use work.convert_pack.all;

entity binary_file_u8_bus_port is
  generic(
    -- Settings
    FNAME_MAXLEN  : natural := 24;          -- Number of characters allocated for filename
    RD_FNAME_DEF  : string  := "rdfoo.txt"; -- Default filename
    WR_FNAME_DEF  : string  := "wrfoo.txt"; -- Default filename
    -- Register Defaults
    DEF_R_Z : unsigned(31 downto 0) := str2u("00000000",32)  -- Value returned for unimplemented registers
  );
  port(
    -- System I/Os
    sys_rst_n  : in   std_logic;
    sys_clk    : in   std_logic;
    sys_clk_en : in   std_logic;

    -- Register Bus interface
    adr_i      : in  unsigned(3 downto 0);
    sel_i      : in  std_logic;
    we_i       : in  std_logic;
    dat_i      : in  unsigned(31 downto 0);
    dat_o      : out unsigned(31 downto 0);
    ack_o      : out std_logic;

    -- Read Bus Interface
    rd_byte_o  : out unsigned(7 downto 0);
    rd_cyc_i   : in  std_logic;
    rd_ack_o   : out std_logic; -- Bus cycle acknowledge
    rd_err_o   : out std_logic; -- Bus cycle error

    -- Write Bus Interface
    wr_byte_i  : in  unsigned(7 downto 0);
    wr_cyc_i   : in  std_logic;
    wr_ack_o   : out std_logic; -- Bus cycle acknowledge
    wr_err_o   : out std_logic  -- Bus cycle error

  );
end binary_file_u8_bus_port;

architecture beh of binary_file_u8_bus_port is

  constant FNAME_PTR_WIDTH : natural := bit_width(FNAME_MAXLEN+1);

  -- Register signals
  type fname_type is array (integer range 0 to FNAME_MAXLEN) of unsigned(7 downto 0); -- One extra character for null terminator
  signal rd_fname_ptr     : unsigned(FNAME_PTR_WIDTH-1 downto 0);
  signal rd_fname         : fname_type;
  signal rd_fname_byte_rd : unsigned(7 downto 0);
  signal rd_active        : unsigned(0 downto 0);
  signal wr_fname_ptr     : unsigned(FNAME_PTR_WIDTH-1 downto 0);
  signal wr_fname         : fname_type;
  signal wr_fname_byte_rd : unsigned(7 downto 0);
  signal wr_active        : unsigned(0 downto 0);

  -- File signals
  signal b1               : unsigned(7 downto 0) := "00000000";

begin

  -- Provide register bus cycle acknowledge immediately when selected
  ack_o <= sel_i;
  
  -- Register read mux
  with to_integer(adr_i) select
  dat_o <=
    u_resize(rd_fname_ptr,32)     when 0,
    u_resize(rd_fname_byte_rd,32) when 1,
    u_resize(rd_active,32)        when 2,
    u_resize(b1,32)               when 3,
    u_resize(wr_fname_ptr,32)     when 4,
    u_resize(wr_fname_byte_rd,32) when 5,
    u_resize(wr_active,32)        when 6,
    DEF_R_Z                       when others;

  -- Current filename byte
  rd_fname_byte_rd <= rd_fname(to_integer(rd_fname_ptr));

  rd_reg_proc: process(sys_clk, sys_rst_n)
  variable i : integer;
  variable fname_var : string(1 to FNAME_MAXLEN+1);
  type byte_file is file of character;
  file f1 : byte_file;
  variable c1 : character;
  variable fname_ptr_var  : integer := 0;
  variable l1 : line;
  begin
    if (sys_rst_n = '0') then
      for i in 1 to FNAME_MAXLEN+1 loop
        fname_var(i) := u2asciichar(to_unsigned(0,8));
        rd_fname(i-1) <= (others=>'0');
      end loop;
      if RD_FNAME_DEF'length<FNAME_MAXLEN then
        for i in RD_FNAME_DEF'range loop
          fname_var(i) := RD_FNAME_DEF(i);
          rd_fname(i-1) <= asciichar2u2(fname_var(i));
        end loop;
      else
        for i in 1 to FNAME_MAXLEN loop
          fname_var(i) := RD_FNAME_DEF(i);
          rd_fname(i-1) <= asciichar2u2(fname_var(i));
        end loop;
      end if;
      rd_fname_ptr <= to_unsigned(RD_FNAME_DEF'length-1,rd_fname_ptr'length);
      fname_ptr_var := RD_FNAME_DEF'length;
      rd_active <= (others=>'0');

    elsif (sys_clk'event and sys_clk='1') then

      -- Default values

      -- Handle bus writes to registers
      if (sel_i='1' and we_i='1') then
        case to_integer(adr_i) is
          when 0 =>
            rd_fname_ptr <= dat_i(FNAME_PTR_WIDTH-1 downto 0);
          when 1 =>
            rd_fname(to_integer(rd_fname_ptr)) <= dat_i(7 downto 0);
            fname_var(to_integer(rd_fname_ptr+1)) := u2asciichar(dat_i(7 downto 0));
          when 2 =>
            rd_active(0) <= dat_i(0);
            if (dat_i(0)='0') then
              rd_fname_ptr <= (others=>'0');
              file_close(f1);
              write(l1,string'("Binary read file "));
              write(l1,fname_var(1 to RD_FNAME_DEF'length));
              write(l1,string'(" closed by command."));
              writeline(output,l1);
            else
              file_open(f1,fname_var(1 to RD_FNAME_DEF'length),read_mode);
              write(l1,string'("Binary read file "));
              write(l1,fname_var(1 to RD_FNAME_DEF'length));
              write(l1,string'(" opened."));
              writeline(output,l1);
              if not endfile(f1) then
                read(f1,c1);
                b1 <= asciichar2u2(c1);
              else
                file_close(f1);
                rd_active(0) <= '0';
                write(l1,string'("Could not read a single byte from binary file "));
                write(l1,fname_var(1 to RD_FNAME_DEF'length));
                write(l1,string'(" !!!"));
                writeline(output,l1);
              end if;
            end if;
          -- Data is read only in this unit
          when 3 =>
            null;
          when others => null;
        end case;
      end if;
      -- Whenever filename is accessed, increment the pointer
      if (sel_i='1' and to_integer(adr_i)=1) then
        rd_fname_ptr <= rd_fname_ptr+1;
      end if;
      -- Whenever data is read from register address, obtain a new byte
      if (sel_i='1' and we_i='0' and to_integer(adr_i)=3) then
        if (rd_active(0)='1') then
          if not endfile(f1) then
            read(f1,c1);
            b1 <= asciichar2u2(c1);
          else
            file_close(f1);
            rd_active(0) <= '0';
            write(l1,string'("Binary read file "));
            write(l1,fname_var(1 to RD_FNAME_DEF'length));
            write(l1,string'(" closed when EOF encountered."));
            writeline(output,l1);
          end if;
        else
          write(l1,string'("Dang it!  Attempt to read [closed] binary file "));
          write(l1,fname_var(1 to RD_FNAME_DEF'length));
          write(l1,string'(", ain't gonna happen."));
          writeline(output,l1);
        end if;
      end if;
      -- Whenever data is read from bus, obtain a new byte
      if (rd_cyc_i='1' and sel_i='0') then
        if (rd_active(0)='1') then
          if not endfile(f1) then
            read(f1,c1);
            b1 <= asciichar2u2(c1);
          else
            file_close(f1);
            rd_active(0) <= '0';
            write(l1,string'("Binary read file "));
            write(l1,fname_var(1 to RD_FNAME_DEF'length));
            write(l1,string'(" closed when EOF encountered buring bus read."));
            writeline(output,l1);
          end if;
        else
          -- Uncomment to see message when bus attempts to read a closed file.
          -- rd_err_o is already provided, and printing the message takes extra time,
          -- so the message was commented out for reasons of economy.
          --write(l1,string'("Dang it!  Attempt to read [closed] binary file "));
          --write(l1,fname_var(1 to RD_FNAME_DEF'length));
          --write(l1,string'(", on the bus port ain't gonna happen."));
          --writeline(output,l1);
        end if;
      end if;

    end if;
  end process;

  rd_byte_o <= b1;
  rd_ack_o <= '1' when rd_cyc_i='1' and sel_i='0' else '0';
  rd_err_o <= '1' when rd_cyc_i='1' and sel_i='0' and rd_active(0)='0' else '0';


  -- Current filename byte
  wr_fname_byte_rd <= wr_fname(to_integer(wr_fname_ptr));

  wr_reg_proc: process(sys_clk, sys_rst_n)
  variable i : integer;
  variable fname_var : string(1 to FNAME_MAXLEN+1);
  type byte_file is file of character;
  file f1 : byte_file;
  variable c1 : character;
  variable fname_ptr_var  : integer := 0;
  variable l1 : line;
  begin
    if (sys_rst_n = '0') then
      for i in 1 to FNAME_MAXLEN+1 loop
        fname_var(i) := u2asciichar(to_unsigned(0,8));
        wr_fname(i-1) <= (others=>'0');
      end loop;
      if WR_FNAME_DEF'length<FNAME_MAXLEN then
        for i in WR_FNAME_DEF'range loop
          fname_var(i) := WR_FNAME_DEF(i);
          wr_fname(i-1) <= asciichar2u2(fname_var(i));
        end loop;
      else
        for i in 1 to FNAME_MAXLEN loop
          fname_var(i) := WR_FNAME_DEF(i);
          wr_fname(i-1) <= asciichar2u2(fname_var(i));
        end loop;
      end if;
      wr_fname_ptr <= to_unsigned(WR_FNAME_DEF'length-1,wr_fname_ptr'length);
      fname_ptr_var := WR_FNAME_DEF'length;
      wr_active <= (others=>'0');

    elsif (sys_clk'event and sys_clk='1') then

      -- Default values

      -- Handle bus writes to registers
      if (sel_i='1' and we_i='1') then
        case to_integer(adr_i) is
          when 4 =>
            wr_fname_ptr <= dat_i(FNAME_PTR_WIDTH-1 downto 0);
          when 5 =>
            wr_fname(to_integer(wr_fname_ptr)) <= dat_i(7 downto 0);
            fname_var(to_integer(wr_fname_ptr+1)) := u2asciichar(dat_i(7 downto 0));
          when 6 =>
            wr_active(0) <= dat_i(0);
            if (dat_i(0)='0') then
              wr_fname_ptr <= (others=>'0');
              file_close(f1);
              write(l1,string'("Binary write file "));
              write(l1,fname_var(1 to WR_FNAME_DEF'length));
              write(l1,string'(" closed by command."));
              writeline(output,l1);
            else
              file_open(f1,fname_var(1 to WR_FNAME_DEF'length),write_mode);
              write(l1,string'("Binary write file "));
              write(l1,fname_var(1 to WR_FNAME_DEF'length));
              write(l1,string'(" opened."));
              writeline(output,l1);
            end if;
          when 7 =>
            if (wr_active(0)='1') then
              c1 := u2asciichar(dat_i(7 downto 0));
              write(f1,c1);
            else
              write(l1,string'("Dang it!  Attempt to write [closed] binary file "));
              write(l1,fname_var(1 to WR_FNAME_DEF'length));
              write(l1,string'(", ain't gonna happen."));
              writeline(output,l1);
            end if;
          when others => null;
        end case;
      end if;
      -- Whenever filename is accessed, increment the pointer
      if (sel_i='1' and to_integer(adr_i)=5) then
        wr_fname_ptr <= wr_fname_ptr+1;
      end if;
      -- Handle writing data from the bus
      if (wr_cyc_i='1' and sel_i='0') then
        if (wr_active(0)='1') then
          c1 := u2asciichar(dat_i(7 downto 0));
          write(f1,c1);
        else
          -- Uncomment to see message when bus attempts to write a closed file.
          -- wr_err_o is already provided, and printing the message takes extra time,
          -- so the message was commented out for reasons of economy.
          --write(l1,string'("Dang it!  Bus attempt to write [closed] binary file "));
          --write(l1,fname_var(1 to WR_FNAME_DEF'length));
          --write(l1,string'(", ain't gonna happen."));
          --writeline(output,l1);
        end if;
      end if;

    end if;
  end process;

  wr_ack_o <= '1' when wr_cyc_i='1' and sel_i='0' else '0';
  wr_err_o <= '1' when wr_cyc_i='1' and sel_i='0' and wr_active(0)='0' else '0';


end beh;






