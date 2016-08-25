--
-- Package with Pullup and Pulldown
-- Useful in simulation
--
library IEEE ;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

package pull_pack_sim is

  component pullup1
    port( 
      pin : inout  std_logic
    );
  end component;

  component pulldn1
    port( 
      pin : inout  std_logic
    );
  end component;

end pull_pack_sim;

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------

library IEEE ;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

entity pullup1 is
  port( 
    pin : inout std_logic
  );
end pullup1;

architecture beh of pullup1 is
begin
  plp: process (pin)
  begin
    if (pin = '1') then
      pin <= '1';
    elsif (pin = 'Z') then
      pin <= '1';
    else
      pin <= 'Z';
    end if;
  end process;
end beh;

library IEEE ;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

entity pulldn1 is
  port( 
    pin : inout  std_logic
  );
end pulldn1;

architecture beh of pulldn1 is
begin
  plp: process (pin)
  begin
    if (pin = '0') then
      pin <= '0';
    elsif (pin = 'Z') then
      pin <= '0';
    else
      pin <= 'Z';
    end if;
  end process;
end beh;
