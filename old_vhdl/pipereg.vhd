library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.std_logic_unsigned.all;

entity pipereg is
     generic (N : integer := 32);
 
 
    port (
	  in0 : in std_logic_vector(N downto 0);  -- write data
	  clk : in std_logic;  -- clock signal to feedback_c
	  out0 : out std_logic_vector(N downto 0);  -- register 1 data ut
	
	  update : in std_logic_vector(0 downto 0); -- write or not if1 then write
	  reset:in std_logic_vector(0 downto 0));
    
end pipereg;


architecture structure_std_reg of pipereg is
    

    signal next_data, data : std_logic_vector(N downto 0);

begin
    write : process(next_data, update, in0, data)
    begin
	out0 <= data;
	next_data <= data;
	if update = "1" then
	    next_data <= in0;
	end if;
    end process write;



    clocked : process (clk,reset)
    begin  -- process
	if reset="0" then
	    data<=(others=>'0');
	elsif (clk'EVENT) and (clk = '1') then
	    data <= next_data;
	end if;
	
    end process clocked;


    
end structure_std_reg;



