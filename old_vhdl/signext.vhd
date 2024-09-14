library IEEE;
use IEEE.STD_LOGIC_1164.all;
entity signext is
    
    port (in0 : in std_logic_vector(15 downto 0);
	  out0 : out std_logic_vector(31 downto 0);
	  ctrin : in std_logic_vector(1 downto 0));

end signext;

architecture thesignext of signext is
    
begin  -- thesignext
    process (in0,ctrin)
	
    begin  -- process
	case ctrin is
	    when "00" =>if in0(15)='0' then  --signed extension
			    out0<="0000000000000000"&in0;
			else
			    out0<="1111111111111111"&in0;
			end if;
	    when "01" =>out0<="0000000000000000"&in0;  --unsigned extension
	    when "10" =>out0<="1111111111111111"&in0;  --fyll med ettor (andi)
	    when "11" =>out0<="0000000000000000"&in0;  --fyll med nollor (ori,xori)
	    when others => null;
	end case;
    end process;
end thesignext;
