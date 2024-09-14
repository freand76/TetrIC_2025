library IEEE;
use IEEE.std_logic_1164.all;

entity datamux is
    
    port (in0, in1, in2 : in std_logic_vector(31 downto 0);
	  sel : in std_Logic_vector(1 downto 0);
	  out0 : out std_logic_vector(31 downto 0));

end datamux;
    
architecture behaviour_mux of datamux is
begin  
    process(in0, in1, in2, sel)
    begin
	out0<=in0;
	case sel is
	    when "00" => out0 <= in0;
	    when "01" => out0 <= in1;
	    when "10" => out0 <= in2;
	    when others => null;
	end case;
    end process;
end behaviour_mux;
