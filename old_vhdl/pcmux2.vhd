library IEEE;
use IEEE.STD_LOGIC_1164.all;
entity pcmux2 is
    
    port (in0 : in std_logic_vector(31 downto 0);
	  in1 : in std_logic_vector(31 downto 0);
	  sel : in std_logic_vector(0 downto 0);
	  out0 : out std_logic_vector(31 downto 0));

end pcmux2;

architecture mypcmux2 of pcmux2 is
    
begin  -- mypcmux2
    process (in0,in1,sel)
	
    begin  -- process
	out0<=in0;
	case sel is
	    when "0" =>out0<=in0;
	    when "1" =>out0<=in1;
	    when others=>null;
	end case;
    end process;
end mypcmux2;
