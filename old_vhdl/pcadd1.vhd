--updated by JP 2000-12-06
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;

entity pcadd1 is    
    port (pc : in std_logic_vector(31 downto 0);
	  stall : in std_logic_vector(0 downto 0);
	  imem_arb_in : in std_logic_vector(0 downto 0);
	  res : out std_logic_vector(31 downto 0));
end pcadd1;

architecture pc_adder of pcadd1 is
    
begin  -- pc_adder
    process(pc, stall, imem_arb_in)
    begin
	res <= pc;
	if stall = "1" and imem_arb_in = "1" then
	    res <= pc + 1;
	end if;
    end process;
end pc_adder;
