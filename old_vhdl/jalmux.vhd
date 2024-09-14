library IEEE;
use IEEE.std_logic_1164.all;

entity jalmux is
    
    port (in0 : in std_logic_vector(4 downto 0);
	  sel : in std_logic_vector(0 downto 0);
	  out0 : out std_logic_vector(4 downto 0));

end jalmux;


architecture behaviour_mux of jalmux is
begin  
    process(in0, sel)
    begin
	out0<=in0;
	case sel is
	    when "0" => out0 <= in0;
	    when "1" => out0 <= "11111";  --spara aterhoppsadressen i reg 31
	    when others => null;
	end case;
    end process;
end behaviour_mux;
