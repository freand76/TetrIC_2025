library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.std_logic_unsigned.all;

entity reg is
    
    port (reset :in std_logic_vector(0 downto 0);
	  rr1 : in std_logic_vector(4 downto 0);
	  rr2 : in std_logic_vector(4 downto 0);  -- read register 2
	  wr : in std_logic_vector(4 downto 0);  -- write register
	  wd : in std_logic_vector(31 downto 0);  -- write data
	  debug_reg1 : out std_logic_vector(31 downto 0);
	  clk : in std_logic;  -- clock signal to feedback_c
	  rd1 : out std_logic_vector(31 downto 0);  -- register 1 data ut
	  rd2 : out std_logic_vector(31 downto 0);  -- register 2 data ut
	  rw : in std_logic_vector(0 downto 0)); -- write or not if1 then write
    
end reg;


architecture structure_reg of reg is
    
    type big_ass_bus is array (31 downto 0) of std_logic_vector(31 downto 0);

    signal next_data, data : big_ass_bus;

begin

    debug_reg1 <= data(1);

    write : process (data, rw, wr, wd)
    begin
	next_data <= data;
	if (rw = "1") and (wr /= "00000") then
	    next_data(conv_integer(wr)) <= wd;
	end if;
	
    end process write;

    rd1 <= (others=>'0') when rr1 = "00000"
	   else next_data(conv_integer(rr1));
    
    rd2 <= (others=>'0') when rr2 = "00000"
	   else next_data(conv_integer(rr2));
		     

    update : process (clk, reset)
    begin  -- process
	if reset = "0" then 	
	    for supar_bengt in 31 downto 0 loop
		  data(supar_bengt) <= (others => '0');
	    end loop;  -- supar_bengt
	elsif (clk'EVENT) and (clk = '1') then
		data <= next_data;
	end if;
    end process update;


    
end structure_reg;



