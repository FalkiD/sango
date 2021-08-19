--------------------------------------------------------------------------
-- Package of simulation control port components
--

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

package sim_uart_control_port_pack is

  component sim_uart_control_port
  generic(
    INPUT_FILE     :  string;
    OUTPUT_FILE    :  string;
    POR_DURATION   :    time;  -- Duration of internal reset signal activity
    POR_ASSERT_LOW : boolean;  -- Determine polarity of reset signal
    CLKRATE        : integer;  -- Control Port clock rate default.
    UART_BAUDRATE  : integer;  -- UART Speed, in bits per second.
    UART_PARITY    : integer;  -- ODD parity
    LINE_LENGTH    : integer   -- Length of buffer to hold file input bytes
  );
  port(
    test_rst : out std_logic;
    test_clk : out std_logic;
    uart_tx  : out std_logic;  -- async. Serial line to FPGA
    uart_rx  : in  std_logic   -- async. Serial line from FPGA
  );
  end component;

end sim_uart_control_port_pack;

package body sim_uart_control_port_pack is
end sim_uart_control_port_pack;

-------------------------------------------------------------------------------
-- Simulation UART ASCII Control Port
-------------------------------------------------------------------------------
--
-- Author: John Clayton
-- Date  : Jan. 02, 2014 Transferred component into package file, wrote
--                       short description.
--
-- Description
-------------------------------------------------------------------------------
-- This is a component meant for simulation only.  It allows commands to be
-- read in from a file, parsed, and characters representing the desired
-- command are then sent out in asynchronous serial form, via a UART.
--
-- There is a delay specified with each command in the input file, which
-- determines how much time elapses between the current command and the
-- subsequent one.  Care must therefore be exercised when setting up the
-- simulation command input file, since commands which do not have
-- sufficient delay can cause subsequent commands to be ignored.
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
--   'u' type = UART bus command with delay
--
-- The related module, "sim_bus_control_port" uses the 'b' type:
--
--   'b' type = binary bus command with delay
--   'd' type = delay only; no command
--
-- The line is terminated with one of these characters:
--   ';' (Sends a Carriage Return, 0x0D)
--   '\' (Sends an Escape character, 0x1B)
--   '-' (Sends a Carriage Return, and ignores the remainder of the line as a comment)


library IEEE ;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

library std ;
use std.textio.all;

library work;
use work.convert_pack.all;
use work.uart_sqclk_pack.all;

entity sim_uart_control_port is
  generic(
    INPUT_FILE     : string  := ".\uart_sim_in.txt";
    OUTPUT_FILE    : string  := ".\uart_sim_out.txt";
    POR_DURATION   :   time  :=    500 ns;  -- Duration of internal reset signal activity
    POR_ASSERT_LOW : boolean :=     false;  -- Determines polarity of reset output
    CLKRATE        : integer := 100000000;  -- Control Port clock rate default.
    UART_BAUDRATE  : integer :=    921600;  -- UART Speed, in bits per second.
    UART_PARITY    : integer :=         2;  -- ODD parity
    LINE_LENGTH    : integer :=        40   -- Length of buffer to hold file input bytes
  );
  port(
    test_rst : out std_logic;  -- Programmable polarity
    test_clk : out std_logic;  -- Programmable frequency
    uart_tx  : out std_logic;  -- HS async. Serial line to FPGA
    uart_rx  : in  std_logic   -- HS async. Serial line from FPGA
  );
end sim_uart_control_port;

architecture beh of sim_uart_control_port is

---- Constants
constant BS_CHAR_U : unsigned(7 downto 0) := str2u("08",8);
constant CR_CHAR_U : unsigned(7 downto 0) := str2u("0D",8);
constant LF_CHAR_U : unsigned(7 downto 0) := str2u("0A",8);
constant ES_CHAR_U : unsigned(7 downto 0) := str2u("1B",8); -- Escape character

---- Components

---- State Machine
TYPE   TST_STATE_TYPE IS (IDLE, UART_TX_OP);
signal tst_state        : TST_STATE_TYPE;

---- Stimulus related signals
type   cmd_bytes_array is array (integer range 0 to LINE_LENGTH-1) of unsigned(7 downto 0);
signal cmd_bytes    : cmd_bytes_array;
signal cmd_byte_cnt : integer;
signal tx_length    : integer;
signal new_stim     : boolean := false;
signal stim_kind    : character;

-- Internal signals
signal ctlr_test_clk_i  : std_logic := '0';
signal nhreset_internal : std_logic := '0';

  -- Clock generator signals
signal uart_dds_phase  : unsigned(15 downto 0);
signal uart_clk        : std_logic;

  -- UART signals
signal tx_wr       : std_logic;
signal tx_data     : unsigned(7 downto 0);
signal tx_done     : std_logic;
signal tx_done_qld : std_logic; -- Qualified tx_done, stays low when tx_wr is high.
signal rx_wr       : std_logic;
signal rx_data     : unsigned(7 downto 0);
signal rx_done     : std_logic;
signal parity      : unsigned(1 downto 0);  -- Parity setting.
signal uart_rate   : unsigned(15 downto 0); -- Bit rate setting.


