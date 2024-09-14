library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;


entity fakebox is
    port (data_ram : out std_logic_vector(31 downto 0);
	  addr_ram : out  std_logic_vector(23 downto 0);	-- 2 Megaord
	  write_ram : out std_logic_vector(0 downto 0);
	  data_flash : in std_logic_vector(7 downto 0);
	  addr_flash : out std_logic_vector(21 downto 0);	-- 2 Megabyte
	  oe_flash : out std_logic_vector(0 downto 0);
	  stall_out : out std_logic_vector(0 downto 0);
	  clock : in std_logic;
	  reset : in std_logic_vector(0 downto 0));

end fakebox;

architecture fb of fakebox is
    constant r_f_oe : std_logic_vector(0 downto 0):="0";
    constant cycles : integer := 7;

    type machinetype is (readflash1,readflash2,readflash3,readflash4,writeram,writeramend,idlestate);
    signal thestate,nextstate : machinetype;

    signal freg1,nextfreg1 : std_logic_vector(7 downto 0);
    signal freg2,nextfreg2 : std_logic_vector(7 downto 0);
    signal freg3,nextfreg3 : std_logic_vector(7 downto 0);
    signal freg4,nextfreg4 : std_logic_vector(7 downto 0);

    signal count,nextcount : std_logic_vector(2 downto 0);

    -- skall ändras för större rom
    signal faddr,nextfaddr : std_logic_vector(21 downto 0);
    signal ramaddr,nextramaddr : std_logic_vector(23 downto 0);
    
begin  -- fb

    
    process (thestate,freg1,freg2,freg3,freg4,faddr,ramaddr,count,
	     data_flash)
    begin
	data_ram<=freg1&freg2&freg3&freg4;
	addr_ram<=ramaddr;
	addr_flash<=faddr;
	write_ram<="1";
	oe_flash<=not r_f_oe;
	stall_out<="0";

	nextstate<=thestate;
	nextfreg1<=freg1;
	nextfreg2<=freg2;
	nextfreg3<=freg3;
	nextfreg4<=freg4;
	nextfaddr<=faddr;
	nextramaddr<=ramaddr;
	nextcount<=count+1;
	
	case thestate is
	    when readflash1 =>
		oe_flash<=r_f_oe;
		nextfreg1<=data_flash;
		if count=cycles then
		    nextcount<=(others=>'0');
		    nextfaddr<=faddr+1;
		    nextstate<=readflash2;
		end if;
	    when readflash2 =>
		oe_flash<=r_f_oe;
		nextfreg2<=data_flash;
		if count=cycles then
		    nextcount<=(others=>'0');
		    nextfaddr<=faddr+1;
		    nextstate<=readflash3;
		end if;
	    when readflash3 =>
		oe_flash<=r_f_oe;
		nextfreg3<=data_flash;
		if count=cycles then
		    nextcount<=(others=>'0');
		    nextfaddr<=faddr+1;
		    nextstate<=readflash4;
		end if;
	    when readflash4 =>
		oe_flash<=r_f_oe;
		nextfreg4<=data_flash;
		if count=cycles then
		    nextfaddr<=faddr+1;
		    nextstate<=writeram;
		end if;
	    when writeram =>
		write_ram<="0";
		nextstate<=writeramend;
       	    when writeramend =>
		write_ram<="1";
		nextramaddr<=ramaddr+1;
		if ramaddr=X"07FFFF" then  -- Flytta 2 Megabyte
		    nextstate<=idlestate;
		else
		    nextcount<=(others=>'0');
		    nextstate<=readflash1;
		end if;
	    when idlestate =>
		write_ram<="1";
		oe_flash<=not r_f_oe;
		stall_out<="1";
	    when others=>null;
	end case;
    end process;

    cl : process (clock, reset)
    begin  -- process cl
	if reset = "0" then
	    thestate<=readflash1;
	    freg1<=(others=>'0');
	    freg2<=(others=>'0');
	    freg3<=(others=>'0');
	    freg4<=(others=>'0');
	    count<=(others=>'0');
	    faddr<=(others=>'0');
	    ramaddr<=(others=>'0');
     	elsif rising_edge(clock) then
	    thestate<=nextstate;
	    freg1<=nextfreg1;
	    freg2<=nextfreg2;
	    freg3<=nextfreg3;
	    freg4<=nextfreg4;
	    count<=nextcount;
	    faddr<=nextfaddr;
	    ramaddr<=nextramaddr;
        end if;
    end process cl;
    
end fb;

