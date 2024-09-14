
library IEEE;
use IEEE.std_logic_1164.all;
entity imem is
    
    port (from_proc_addr_in : in std_logic_vector(23 downto 0);  -- pc in
	  to_proc_data_out : out std_logic_vector(31 downto 0); -- instruktion ut
	  from_bus_data_in : in std_logic_vector(31 downto 0);
	  to_bus_addr_out : out std_logic_vector(23 downto 0);
	  arb_in : in std_logic_vector(0 downto 0);
	  stall_in : in std_logic_vector(0 downto 0));
end imem;

-- purpose: instruction memory with bus-request.
architecture behav_imem of imem is
    
begin  -- behav_imem


    process (from_proc_addr_in, arb_in, from_bus_data_in, stall_in)
	
    begin  -- process
	to_proc_data_out <= (others => '0');  -- nop!
	to_bus_addr_out <= from_proc_addr_in;

	if arb_in = "1" and stall_in = "1" then
	    to_proc_data_out <= from_bus_data_in;
	end if;
	
    end process;
    
end behav_imem;