BEGIN

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
    variable dchar_i      : integer;

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
          line_num   := line_num+1;
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
            if (temp_char = '-' or temp_char = ';' or temp_char = '\') then
              line_done := true;
            elsif (item_count=0 and temp_char/=' ') then
              stim_kind   <= temp_char;
              stim_kind_v := temp_char; -- Display stim uses this.  It cannot read stim_kind immediately.
              if (stim_kind_v='u') then
                write(line_2,string'("UART Command: "));
              elsif (stim_kind_v='d') then
                write(line_2,string'("UART Delay Token. "));
              else
                write(line_2,string'("UART Unknown stimulus type encountered.  No action taken."));
              end if;
              item_count  := item_count+1;
            elsif (item_count=1) then -- Time field read removes leading whitespace automatically.
              time_val := 0 ns;
              read(line_1, time_val);
              time_mark := NOW;
              item_count := item_count+1;
            end if;
            if (stim_kind_v='u') then
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
              elsif (item_count>1 and temp_char='\') then
                cmd_bytes(item_count-2) <= ES_CHAR_U;
                item_count := item_count+1;
              end if;
            end if;
            if (good=false) then
              line_done := true;
            end if;
          end loop;
          if (stim_kind_v='u') then
            tx_length <= item_count-2;
            new_stim <= true;
          end if;
          display_stim;
        elsif not (stim_done) then
          write (line_2, string'("At "));
          write (line_2, now, unit => ns);
          write (line_2, string'(", UART control port finished reading stimulus file. "));
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
      if (rx_wr='1') then
        if (rx_data=BS_CHAR_U) then
          write (line_2, string'("<BS>"));
        elsif (rx_data=CR_CHAR_U) then
          write (line_2, string'("<CR>"));
        elsif (rx_data=LF_CHAR_U) then
          write (line_2, string'("<LF>"));
          writeline (o_file, line_2);
--          write (line_2, string'("At "));
--          write (line_2, now, justified => RIGHT, field => 12, unit => us);
--          write (line_2, string'(", received line feed."));
--          writeline (o_file, line_2);
        else
--          write (line_2, u2string(rx_data,2)); -- For Hexadecimal output
          write (line_2, u2asciichar(rx_data)); -- For ASCII output
        end if;
      end if;
    end if;
        
  end process;

-------------------------
-- Control Port State Machine
-- For async., loads and awaits TX completion for the three TLM bytes.
-- For CMD, simply starts the transmitter and waits for completion.
  cp_fsm_proc: process(ctlr_test_clk_i, nhreset_internal)
  begin
    if (nhreset_internal='0') then
      tst_state  <= IDLE;
      tx_wr      <= '0';
      tx_data    <= (others=>'0');
      cmd_byte_cnt   <= 0;
    elsif (ctlr_test_clk_i'event and ctlr_test_clk_i = '1') then
      -- Default Values
      tx_wr      <= '0';
      tx_data    <= (others=>'0');
      case tst_state is

        when IDLE =>
          cmd_byte_cnt <= 0;
          if (new_stim) then
            if (stim_kind='u') then
              tst_state <= UART_TX_OP;
            end if;
          end if;
          
        when UART_TX_OP =>         -- Send out the bytes
          if (tx_done_qld = '1') then
            if (cmd_byte_cnt = tx_length) then
              cmd_byte_cnt <= 0;
              tst_state <= IDLE;
            else
              tx_wr   <= '1';
              cmd_byte_cnt <= cmd_byte_cnt+1;
              tx_data <= cmd_bytes(cmd_byte_cnt);
            end if;
          end if;

      end case;
    end if;                                      -- end if(FPGA_CLK = 1)
  end process;

  tx_done_qld <= (tx_done and not tx_wr);

-------------------------
-- UART without buffer
  tst_uart: uart_sqclk
    port map ( 

      sys_rst_n     => nhreset_internal,
      sys_clk       => ctlr_test_clk_i,
      sys_clk_en    => '1',
       
      -- rate and parity
      parity_i      => parity,
      rate_clk_i    => uart_clk,

      -- serial I/O
      tx_stream     => uart_tx,
      rx_stream     => uart_rx,

      --control and status
      tx_wr_i       => tx_wr,
      tx_dat_i      => tx_data,
      tx_done_o     => tx_done,
      rx_restart_i  => '0',
      rx_dat_o      => rx_data,
      rx_wr_o       => rx_wr,
      rx_done_o     => rx_done,
      frame_err_o   => open,
      parity_err_o  => open
    );

  -- UART settings
  parity    <= to_unsigned(UART_PARITY,parity'length);
  uart_rate <= to_unsigned(integer(real(2**16)*real(UART_BAUDRATE)/real(CLKRATE)),16);

  -------------------------
  -- UART Clock Process
  uart_dds: process(nhreset_internal,ctlr_test_clk_i)
  begin
    if (nhreset_internal = '0') then
      uart_dds_phase   <= (others=>'0');
    elsif (ctlr_test_clk_i'event and ctlr_test_clk_i='1') then
      uart_dds_phase <= uart_dds_phase + uart_rate;
    end if;
  end process uart_dds;
  uart_clk <= uart_dds_phase(15);


end beh;



