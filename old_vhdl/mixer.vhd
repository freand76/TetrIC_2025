library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

entity mixer is
    
    port (clk : in std_logic;
	  reset : in std_logic_vector(0 downto 0);
	  step : in std_logic_vector(0 downto 0);
	  data0 : in std_logic_vector(7 downto 0);
	  data1 : in std_logic_vector(7 downto 0);
	  data2 : in std_logic_vector(7 downto 0);
	  data3 : in std_logic_vector(7 downto 0);
	  sample : out std_logic_vector(7 downto 0)
	  );

end mixer;

-- purpose: mixar fyra kanaler till en
architecture mymixer of mixer is 

    signal nexttempdata,tempdata : std_logic_vector(9 downto 0);
    
begin  -- mymixer
    
 
    sample <= not tempdata(9 downto 9) & tempdata(8 downto 2);

    process (step,data0,data1,data2,data3,tempdata)
    variable plus0,plus1,plus2,plus3 : std_logic_vector(9 downto 0);

 

    begin  -- process
	nexttempdata <= tempdata;
	if step = "1" then
	    plus0 := data0(7 downto 7) & data0(7 downto 7) & data0;
	    plus1 := data1(7 downto 7) & data1(7 downto 7) & data1;
	    plus2 := data2(7 downto 7) & data2(7 downto 7) & data2;
	    plus3 := data3(7 downto 7) & data3(7 downto 7) & data3;
	    nexttempdata <=  plus0+plus1+plus2+plus3;

	end if;
    end process;

    process (clk, reset)
    begin  -- process
	if reset = "0" then
	    tempdata <= (others => '0');
			 
	-- activities triggered by rising edge of clock
	elsif clk'event and clk = '1' then
	    tempdata <= nexttempdata;
	end if;
    end process;
    
end mymixer;











