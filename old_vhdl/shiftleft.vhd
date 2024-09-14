library IEEE;
use IEEE.std_logic_1164.all;

entity shiftleft is
    
    port (in0 : in std_logic_vector(31 downto 0);
	  out0  : out std_logic_vector(31 downto 0));

end shiftleft;

architecture physical of shiftleft is
    
begin
    process (in0)
    begin
	out0 <= (in0(31 downto 2) & "00"); 
    end process;
    
end physical;
