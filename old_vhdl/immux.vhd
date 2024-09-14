library IEEE;
use IEEE.std_logic_1164.all;

entity immux is
    
    port (in0,in1 : in std_logic_vector(31 downto 0);
	  sel : in std_logic_vector(0 downto 0);
	  out0 : out std_logic_vector(31 downto 0));

end immux;

architecture behaviour_mux of immux is
begin  
    process(in0, in1, sel)
    begin
	out0<=in0;
	case sel is
	    when "0" => out0 <= in0;
	    when "1" => out0 <= in1;
	    when others => null;
	end case;
    end process;
end behaviour_mux;
