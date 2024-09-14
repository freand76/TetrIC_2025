library IEEE;
use IEEE.std_logic_1164.all;

entity fwunit is
    
    port (rt, rs, memregdest, wbregdest: in std_logic_vector(4 downto 0);
	  memregwr, wbregwr : in std_logic_vector(0 downto 0);
	  sel1, sel2 : out std_logic_vector(1 downto 0));

end fwunit;

architecture myfwunit of fwunit is
    
begin  -- myfwunit
    process (rt,rs,memregdest,wbregdest,memregwr,wbregwr)
    begin
	sel1<="00";
	sel2<="00";
	if rt=memregdest and memregwr="1" then
	    sel2<="10";
	end if;
	if rs=memregdest and memregwr="1" then
	    sel1<="10";
	end if;

	if ((rt=wbregdest and wbregwr="1" and rt/=memregdest) or (rt=wbregdest and wbregwr="1" and rt=memregdest and memregwr="0")) then
	    sel2<="01";
	end if;
	if ((rs=wbregdest and wbregwr="1" and rs/=memregdest) or (rs=wbregdest and wbregwr="1" and rt=memregdest and memregwr="0")) then
	    sel1<="01";
	end if;
	
    end process;
end myfwunit;
