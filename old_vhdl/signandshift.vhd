-- updated by JP 2000-12-06
library IEEE;
use IEEE.STD_LOGIC_1164.all;
entity signandshift is
    
    port (in0 : in std_logic_vector(25 downto 0);
	  out0 : out std_logic_vector(31 downto 0));

end signandshift;

architecture shift_left_two of signandshift is
    
begin  -- signextend
    process (in0)
    begin
	out0 <= "000000" & in0;
    end process;
end shift_left_two;
