library IEEE;
use IEEE.std_logic_1164.all;

entity memctrl is
    
    port (ramadr : in std_logic_vector(23 downto 0);
	  fbw,procdmemw : in std_logic_vector(0 downto 0);
	  ljudcs, bildcs, ramrw, globalrw : out std_logic_vector(0 downto 0);
	  clk : in std_logic);

    --globalrw 0=skrivning 1=lasning
    --ramoe 0=lasning 1=skrivning till minnet
end memctrl;

architecture thememctrl of memctrl is
    signal s_write : std_logic_vector(0 downto 0);
begin  -- thememctrl

    s_write<="1" when (fbw="1" and procdmemw="1") else "0";
    ramrw<="0" when (s_write="0" and clk='0' and ramadr(23 downto 21)="000") else "1"; 
    globalrw<=s_write;    

    process (ramadr)

    begin  -- process
	ljudcs<="1";
	bildcs<="1";
    
	case ramadr(23 downto 21) is
	    when "000" =>  		-- ram
		null;
	    when "010" =>  		-- ljud
		ljudcs<="0";
	    when "011" =>  		-- bild
		bildcs<="0";	       
	    when others => null;

	   end case;
    end process;
end thememctrl;
