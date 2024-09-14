library IEEE;
use IEEE.std_logic_1164.all;

entity branchlogic is
    
    port (zero,overflow: in std_logic_vector(0 downto 0);
	  instr: in std_logic_vector(2 downto 0);
	  ctrpcmux3, ctrpcmux1 : out std_logic_vector(0 downto 0));

end branchlogic;

-- purpose: styr branch
architecture mybranchlogic of branchlogic is
    
begin  -- mybranchlogic
    process (zero,overflow,instr)
	
    begin  -- process
	ctrpcmux3<="0";
	ctrpcmux1<="0";
	if instr="011" then  		--jr och jalr
	    ctrpcmux3<="1";
	    ctrpcmux1<="1";
	end if;
	if (instr="001" and zero="0") then  	--beq
	    ctrpcmux3<="0";
	    ctrpcmux1<="1";
	end if;
	if instr="000" then  	--inget hopp
	    ctrpcmux3<="0";
	    ctrpcmux1<="0";
	end if;
	if (instr="010" and zero="1") then  	--bne
	    ctrpcmux3<="0";
	    ctrpcmux1<="1";
	end if;
	if instr="101" and (zero="0" or overflow="0") then  --bge
	    ctrpcmux3<="0";
	    ctrpcmux1<="1";
	end if;
	if instr="110" and zero="1" and overflow="0" then  --bgt
	    ctrpcmux3<="0";
	    ctrpcmux1<="1";
	end if;
	
    end process;
end mybranchlogic;
