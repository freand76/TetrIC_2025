library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

entity joyctrl is
    
    port (clk	: in std_logic;
	  reset : in std_logic_vector(0 downto 0);
	  joyin : in std_logic_vector(7 downto 0);
	  ctrlout : out std_logic_vector(7 downto 0));
end joyctrl;

architecture myjoyctrl of joyctrl is
    signal joyreg,nextjoyreg : std_logic_vector(7 downto 0);
begin  -- myjoyctrl

    nextjoyreg<=joyin;
    ctrlout<=joyreg;
    
    process(clk,reset)
    begin
	if reset="0" then
	    joyreg<=(others=>'0');
	elsif rising_edge(clk) then
	    joyreg<=nextjoyreg;
       	end if;
    end process;
    
end myjoyctrl;





