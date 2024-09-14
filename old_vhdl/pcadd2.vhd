--changed by JP 20001125 20:55
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;
entity pcadd2 is
    
    port (in0, in1 : in std_logic_vector(31 downto 0);
	  out0 : out std_logic_vector(31 downto 0));

end pcadd2;

architecture mypcadd2 of pcadd2 is
    
begin  -- mypcadd2
 
    process (in0,in1)
    begin  -- process
	out0<= in0+in1;
    end process;
end mypcadd2;
