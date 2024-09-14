library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

entity mult is
    port (indata : in std_logic_vector(31 downto 0);
	  utdata : out std_logic_vector(31 downto 0);
	  factor : in std_logic_vector(6 downto 0);	
	  clk : in std_logic;
	  reset : in std_logic_vector(0 downto 0);
	  start : in std_logic_vector(0 downto 0);  
	  ready : out std_logic_vector(0 downto 0);
	  mastervol : in std_logic_vector(2 downto 0));
end mult;

architecture mymult of mult is


    signal thestate,nextstate : std_logic_vector(3 downto 0);
    signal data,nextdata : std_logic_vector(31 downto 0);
    signal fact,nextfact : std_logic_vector(6 downto 0);
    signal one,nextone : std_logic_vector(13 downto 0);
    signal two,nexttwo : std_logic_vector(13 downto 0);
    signal three,nextthree : std_logic_vector(13 downto 0);
    signal four,nextfour : std_logic_vector(13 downto 0);
    signal neg1,neg2,neg3,neg4 : std_logic;
    signal nextneg1,nextneg2,nextneg3,nextneg4 : std_logic;
begin				      
    utdata<=one(13 downto 6)&two(13 downto 6)&three(13 downto 6)&four(13 downto 6);
    
    process(indata,factor,start,thestate,data,fact,one,two,three,four,neg1,neg2,neg3,neg4,mastervol)
		variable tempmastervol : std_logic_vector(2 downto 0);
    begin
	ready<="0";
	nextdata<=data;
	nextfact<=fact;
	nextone<=one;
	nexttwo<=two;
	nextthree<=three;
	nextfour<=four;
	nextneg1<=neg1;
	nextneg2<=neg2;
	nextneg3<=neg3;
	nextneg4<=neg4;
	
	if thestate/="0000" then
	    nextstate<=thestate+1;    
	elsif start="1" then
	    nextstate<="0001";
	else
	    nextstate<=thestate;
	end if;
	
	case thestate is
	    when "0000" => 
		nextdata<=indata;
		tempmastervol:=mastervol;
		case tempmastervol is
			when "000" =>
				nextfact<=(others=>'0');
			when "001" =>
				nextfact<="000000"&factor(6 downto 6);
			when "010" =>
				nextfact<="00000"&factor(6 downto 5);
			when "011" => 
				nextfact<="0000"&factor(6 downto 4);
			when "100" =>
				nextfact<="000"&factor(6 downto 3);
			when "101" =>
				nextfact<="00"&factor(6 downto 2);
		 	when "110" =>
				nextfact<="0"&factor(6 downto 1);
			when others => -- "111"
				nextfact<=factor;
		end case;
		nextneg1<='0';
		nextneg2<='0';
		nextneg3<='0';
		nextneg4<='0';
	    when "0001" =>
		nextone<=(others=>'0');
		nexttwo<=(others=>'0');
		nextthree<=(others=>'0');
		nextfour<=(others=>'0');
		
		if data(31)='1' then
		    nextdata(31 downto 24)<=not data(31 downto 24)+1;
		    nextneg1<='1';
		end if;
		if data(23)='1' then
		    nextdata(23 downto 16)<=not data(23 downto 16)+1;
		    nextneg2<='1';
		end if;
		if data(15)='1' then
		    nextdata(15 downto 8)<=not data(15 downto 8)+1;
		    nextneg3<='1';
		end if;
		if data(7)='1' then
		    nextdata(7 downto 0)<=not data(7 downto 0)+1;
		    nextneg4<='1';
		end if;
		
	    when "0010"|"0011"|"0100"|"0101"|"0110"|"0111"|"1000" =>
		if fact(6)='1' then
		    nextone<=one(12 downto 0)&'0' + data(31 downto 24);
		    nexttwo<=two(12 downto 0)&'0' + data(23 downto 16);
		    nextthree<=three(12 downto 0)&'0' + data(15 downto 8);
		    nextfour<=four(12 downto 0)&'0' + data(7 downto 0);
		else
		    nextone<=one(12 downto 0)&'0';
		    nexttwo<=two(12 downto 0)&'0';
		    nextthree<=three(12 downto 0)&'0';
		    nextfour<=four(12 downto 0)&'0';
		end if;
		nextfact<=fact(5 downto 0)&'0';
	    when "1001" =>
		if neg1='1' then
		    nextone<=not one + 1;
		end if;
		if neg2='1' then
		    nexttwo<=not two + 1;
		end if;
		if neg3='1' then
		    nextthree<=not three + 1;
		end if;
		if neg4='1' then
		    nextfour<=not four + 1;
		end if;
		
		
	    when others =>
		ready <= "1";
		nextstate<="0000";
	end case;
    end process;

    process(clk,reset)
    begin
	if reset="0" then
	    one<=(others=>'0');
	    two<=(others=>'0');	    
	    three<=(others=>'0');
	    four<=(others=>'0');
	    thestate<=(others=>'0');
	    data<=(others=>'0');
	    fact<=(others=>'0');
	    neg1<='0';
	    neg2<='0';
	    neg3<='0';
	    neg4<='0';
	elsif rising_edge(clk) then
	    one<=nextone;
	    two<=nexttwo;	    
	    three<=nextthree;
	    four<=nextfour;
	    thestate<=nextstate;
	    data<=nextdata;
	    fact<=nextfact;
	    neg1<=nextneg1;
	    neg2<=nextneg2;
	    neg3<=nextneg3;
	    neg4<=nextneg4;
	end if;
    end process;
end mymult;


