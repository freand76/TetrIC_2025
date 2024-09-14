 
library IEEE;
use IEEE.std_logic_1164.all;
entity ex_dmem is
    
    port (from_proc_read_in : in std_logic_vector(0 downto 0);
	  from_proc_write_in : in std_logic_vector(0 downto 0);
	  
	  stall_out : out std_logic_vector(0 downto 0);

	  internal_arb_out : out std_logic_vector(0 downto 0);
      
	  arb_in : in std_logic_vector(0 downto 0);
	  bus_req : out std_logic_vector(0 downto 0);
	  dmem_pre_write : out std_logic_vector(0 downto 0);
	  dmem_pre_read : out std_logic_vector(0 downto 0));

end ex_dmem;

-- purpose: instruction memory with bus-request.
architecture behav_ex_dmem of ex_dmem is
    
begin  -- behav_imem
    
    dmem_pre_write <= arb_in and from_proc_write_in;
    dmem_pre_read <= arb_in and from_proc_read_in;

    process (arb_in, from_proc_read_in, from_proc_write_in)
	variable want_bus : std_logic_vector(0 downto 0);

    begin  -- process
	stall_out <= "1";
	want_bus := from_proc_read_in or  from_proc_write_in;
	bus_req <= want_bus;
	
        internal_arb_out <= arb_in;        
	
	if arb_in = "0" and want_bus = "1" then
	    stall_out <= "0";
	end if;

    end process;

end behav_ex_dmem;
