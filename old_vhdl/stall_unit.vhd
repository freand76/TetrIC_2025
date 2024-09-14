library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.std_logic_unsigned.all;

entity s_unit is
    
    port(dmem_stall, other_stall_1, other_stall_2 : in std_logic_vector(0 downto 0);
	 proc_stall : out std_logic_vector(0 downto 0));
end s_unit;

architecture structure_s_unit of s_unit is

begin
process(dmem_stall, other_stall_1, other_stall_2)
    begin
	proc_stall <= "1";
	if dmem_stall = "0" or other_stall_1 = "0" or other_stall_2 = "0" then
	    proc_stall <= "0";
	end if;
    end process;
    
end structure_s_unit;

