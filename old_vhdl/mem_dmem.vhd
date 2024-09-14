 
library IEEE;
use IEEE.std_logic_1164.all;
entity mem_dmem is
    
    port (to_proc_stall: out std_logic_vector(0 downto 0);
	  from_proc_read_in : in std_logic_vector(0 downto 0);
	  from_proc_write_in : in std_logic_vector(0 downto 0);
	  
	  clk : in std_logic;
	  reset : in std_logic_vector(0 downto 0);

	  to_bus_write : out std_logic_vector(0 downto 0);
	  
	  internal_arb_in : in std_logic_vector(0 downto 0);
	  to_arb_dmemwrite : out std_logic_vector(0 downto 0));

end mem_dmem;

-- purpose: instruction memory with bus-request.
architecture behav_mem_dmem of mem_dmem is
    type statemachinetype is (firststate,endstate);
    signal thestate,nextstate : statemachinetype;
begin  -- behav_mem_dmem

    
    
    process (internal_arb_in, from_proc_read_in, from_proc_write_in, thestate, reset)
	variable arb_r_w : std_logic_vector(2 downto 0);
    begin  -- process
	
	arb_r_w := internal_arb_in & from_proc_read_in & from_proc_write_in;

	to_bus_write <= "1";
	to_arb_dmemwrite <="0";
	to_proc_stall <="1";
	nextstate <= firststate;
	
	if reset = "1" then
	    case thestate is
		when firststate => 
		    case arb_r_w is
			when "110" =>  		-- arbin and read.
			    to_bus_write <= "1";
			    nextstate<=firststate;
			when "101" =>  		-- arbin and write.
			    to_bus_write <= "0";
			    to_arb_dmemwrite <="1";
			    to_proc_stall <="0";
			    nextstate<=endstate;
			when others =>
			    to_bus_write <= "1";
			    nextstate<=firststate;
		    end case;
		when endstate =>   -- 2nd write state.
		    to_bus_write <="1";		
		    nextstate<=firststate;
		when others => null;
	    end case;
	end if;
    end process;
    
    process(clk,reset)
    begin
	if reset="0" then
	    thestate<=firststate;
	elsif rising_edge(clk) then
	    thestate<=nextstate;
	end if;    
    end process;
end behav_mem_dmem;
