library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

entity debugbox is
    
    port (clk : in std_logic;
	  reset : in std_logic_vector(0 downto 0);
	  load : in std_logic_vector(0 downto 0);
	  debug_pc,
	  debug_reg,
	  debug_alu1in,
	  debug_alu2in,
	  debug_aluut,
	  debug_instr,
	  debug_ctrl : in std_logic_vector(31 downto 0);
	  serialout : out std_logic_vector(0 downto 0));
end debugbox;


architecture mydebugbox of debugbox is
    type machinetype is (loadstate,setupstate,pcstate,regstate,alu1instate,alu2instate,aluutstate,instrstate,ctrlstate,endstate);

    constant setup_const : std_logic_vector(31 downto 0) := X"F0F0FF00";
    
    signal thestate,nextthestate : machinetype;
    signal counter,nextcounter : integer range 0 to 31;

    signal
	sig_pc,next_sig_pc,
	sig_reg,next_sig_reg,
	sig_alu1in,next_sig_alu1in,
	sig_alu2in,next_sig_alu2in,
	sig_aluut,next_sig_aluut,
	sig_instr,next_sig_instr,
	sig_ctrl,next_sig_ctrl : std_logic_vector(31 downto 0);

    signal sig_ser_out : std_logic;
begin  -- mydebugbox

    serialout(0)<=sig_ser_out;
    
    process(thestate,counter,load,
	    sig_pc,sig_reg,sig_alu1in,sig_alu2in,sig_aluut,sig_instr,sig_ctrl,
	    debug_pc,debug_reg,debug_alu1in,debug_alu2in,debug_aluut,debug_instr,debug_ctrl)
    begin
	nextthestate<=thestate;
	nextcounter<=counter;
	next_sig_pc<=sig_pc;
	next_sig_reg<=sig_reg;
	next_sig_alu1in<=sig_alu1in;
	next_sig_alu2in<=sig_alu2in;
	next_sig_aluut<=sig_aluut;
	next_sig_instr<=sig_instr;
	next_sig_ctrl<=sig_ctrl;

	sig_ser_out<='1';
	
	case thestate is
	    when loadstate =>

		next_sig_pc<=debug_pc;
		next_sig_reg<=debug_reg;
		next_sig_alu1in<=debug_alu1in;
		next_sig_alu2in<=debug_alu2in;
		next_sig_aluut<=debug_aluut;
		next_sig_instr<=debug_instr;
		next_sig_ctrl<=debug_ctrl;
		
		if load="0" then
		    nextthestate<=setupstate;
		    nextcounter<=0;
		end if;
	    when setupstate =>
		sig_ser_out<=setup_const(counter);
		if counter=31 then
		    nextcounter<=0;
		    nextthestate<=pcstate;
		else
		    nextcounter<=counter+1;
		end if;		
	    when pcstate =>
		sig_ser_out<=sig_pc(31);
		next_sig_pc<=sig_pc(30 downto 0)&"0";
		if counter=31 then
		    nextcounter<=0;
		    nextthestate<=regstate;
		else
		    nextcounter<=counter+1;
		end if;
	    when regstate =>
		sig_ser_out<=sig_reg(31);
		next_sig_reg<=sig_reg(30 downto 0)&"0";
		if counter=31 then
		    nextcounter<=0;
		    nextthestate<=alu1instate;
		else
		    nextcounter<=counter+1;
		end if;
	    when alu1instate =>
		sig_ser_out<=sig_alu1in(31);
		next_sig_alu1in<=sig_alu1in(30 downto 0)&"0";
		if counter=31 then
		    nextcounter<=0;
		    nextthestate<=alu2instate;
		else
		    nextcounter<=counter+1;
		end if;
	    when alu2instate =>
		sig_ser_out<=sig_alu2in(31);
		next_sig_alu2in<=sig_alu2in(30 downto 0)&"0";
		if counter=31 then
		    nextcounter<=0;
		    nextthestate<=aluutstate;
		else
		    nextcounter<=counter+1;
		end if;
	    when aluutstate =>
		sig_ser_out<=sig_aluut(31);
		next_sig_aluut<=sig_aluut(30 downto 0)&"0";
		if counter=31 then
		    nextcounter<=0;
		    nextthestate<=instrstate;
		else
		    nextcounter<=counter+1;
		end if;
	    when instrstate =>
		sig_ser_out<=sig_instr(31);
		next_sig_instr<=sig_instr(30 downto 0)&"0";
		if counter=31 then
		    nextcounter<=0;
		    nextthestate<=ctrlstate;
		else
		    nextcounter<=counter+1;
		end if;
	    when ctrlstate =>
		sig_ser_out<=sig_ctrl(31);
		next_sig_ctrl<=sig_ctrl(30 downto 0)&"0";
		if counter=31 then
		    nextcounter<=0;
		    nextthestate<=endstate;
		else
		    nextcounter<=counter+1;
		end if;
	    when endstate =>
		if load="1" then
		    nextthestate<=loadstate;
		end if;
	    when others => null;
	end case;
    end process;

    process(clk,reset)
    begin
	if reset="0" then
	    thestate<=loadstate;
	    counter<=0;
	    sig_pc<=(others=>'0');
	    sig_reg<=(others=>'0');
	    sig_alu1in<=(others=>'0');
	    sig_alu2in<=(others=>'0');
	    sig_aluut<=(others=>'0');
	    sig_instr<=(others=>'0');
	    sig_ctrl<=(others=>'0');
	elsif rising_edge(clk) then
	    thestate<=nextthestate;
	    counter<=nextcounter;
	    sig_pc<=next_sig_pc;
	    sig_reg<=next_sig_reg;
	    sig_alu1in<=next_sig_alu1in;
	    sig_alu2in<=next_sig_alu2in;
	    sig_aluut<=next_sig_aluut;
	    sig_instr<=next_sig_instr;
	    sig_ctrl<=next_sig_ctrl;
	end if;
    end process;
end mydebugbox;
