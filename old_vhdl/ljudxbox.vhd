library ieee;
use ieee.std_logic_1164.all;

entity ljudxbox is
    port(clk :in std_logic;
	 reset :in std_logic_vector(0 downto 0);
	 stall :in std_logic_vector(0 downto 0);
	 stepin :in std_logic_vector(0 downto 0);
	 rightin :in std_logic_vector(7 downto 0);
	 leftin : in std_logic_vector(7 downto 0);
	 soundwr : out std_logic_vector(0 downto 0);
	 soundaddr : out std_logic_vector(0 downto 0);
	 sounddata : out std_logic_vector(7 downto 0));
end ljudxbox;

architecture myljudxbox of ljudxbox is
    signal state,nextstate : integer range 0 to 5;
    signal pipereg1,nextpipereg1, pipereg2, nextpipereg2 : std_logic_vector(7 downto 0);
    signal leftpipe1, leftpipe2, leftpipe3, leftpipe4, leftpipe5 : std_logic_vector(7 downto 0);
    signal nextleftpipe1, nextleftpipe2, nextleftpipe3, nextleftpipe4, nextleftpipe5 : std_logic_vector(7 downto 0);
begin  -- myljudxbox
	
	nextpipereg1 <= rightin;
	nextpipereg2 <= pipereg1;
	nextleftpipe1 <= leftin;
	nextleftpipe2 <= leftpipe1;
	nextleftpipe3 <= leftpipe2;
	nextleftpipe4 <= leftpipe3;
	nextleftpipe5 <= leftpipe4;

    process(stepin, state,pipereg2, leftpipe5, stall)
    begin  -- process
	nextstate <= state;
	soundaddr <= "0";
	sounddata <= pipereg2;
	soundwr <= "1";
	case state is
	    when 0 =>
		if stall="1" then
		    nextstate <= state+1;
		end if;
	    when 1 =>
		sounddata <= pipereg2;
		if stepin="1" then
		    soundwr <= "0";
		    nextstate <= state+1;
		end if;
	    when 2 =>
		sounddata <= pipereg2;
		nextstate <= state+1;
	    when 3 =>
		soundaddr <= "1";
		sounddata <= leftpipe5;
		nextstate <= state+1;
	    when 4 =>
		soundaddr <= "1";
		sounddata <= leftpipe5;
		soundwr <= "0";
		nextstate <= state+1;
	    when 5 =>
		soundaddr <= "1";
		sounddata <= leftpipe5;
		nextstate <= 1;
	    when others =>
		nextstate <= 1;
	end case;
    end process;

    process (clk, reset)
	
    begin  -- process
	-- activities triggered by asynchronous reset (active low)
	if reset = "0" then
	    state <= 0;
	    pipereg1 <= (others => '0');
	    pipereg2 <= (others => '0');
	    leftpipe1 <= (others => '0');
	    leftpipe2 <= (others => '0');
	    leftpipe3 <= (others => '0');
	    leftpipe4 <= (others => '0');
	    leftpipe5 <= (others => '0');
	    
	-- activities triggered by rising edge of clock
	elsif clk'event and clk = '1' then
	    state <= nextstate;
	    pipereg1 <= nextpipereg1;
	    pipereg2 <= nextpipereg2;
	    leftpipe1 <= nextleftpipe1;
	    leftpipe2 <= nextleftpipe2;
	    leftpipe3 <= nextleftpipe3;
	    leftpipe4 <= nextleftpipe4;
	    leftpipe5 <= nextleftpipe5;
			 
	end if;
    end process;
					  
    
end myljudxbox;
