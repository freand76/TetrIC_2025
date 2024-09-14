library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

entity resample is
    
    port (clk : in std_logic;
	  step : in std_logic_vector(0 downto 0);
	  datain : in std_logic_vector(31 downto 0);
	  wr : in std_logic_vector(0 downto 0); -- multready
	  ack : in std_logic_vector(0 downto 0);  -- reqack
	  freq : in std_logic_vector(15 downto 0);
	  clr : in std_logic_vector(0 downto 0); 
	  running : in std_logic_vector(0 downto 0);
	  dataut : out std_logic_vector(7 downto 0);
	  req : out std_logic_vector(0 downto 0));  -- request

--port (clk : in std_logic;
--      reset : in std_logic_vector(0 downto 0);
--      reqack : in std_logic_vector(0 downto 0);
--      reqdata : in std_logic_vector(31 downto 0);
--      freq : in std_logic_vector(15 downto 0);
--      active : in std_logic_vector(0 downto 0); 
--      sampleout : out std_logic_vector(7 downto 0);
--      req : out std_logic_vector(0 downto 0);
    
end resample;

architecture myresample of resample is
    type samdatatype is array (0 to 3) of std_logic_vector(7 downto 0);
    
    signal samdata,nextsamdata : samdatatype;
    signal sampos,nextsampos : std_logic_vector(17 downto 0);
    signal newd,nextnewd : std_logic_vector(0 downto 0);
    signal thedata,nextthedata : std_logic_vector(7 downto 0);
	signal tempdata,nexttempdata : std_logic_vector(7 downto 0);

begin  -- myresample

    req<=newd and running;
    dataut<=tempdata;
	nexttempdata<=thedata;
    process(sampos,newd,ack,freq,step,thedata,samdata,running)
    begin
	nextnewd <= newd;
	nextsampos<=sampos;
	nextthedata<=thedata;
	if running = "1" then
	    if step="1" then
		nextsampos<=sampos+freq;
		nextthedata<=samdata(CONV_INTEGER(sampos(16 downto 15)));
	    end if;

	    if sampos(17)='1' then
		nextnewd<="1";
		nextsampos(17 downto 15)<="000";
	    elsif ack="1" then
		nextnewd<="0";
	    end if;
	else
	    nextthedata <= (others => '0');
	end if;
    end process;
   
	process(wr,datain,samdata)
	begin
		nextsamdata<=samdata;
		if wr="1" then
		    nextsamdata(0)<=datain(31 downto 24);
		    nextsamdata(1)<=datain(23 downto 16);
		    nextsamdata(2)<=datain(15 downto 8);
		    nextsamdata(3)<=datain(7 downto 0);
		end if;
	end process;
   
    process(clk,clr)
    begin
		if clr = "0" then
		    newd<="1";
	    	sampos<=(others=>'0');
			samdata(0)<=(others=>'0');
			samdata(1)<=(others=>'0');
			samdata(2)<=(others=>'0');
			samdata(3)<=(others=>'0');
			thedata<=(others=>'0');
	    	tempdata<=(others=>'0');
		elsif rising_edge(clk) then
		    tempdata<=nexttempdata;
			thedata<=nextthedata;
		    newd<=nextnewd;
		    sampos<=nextsampos(17 downto 0);	 
			samdata<=nextsamdata;
		end if;
    end process;
end myresample;



















