-------------------------------------------------------------------------------
-- MOD: Adresser CPU kan skriva (6 laegst signifikanta bitar)
-- xxxx000000 (00/00): adress till MODdata (24 bits)
-- xxxx000001 (01/01): (adress till lookupdata - 108) (24 bits)
-- xxxx000010 (02/02): mute, bitpattern. bit 7 = ch0, bit 0 = ch 7. 1 = on, 0 = mute (8 bits)
-- xxxx000011 (03/03): loop/pause/start. 1 = true, 0 false. "x01" = start mod (3 bits) 
-- xxxx000100 (04/04): sample startaddress, channel 4 (24 bits)
-- xxxx000101 (05/05): sample startaddress, channel 5 (24 bits)
-- xxxx000110 (06/06): sample startaddress, channel 6 (24 bits)
-- xxxx000111 (07/07): sample startaddress, channel 7 (24 bits)
-- xxxx001000 (08/08): sample volume, channel 4 (7 bits, 0-64 valid values)
-- xxxx001001 (09/09): sample volume, channel 5 (7 bits)
-- xxxx001010 (0A/10): sample volume, channel 6 (7 bits)
-- xxxx001011 (0B/11): sample volume, channel 7 (7 bits)
-- xxxx001100 (0C/12): sample endaddress, channel 4 (24 bits)
-- xxxx001101 (0D/13): sample endaddress, channel 5 (24 bits)
-- xxxx001110 (0E/14): sample endaddress, channel 6 (24 bits)
-- xxxx001111 (0F/15): sample endaddress, channel 7 (24 bits)
-- xxxx010000 (10/16): sample loopstartaddress, channel 4 (24 bits)
-- xxxx010001 (11/17): sample loopstartaddress, channel 5 (24 bits)
-- xxxx010010 (12/18): sample loopstartaddress, channel 6 (24 bits)
-- xxxx010011 (13/19): sample loopstartaddress, channel 7 (24 bits)
-- xxxx010100 (14/20): sample loopendaddress, channel 4 (24 bits)
-- xxxx010101 (15/21): sample loopendaddress, channel 5 (24 bits)
-- xxxx010110 (16/22): sample loopendaddress, channel 6 (24 bits)
-- xxxx010111 (17/23): sample loopendaddress, channel 7 (24 bits)
-- xxxx011000 (18/24): sample frequency, channel 4 (16 bits)
-- xxxx011001 (19/25): sample frequency, channel 5 (16 bits)
-- xxxx011010 (1A/26): sample frequency, channel 6 (16 bits)
-- xxxx011011 (1B/27): sample frequency, channel 7 (16 bits)
-- xxxx011100 (1C/28): clockdivider, MODticks (20 bits) - value: ClockFreq/50
-- xxxx011101 (1D/29): clockdivider, sampleclock (20 bits) - value: ClockFreq/32768
-- xxxx011110 (1E): Nope... Not Used.
-- xxxx011111 (1F/31): Muxselect, vaelj vilken registerdata CPU ska kunna laesa.
-- xxxx1xxxxx (20-3F): Not Used either. Surprise huh? 
-------------------------------------------------------------------------------
-- Naat nytt?
-- *) Pause inlagt. Pausesignal <= "1" vilket staenger av raeknarna, mutar alla
-- kanaler, och hoppar till Pausemachinestate. Daerifraan kommer man bara om
-- CPU skriver "x01" till register 03 (startar MOD:en igen), och omedelbart
-- daerefter skriver onskat bitpattern till register 02 ("unmute:ar" kanalerna).
-- *) Registerskrivningar inlagda. Duh! Funkar? det aatersaar att se... =)
-- *) stod for 16/32/whatever MHz klockfrekvens. Funkar genom att CPU (eller
-- naan annan som har kontrol over databussen) skriver onskade klockdividender
-- i reg $18 och $19 enl. ovan. Vaerdena ska vara Klockfrekvens/50 respektive Klockfrekvens/32768.
-- Reg $18 kan anvaendas av proc att delvis implementera effekt ??, SetSpeed.
-- Om en mod med annan BPM aen 125 spelas fixar CPU det med en skrivning...
-- *) naan mindre detalj jag glomt nu...



-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- NOTERA:
-- alla pekare och offset i moddatan ar i byte -> hogerskifta 2 bitar.
-- varje nextreadaddress tilldelning medor en automatisk lasning en clk senare
-- i state_1_B ar skillnaden mellan instr- och noinstr fallen vilken address
-- som laggs ut
-- notelookupaddress pekar paa tabell med dwords (frekvenser) varav 16 ovre
-- bitar oanvanda. kan med lite (mycket) jobb av CPUn anvandas till annat.
--
-- fundera pa: en raknare som raknar ner 32MHz till tempo (2*bmp/5), tempo [32 => 102]
-- raknarens varde kan klammas in i lookuptabellen
--
-- kan bli timingproblem, framst nar resampler kraver ny data just som
-- updaterow paborjats. (kanske kolla om nan behover data mellan kanalerna)
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

entity mainunit is
--    generic (WIDTH : integer ;
--	     CHAN : integer );
    port (addrbus : in std_logic_vector(23 downto 0);  -- adrs till
						      -- minnesmappade register
	  databus : in std_logic_vector(31 downto 0);   -- data till motsv reg
	  grw   : in std_logic_vector(0 downto 0);
	  cs : in std_logic_vector(0 downto 0);
	  ack : in std_logic_vector(0 downto 0);  		 -- ROM-data tillgangligt, aktiv hog	 
	  data : in std_logic_vector(31 downto 0);   -- data fran ROM-al	 	 
	  reset : in std_logic_vector(0 downto 0);
	  clk : in std_logic;
	  romutaddress : out std_logic_vector(23 downto 0);   -- adrs till ROM-accessladan
	  rdout : out std_logic_vector(0 downto 0);  		-- lassignal till ROM, aktiv hog
--	  doneflag : out std_logic_vector(0 downto 0);
	  step : out std_logic_vector(0 downto 0);
	  rightsample : out std_logic_vector(7 downto 0);
	  leftsample : out std_logic_vector(7 downto 0);
	  status_out : out std_logic_vector(31 downto 0);  -- utgaang dirket kopplad till ALU, genom ReadFromCoProc
	stall_in : in std_logic_vector(0 downto 0) -- stall fran FakeBox, aktivt laag
--	  state : out std_logic_vector(3 downto 0)  -- DISPLAY OUT ; ska bort i slutgiltiga versionen
	 );
end mainunit;

 

architecture mymainunit of mainunit is

    component mult
    port (indata : in std_logic_vector(31 downto 0);
	  utdata : out std_logic_vector(31 downto 0);
	  factor : in std_logic_vector(6 downto 0);   -- volume
	  clk : in std_logic;
	  reset : in std_logic_vector(0 downto 0);  	
	  start : in std_logic_vector(0 downto 0);   -- data ack
	  ready : out std_logic_vector(0 downto 0); -- resample wr
	  mastervol : in std_logic_vector(2 downto 0));
    end component;


    component resample
	port (clk : in std_logic;
	      
	      step : in std_logic_vector(0 downto 0);
	      datain : in std_logic_vector(31 downto 0);
	      wr : in std_logic_vector(0 downto 0);   -- mult ready
	      ack : in std_logic_vector(0 downto 0);   -- data ack
	      freq : in std_logic_vector(15 downto 0);
	      clr : in std_logic_vector(0 downto 0);
	      running : in std_logic_vector(0 downto 0);
	      dataut : out std_logic_vector(7 downto 0);
	      req : out std_logic_vector(0 downto 0)
	      );
    end component;

    component mixer
	port (clk : in std_logic;
	      reset : in std_logic_vector(0 downto 0);
	      step : in std_logic_vector(0 downto 0);
	      data0 : in std_logic_vector(7 downto 0);
	      data1 : in std_logic_vector(7 downto 0);
	      data2 : in std_logic_vector(7 downto 0);
	      data3 : in std_logic_vector(7 downto 0);
	      sample : out std_logic_vector(7 downto 0) 
	      );
    end component;

--    component sampleoutput
--	generic (FILENAME : string);
--	port (data : in std_logic_vector(7 downto 0);
--	      step : in std_logic_vector(0 downto 0));
--   end component;

    

    
-- Statemachinetype
    type statemachinetype is (autostartstate,autoreadstate,startmachinestate,stallstate,
			      initstate,initstatewait,
			      updaterowstate,updaterowstate_1_A,updaterowstate_1_B,
			      updaterowstate_1_C,updaterowstate_1_D,updaterowstate_1_E,
			      updaterowstate_1_F,updaterowstate_1_G,updaterowstate_1_H,
			      loopchstate,rowfx_1,mainwaitstate,samdatawaitstate,extramainwaitstate,
			      dotickfxstate,dotickreadsetup,tickfxreadstate,tickfxloopstate,
			      increaserowstate,checksongendstate,readstate,
			      getpattnumstate,getpattnumstate_B,
			      pausemachinestate,endmachine);
    
-- Sampletyper
    type samaddrtype is array (0 to 7) of std_logic_vector(23 downto 0);
    type samvolumetype is array (0 to 7) of std_logic_vector(6 downto 0);
    type samfreqtype is array (0 to 7) of std_logic_vector(15 downto 0);
    type saminstrtype is array (0 to 3) of std_logic_vector(4 downto 0);
    type fxtype is array (0 to 3) of std_logic_vector(7 downto 0);
--    type vibratopostype is array (0 to 3) of std_logic_vector(5 downto 0);
--    type vibratocontroltype is array (0 to 3) of std_logic_vector(2 downto 0);
    type notetype is array (0 to 3) of std_logic_vector(10 downto 0);
    type speedtype is array (0 to 3) of std_logic_vector(7 downto 0);
    type statustype is array (0 to 8) of std_logic_vector(0 downto 0);
--    type samflagtype is array ((0 to CHAN-1) of std_logic_vector(3 downto 0);
			       
-- Main register, tilldelas av processorn
    signal offset,nextoffset :  std_logic_vector(23 downto 0);  -- startaddress for hela mod strukturen
    signal notelookupaddress,nextnotelookupaddress :  std_logic_vector(23 downto 0);
    -- absolut address for note->freq lookuptabell( konstant ??? ), dra ifran
    -- 108 words fran korrekt addres
    signal chanstatus,nextchanstatus : std_logic_vector(7 downto 0); --
    -- 1=kanalhors, bit 7 = chan0, bit 6 = ch1 . . . bit 0 = chan7
    signal songstatus,nextsongstatus : std_logic_vector(23 downto 0);   --
    -- 23-16 chanstatus, bit 23 = chan0 -> bit 16 = chan7, 1 = hors, 0 = muted
    -- 15-8 samplespelas
    -- 2-0 loop,paus,play

    signal regsongstatus,nextregsongstatus : std_logic_vector(2 downto 0);
    
-- Sampleinfo register
    signal samaddrpos,nextsamaddrpos : samaddrtype;   -- tilldelas startadressen, raknar aktuell pos
    signal samendaddr,nextsamendaddr : samaddrtype;   -- slutadressem
    signal samloopstart,nextsamloopstart : samaddrtype;   -- loop
    signal samloopend,nextsamloopend : samaddrtype;   -- loop
    signal volume,nextvolume : samvolumetype;
    signal lastinst,nextlastinst : saminstrtype;
    signal freq,nextfreq : samfreqtype; 
    signal amiganote,nextamiganote : notetype; -- std_logic_vector(10 downto 0);  -- behovs
								      -- vael 4
								      -- eller 8?
-- fxreg, paramreg
    signal fxreg,nextfxreg,paramreg,nextparamreg : fxtype;
--    signal vibratopos, nextvibratopos,tremolopos,nexttremolopos : vibratopostype;
--    signal vibratocontrol, nextvibratocontrol,tremolocontrol,nexttremolocontrol : vibratocontroltype;
    signal note_to_slide_to, nextnote_to_slide_to : notetype;
    signal portaspeed,nextportaspeed : speedtype;
    signal active,nextactive : statustype;

-- alla adresser anges som Wordadresser. (byteadress / 4)
-- headeroffset = storleken pa skrapet fore forsta pattern

-- Konstanter 
    constant patternlookup : std_logic_vector(23 downto 0) := conv_std_logic_vector(124,24); -- patternlookupoffset
    shared variable temp : std_logic_vector(23 downto 0);
-- Songinfo register
    signal songspeed,nextsongspeed : std_logic_vector(4 downto 0);
    signal tickcount,nexttickcount : std_logic_vector(4 downto 0);
    signal songpos,nextsongpos :  std_logic_vector(6 downto 0);
    signal songlength,nextsonglength : std_logic_vector(6 downto 0);
    signal curpat,nextcurpat :  std_logic_vector(6 downto 0);
    signal patrow,nextpatrow : std_logic_vector(5 downto 0);
    signal numchan, nextnumchan : std_logic_vector(2 downto 0);  -- patternsize=numchan*64
    signal songtempo,nextsongtempo : std_logic_vector(7 downto 0);  -- Kanske
    signal pataddr,nextpataddr : std_logic_vector(23 downto 0);  --
    signal nextbreakflag,breakflag,nextjumpflag,jumpflag,nextstopsignal,stopsignal,nextpausesignal,pausesignal : std_logic_vector(0 downto 0);
    signal nextch,ch : integer range 0 to 3;
    signal activechannel,nextactivechannel : integer range 0 to 8;  -- om 8 no
								    -- channel active
-- Temporara register
   
    signal leftsample_out, rightsample_out : std_logic_vector(7 downto 0);
    signal readaddress,nextreadaddress,romaddress,nextromaddress :  std_logic_vector(23 downto 0);
    signal tempdata,nexttempdata :  std_logic_vector(31 downto 0);
    signal lookup,nextlookup : std_logic_vector(1 downto 0);  -- flagga for
    signal nextrd,rd,nextautoset,autoset : std_logic_vector(0 downto 0);
    signal countexpired,nextcountexpired,slide_dir,nextslide_dir : std_logic_vector(0 downto 0);
    
-- Statemachineregister
    signal thestate,nextstate,tempstate,nexttempstate : statemachinetype;

-- klockreg
    signal waitclock,nextwaitclock,waitcount,nextwaitcount,stepclock,nextstepclock,stepcount,nextstepcount : std_logic_vector(19 downto 0);

-- datalaesning ut
    signal muxselect, nextmuxselect : std_logic_vector(7 downto 0);  -- CPU skriver for att vaelja registerdata ut
    
-- Kontaktledningar
	
    signal req0,req1,req2,req3,req4,req5,req6,req7 : std_logic_vector(0 downto 0); -- data request
							        -- fran resp
							        -- resampler.  ,req4,req5,req6,req7
    signal RS_0_data,RS_1_data,RS_2_data,RS_3_data,RS_4_data,RS_5_data,RS_6_data,RS_7_data : std_logic_vector(31 downto 0);
--	RS_4_data,RS_5_data,RS_6_data,RS_7_data : std_logic_vector(31 downto 0); -- samdata till resp resampler
    signal RS_0_ack,RS_1_ack,RS_2_ack,RS_3_ack,RS_4_ack,RS_5_ack,RS_6_ack,RS_7_ack : std_logic_vector(0 downto 0);
--	RS_4_ack,RS_5_ack,RS_6_ack,RS_7_ack : std_logic_vector(0 downto 0); -- data ack till resp resampler
    signal dataut0,dataut1,dataut2,dataut3,dataut4,dataut5,dataut6,dataut7 : std_logic_vector(7 downto 0);   -- 
    signal mystep : std_logic_vector(0 downto 0);
    signal mult_0_datain,mult_1_datain,mult_2_datain,mult_3_datain,mult_4_datain,mult_5_datain,mult_6_datain,mult_7_datain : std_logic_vector(31 downto 0);
--	mult_4_datain,mult_5_datain,mult_6_datain,mult_7_datain : std_logic_vector(31 downto 0);
    signal mult_0_ready,mult_1_ready,mult_2_ready,mult_3_ready,mult_4_ready,mult_5_ready,mult_6_ready,mult_7_ready : std_logic_vector(0 downto 0);
--	mult_4_ready,mult_5_ready,mult_6_ready,mult_7_ready : std_logic_vector(0 downto 0);
--    signal leftsample,rightsample : std_logic_vector(7 downto 0);

	signal mastervolreg,nextmastervolreg : std_logic_vector(23 downto 0);

begin  -- mymainunit

    MULT0 : mult port map (mult_0_datain,RS_0_data,volume(0),clk,reset,RS_0_ack,mult_0_ready,mastervolreg(11 downto 9));
    MULT1 : mult port map (mult_1_datain,RS_1_data,volume(1),clk,reset,RS_1_ack,mult_1_ready,mastervolreg(8 downto 6));
    MULT2 : mult port map (mult_2_datain,RS_2_data,volume(2),clk,reset,RS_2_ack,mult_2_ready,mastervolreg(5 downto 3));
    MULT3 : mult port map (mult_3_datain,RS_3_data,volume(3),clk,reset,RS_3_ack,mult_3_ready,mastervolreg(2 downto 0));

    MULT4 : mult port map (mult_4_datain,RS_4_data,volume(4),clk,reset,RS_4_ack,mult_4_ready,mastervolreg(23 downto 21));
    MULT5 : mult port map (mult_5_datain,RS_5_data,volume(5),clk,reset,RS_5_ack,mult_5_ready,mastervolreg(20 downto 18));
    MULT6 : mult port map (mult_6_datain,RS_6_data,volume(6),clk,reset,RS_6_ack,mult_6_ready,mastervolreg(17 downto 15));
    MULT7 : mult port map (mult_7_datain,RS_7_data,volume(7),clk,reset,RS_7_ack,mult_7_ready,mastervolreg(14 downto 12));
    
    RE0 : resample port map (clk,mystep,RS_0_data,mult_0_ready,RS_0_ack,freq(0),reset,
			     active(0),dataut0,req0);
    RE1 : resample port map (clk,mystep,RS_1_data,mult_1_ready,RS_1_ack,freq(1),reset,
			     active(1),dataut1,req1);
    RE2 : resample port map (clk,mystep,RS_2_data,mult_2_ready,RS_2_ack,freq(2),reset,
			     active(2),dataut2,req2);
    RE3 : resample port map (clk,mystep,RS_3_data,mult_3_ready,RS_3_ack,freq(3),reset,
			     active(3),dataut3,req3);
    RE4 : resample port map (clk,mystep,RS_4_data,mult_4_ready,RS_4_ack,freq(4),reset,
			     active(4),dataut4,req4);
    RE5 : resample port map (clk,mystep,RS_5_data,mult_5_ready,RS_5_ack,freq(5),reset,
			     active(5),dataut5,req5);
    RE6 : resample port map (clk,mystep,RS_6_data,mult_6_ready,RS_6_ack,freq(6),reset,
			     active(6),dataut6,req6);
    RE7 : resample port map (clk,mystep,RS_7_data,mult_7_ready,RS_7_ack,freq(7),reset,
			     active(7),dataut7,req7);

    MIXLEFT : mixer port map (clk,reset,mystep,dataut0,dataut3,dataut4,dataut7,leftsample_out);
    MIXRIGHT : mixer port map (clk,reset,mystep,dataut1,dataut2,dataut5,dataut6,rightsample_out);
    
    leftsample <= leftsample_out;
    rightsample <= rightsample_out;

--    UTLEFT : sampleoutput generic map ("left.txt") port map (leftsample,mystep);
--    UTRIGHT : sampleoutput generic map ("right.txt") port map (rightsample,mystep);
-------------------------------------------------------------------------------
-- lookuptabellen ar 800 word stor. (15 downto 0) ar
-- freqvarden i herz. de 64 forsta orden innehaller sinustabell
-- paa bitar(23 downto 16). sinustabellen ar en full period. addresseringen sker
-- med notelookupaddress + notvardet. notelookupaddressen pekar 108 words fore
-- tabellen => ett not varde=108 pekar pa forsta wordet i tabellen.
-------------------------------------------------------------------------------

    process(songstatus, waitcount,waitclock,countexpired)
    begin
	nextcountexpired <= countexpired;
	nextwaitcount <= waitcount;
--	if pausesignal = "0" then
	    if waitcount=0 then
		nextwaitcount<=waitclock;
		nextcountexpired <= "1";
	    elsif songstatus(3 downto 3) = "0" then
		nextcountexpired <= "0";
		nextwaitcount <= waitcount-1;
	    else
		nextwaitcount<=waitcount-1;
	    end if;
--	end if;
    end process;

    process(stepcount,stepclock)
    begin
	nextstepcount <= stepcount;
	mystep <= "0";
	step <= "0";
--	if pausesignal = "0" then
	    if stepcount = 0  then
--		nextstepcount <= X"001E8";-- clockfreq/samplingsfreqout, 16MHz/32768=488
		nextstepcount <= stepclock;
		mystep <= "1";
		step <= "1";
	    else
		mystep <= "0";
		step <= "0";
		nextstepcount <= stepcount-1;   
	    end if;
--	end if;
    end process;

    process(readaddress,romaddress,notelookupaddress,offset,lookup)
    begin
	romutaddress <= romaddress;
	nextromaddress<=romaddress;
	case lookup is
	    when "00" =>
--		nextromaddress<=readaddress+offset;
		romutaddress <= readaddress + offset;
		nextromaddress <= readaddress + offset;
	    when "01" =>
--		nextromaddress<=readaddress+notelookupaddress;  -- readlookupaddress=notvardet=108:907
		romutaddress <= readaddress + notelookupaddress;
		nextromaddress <= readaddress + notelookupaddress;
	    when "10" =>
		romutaddress <= readaddress;
		nextromaddress <= readaddress;
--		romutaddress <= (others => 'Z');
		when "11" => null;
	    when others => null;
	end case;
	
    end process;

-------------------------------------------------------------------------------
--  processor skriver till reg
-------------------------------------------------------------------------------
-- vi vill ha 64 adresser totalt, dvs 6 bits. bara 4 adr anvaends
-- haer, (lookupadress,modadress,start, mute) resten i mainunit-processen
    
    process(offset,notelookupaddress,chanstatus,regsongstatus,addrbus,databus,grw,cs,stopsignal,autoset,tempdata)
    begin
	nextoffset <= offset;
	nextnotelookupaddress <= notelookupaddress;
	nextchanstatus <= chanstatus;
	nextregsongstatus <= regsongstatus;
	if stopsignal = "1" then
	    nextregsongstatus <= (others => '0');
	end if;
--	if pausesignal = "1" then
--	    nextchanstatus <= (others => '0');
--	end if;
	if autoset = "1" then
		nextoffset <= tempdata(23 downto 0);
		nextnotelookupaddress <= tempdata(23 downto 0)-908;
		nextregsongstatus <= "101";
	end if;
		
	if grw = "0" and cs ="0" then
	    case addrbus(5 downto 0) is
		when "000000" => nextoffset <= databus(23 downto 0);
		when "000001" => nextnotelookupaddress <= databus(23 downto 0);
		when "000010" => nextchanstatus <= databus(7 downto 0); -- laggs i songstatus(23  downto 16)
		when "000011" => nextregsongstatus <= databus(2 downto 0);
		when others => null;
	    end case;
	end if;
    end process;

    process(--data,ack,thestate,songstatus,
		    --curpat, patrow, pataddr, readaddress)
			leftsample_out, rightsample_out, dataut0,dataut1,dataut2,dataut3,dataut4,dataut5,dataut6,dataut7,
	addrbus,databus,grw,cs,pausesignal,muxselect,slide_dir,stall_in,
	data,ack,readaddress,chanstatus,songstatus,regsongstatus,
	thestate,tempstate,songspeed,songpos,songtempo,lookup,rd,
	tickcount,patrow,songlength,numchan,
	curpat,pataddr,tempdata,lastinst,amiganote,
	samaddrpos,volume,samendaddr,samloopstart,mastervolreg,
	samloopend,freq,fxreg,paramreg, -- vibratopos,vibratocontrol,tremolocontrol,tremolopos,
	portaspeed,note_to_slide_to,breakflag,jumpflag,ch,
	waitclock,stepclock,countexpired,activechannel,stopsignal,active,req0,req1,req2,req3,req4,req5,req6,req7
    )

		    
    variable localpataddress : std_logic_vector(23 downto 0);
    begin
	-- Se till att det inte blir latchar
	-- next <= ickenext
	nextlookup <= lookup;
	nextrd <= rd;
	rdout <= rd;
	nextstate <= thestate;
	nexttempstate <= tempstate;
	nextsongspeed <= songspeed;
	nextsongpos <= songpos;
	nextsongtempo <= songtempo;
	nexttickcount <= tickcount;
	nextpatrow <=patrow;
	nextreadaddress <= readaddress;
	nextsonglength <=songlength;
	nextnumchan <= numchan;
	nextcurpat <= curpat;
	nextpataddr <= pataddr;
	nexttempdata <= tempdata;
	nextlastinst <= lastinst;
-------------------------------------------------------------------------------
-- boundscheck
	nextamiganote <= amiganote;
	if amiganote(0) < "00001101100" then  -- = 6c = 108
	    nextamiganote(0) <= "00001101100";
	elsif amiganote(0) > "01110001011" then  -- = 38b = 907
	    nextamiganote(0) <= "01110001011";
	end if;
	if amiganote(1) < "00001101100" then
	    nextamiganote(1) <= "00001101100";
	elsif amiganote(1) > "01110001011" then
	    nextamiganote(1) <= "01110001011";
	end if;
	if amiganote(2) < "00001101100" then
	    nextamiganote(2) <= "00001101100";
	elsif amiganote(2) > "01110001011" then
	    nextamiganote(2) <= "01110001011";
	end if;
	if amiganote(3) < "00001101100" then
	    nextamiganote(3) <= "00001101100";
	elsif amiganote(3) > "01110001011" then
	    nextamiganote(3) <= "01110001011";
	end if;

	nextvolume <= volume;
	if volume(0) > "1100000" then  	-- tolkas som tvakompl < 0
	    nextvolume(0) <= (others => '0');
	elsif volume(0) > "1000000" then
	    nextvolume(0) <= "1000000";
	end if;
	if volume(1) > "1100000" then
	    nextvolume(1) <= (others => '0');
	elsif volume(1) > "1000000" then
	    nextvolume(1) <= "1000000";
	end if;
	if volume(2) > "1100000" then
	    nextvolume(2) <= (others => '0');
	elsif volume(2) > "1000000" then
	    nextvolume(2) <= "1000000";
	end if;
	if volume(3) > "1100000" then
	    nextvolume(3) <= (others => '0');
	elsif volume(3) > "1000000" then
	    nextvolume(3) <= "1000000";
	end if;
-------------------------------------------------------------------------------
	nextsamaddrpos <= samaddrpos;
	nextsamendaddr <= samendaddr;
	nextsamloopstart <= samloopstart;
	nextsamloopend <= samloopend;
	nextfreq <= freq;
	nextwaitclock <= waitclock;
	nextstepclock <= stepclock;
	nextmuxselect <= muxselect;
	nextmastervolreg<=mastervolreg;
	nextsonglength <= songlength;
	nextsongpos <= songpos;
	nextpatrow <= patrow;
	nextpataddr <= pataddr;
	nextcurpat <= curpat;

	if grw="0" and cs="0" then
	    case addrbus(5 downto 0) is
		when "000100" =>
		    nextsamaddrpos(4) <= databus(23 downto 0);
		when "000101" =>
		    nextsamaddrpos(5) <= databus(23 downto 0);
		when "000110" =>
		    nextsamaddrpos(6) <= databus(23 downto 0);
		when "000111" =>
		    nextsamaddrpos(7) <= databus(23 downto 0);
		when "001000" =>
		    nextvolume(4) <= databus(6 downto 0);
		when "001001" =>
		    nextvolume(5) <= databus(6 downto 0);
		when "001010" =>
		    nextvolume(6) <= databus(6 downto 0);
		when "001011" =>
		    nextvolume(7) <= databus(6 downto 0);
		when "001100" =>
		    nextsamendaddr(4) <= databus(23 downto 0);
		when "001101" =>
		    nextsamendaddr(5) <= databus(23 downto 0);
		when "001110" =>
		    nextsamendaddr(6) <= databus(23 downto 0);
		when "001111" =>
		    nextsamendaddr(7) <= databus(23 downto 0);
		when "010000" =>
		    nextsamloopstart(4) <= databus(23 downto 0);
		when "010001" =>
		    nextsamloopstart(5) <= databus(23 downto 0);
		when "010010" =>
		    nextsamloopstart(6) <= databus(23 downto 0);
		when "010011" =>
		    nextsamloopstart(7) <= databus(23 downto 0);
		when "010100" =>
		    nextsamloopend(4) <= databus(23 downto 0);
		when "010101" =>
		    nextsamloopend(5) <= databus(23 downto 0);
		when "010110" =>
		    nextsamloopend(6) <= databus(23 downto 0);
		when "010111" =>
		    nextsamloopend(7) <= databus(23 downto 0);
		when "011000" =>
		    nextfreq(4) <= databus(15 downto 0);
		when "011001" =>
		    nextfreq(5) <= databus(15 downto 0);
		when "011010" =>
		    nextfreq(6) <= databus(15 downto 0);
		when "011011" =>
		    nextfreq(7) <= databus(15 downto 0);
		when "011100" =>
		    nextwaitclock <= databus(19 downto 0); -- purpose: to enable MU to run
                                        -- at any CPU-specified clockfreq  
		when "011101" =>  	-- CPU simply calculates/writes NbrOfClocks per tick & step
		    nextstepclock <= databus(19 downto 0);
		when "011111" =>  	-- MuxSelect
		    nextmuxselect <= databus(7 downto 0);
		when "100000" =>
		    nextsonglength <= databus(6 downto 0);
		when "100001" =>
		    nextsongpos <= databus(6 downto 0);
		    nextstate <= getpattnumstate;
		when "100010" =>
		    nextpatrow <= databus(5 downto 0);
		when "100011" =>
		    nextpataddr <= databus(23 downto 0);
		when "100100" =>     		
		    nextcurpat <= databus(6 downto 0);
		when "100101" =>
		    nextmastervolreg <= databus(30 downto 28)&
								databus(26 downto 24)&
								databus(22 downto 20)&
								databus(18 downto 16)&
								databus(14 downto 12)&
								databus(10 downto 8)&
								databus(6 downto 4)&
								databus(2 downto 0); -- Mastervolset
		when others => 
			null;
  	end case;
	end if;
--	end if;
	nextfxreg <= fxreg;
	nextparamreg <=  paramreg;
--	nextvibratocontrol <= vibratocontrol;
--	nextvibratopos <= vibratopos;
--	nexttremolocontrol <= tremolocontrol;
--	nexttremolopos <= tremolopos;
	nextportaspeed <= portaspeed;
	nextnote_to_slide_to <= note_to_slide_to;
	nextbreakflag <= breakflag;
	nextjumpflag <= jumpflag;
	nextch <= ch;
	nextactivechannel <= activechannel;
	nextactive <= active;  		-- default
	nextslide_dir <= slide_dir;
	nextsongstatus <= chanstatus & active(0)&active(1)&active(2)&active(3)&active(4)&active(5)&active(6)&active(7) & "0000" & countexpired & regsongstatus;
	nextstopsignal <= stopsignal;
	nextpausesignal <= pausesignal;
	RS_0_ack <= stopsignal or pausesignal or not songstatus(23 downto 23);  -- om alla=0 => rs_x_ack=0
	RS_1_ack <= stopsignal or pausesignal or not songstatus(22 downto 22);  -- om rs_x_ack 1, laddas
						-- resampler med mult_x_datain (=0) => tystnad
	RS_2_ack <= stopsignal or pausesignal or not songstatus(21 downto 21);
	RS_3_ack <= stopsignal or pausesignal or not songstatus(20 downto 20);
	RS_4_ack <= stopsignal or pausesignal or not songstatus(19 downto 19);
	RS_5_ack <= stopsignal or pausesignal or not songstatus(18 downto 18);
	RS_6_ack <= stopsignal or pausesignal or not songstatus(17 downto 17);
        RS_7_ack <= stopsignal or pausesignal or not songstatus(16 downto 16);
--	RS_0_ack <= "0";
--	RS_1_ack <= "0";
--	RS_2_ack <= "0";
--	RS_3_ack <= "0";
--	RS_4_ack <= "0";
--	RS_5_ack <= "0";
--	RS_6_ack <= "0";
--	RS_7_ack <= "0";
	mult_0_datain <= (others => '0');
	mult_1_datain <= (others => '0');
	mult_2_datain <= (others => '0');
	mult_3_datain <= (others => '0');
	mult_4_datain <= (others => '0');
	mult_5_datain <= (others => '0');
	mult_6_datain <= (others => '0');
	mult_7_datain <= (others => '0');
	nextautoset <= "0";
--	doneflag <= "0";
--	state<="0000";

	if samaddrpos(4) < samendaddr(4) then -- autostarta fx-samples om samstart() < samend()
	    nextactive(4) <= "1";
	end if;
	if samaddrpos(5) < samendaddr(5) then
	    nextactive(5) <= "1";
	end if;
	if samaddrpos(6) < samendaddr(6) then
	    nextactive(6) <= "1";
	end if;
	if samaddrpos(7) < samendaddr(7) then
	    nextactive(7) <= "1";
	end if;
-- Muxselect, Mainunit<->CPU kontakten
	case muxselect is
	    when X"00" => 
		status_out <= rightsample_out & leftsample_out & songstatus(15 downto 0);
	    when X"01" =>
		status_out <= rightsample_out & "000"&songspeed & "000"&tickcount & "00000000";
	    when X"02" =>
		status_out <= "0"&songlength & "0"& songpos & "0"&curpat & "00"&patrow;
	    when X"03" =>
		status_out <= dataut0 & dataut1 & dataut2 & dataut3;
	    when X"04" =>
		status_out <= dataut4 & dataut5 & dataut6 & dataut7;
	    when X"10" =>
		status_out <= "000"&lastinst(0) & samaddrpos(0);
	    when X"11" =>
		status_out <= "000"&lastinst(1) & samaddrpos(1);
	    when X"12" =>
		status_out <= "000"&lastinst(2) & samaddrpos(2);
	    when X"13" =>
		status_out <= "000"&lastinst(3) & samaddrpos(3);
	    when X"14" =>
		status_out <= "00000000" & samaddrpos(4);
	    when X"15" =>
		status_out <= "00000000" & samaddrpos(5);
	    when X"16" =>
		status_out <= "00000000" & samaddrpos(6);
	    when X"17" =>
		status_out <= "00000000" & samaddrpos(7);
	    when X"20" =>
		status_out <= "000000000" & volume(0) & freq(0);
	    when X"21" =>
		status_out <= "000000000" & volume(1) & freq(1);
	    when X"22" =>
		status_out <= "000000000" & volume(2) & freq(2);
	    when X"23" =>
		status_out <= "000000000" & volume(3) & freq(3);
	    when X"24" =>
		status_out <= "000000000" & volume(4) & freq(4);
	    when X"25" =>
		status_out <= "000000000" & volume(5) & freq(5);
	    when X"26" =>
		status_out <= "000000000" & volume(6) & freq(6);
	    when X"27" =>
		status_out <= "000000000" & volume(7) & freq(7);
	    when X"30" =>
		status_out <= "0000000000000000" & fxreg(0) & paramreg(0);
	    when X"31" =>
		status_out <= "0000000000000000" & fxreg(1) & paramreg(1);
	    when X"32" =>
		status_out <= "0000000000000000" & fxreg(2) & paramreg(2);
	    when X"33" =>
		status_out <= "0000000000000000" & fxreg(3) & paramreg(3);
	    when others =>
		status_out <= rightsample_out & leftsample_out & songstatus(15 downto 0);  -- default
	end case;

-- statemaskinen:
	case thestate is  
	
		when stallstate =>
--		state<=X"F";
		if stall_in = "1" then
			nextstate <= autostartstate;
		end if;
	
		when autostartstate =>
--		state<=X"E";
		nextlookup <= "10";
		nextreadaddress <= (others => '0');
		nextrd <= "1";
		nexttempstate <= autoreadstate;
	    nextstate <= readstate;
	    
	    when autoreadstate =>
--		state<=X"D";
	    nexttempdata <= data;
	    if data /= X"00000000" then
	    	nextautoset <= "1";
--			state<=X"C";
	    end if;
	    nextstate <= startmachinestate;
	    	
	    when startmachinestate =>
--		state<=X"b";
		nextlookup <= "11";
		nextstopsignal <= "0";  -- nollstaller regsongstatus
		if songstatus(1 downto 0) = "01" then  -- songstatus:bit2=loop,
						        -- bit1=paus, bit0=play
		   nextstate <= initstate;
		end if;

	    when initstate =>
--		state<=X"A";
	
		nextsongspeed <= conv_std_logic_vector(6,5);
		nexttickcount <= "00001";
		nextsongpos <= conv_std_logic_vector(0,7);
		nextpatrow <= conv_std_logic_vector(0,6);
		nextsongtempo <= conv_std_logic_vector(125,8);
		nextlookup <= "00";
		nextreadaddress <= conv_std_logic_vector(124,24);
		nextrd <= "1";
		nexttempstate <= initstatewait;
		nextstate <= readstate;
--		if ack = 1 then
--		  nextstate <= initstatewait;
--		  nextlookup <= "11";
--		  nextrd <= "0";
--		end if;
		

	    when initstatewait =>
--		state<=X"9";		
-- 		if ack = "1" then
--		nextlookup <= "11";
--		nextrd <= "0";
		nextsonglength <= data(30 downto 24);
		nextnumchan <= data(18 downto 16);
		nextcurpat <= data(6 downto 0);  -- hur manga bitar 7
		nextstate <= mainwaitstate;
	
	    when mainwaitstate =>
--		state<="0011"
--		state<=songpos(3 downto 0);
		if songstatus(0 downto 0) = "0" then
		    nextstopsignal <= "1";  -- nollstaller regsongstatus
		    nextstate <= startmachinestate;  -- stoped
		    nextactive(0) <= "0";
		    nextactive(1) <= "0";
		    nextactive(2) <= "0";
		    nextactive(3) <= "0";
		    nextactive(4) <= "0";
		    nextactive(5) <= "0";
		    nextactive(6) <= "0";
		    nextactive(7) <= "0";
--		    RS_0_ack <= "1";  	-- skriv 0 till resampler, tystar allt
--		    RS_1_ack <= "1";
--		    RS_2_ack <= "1";
--		    RS_3_ack <= "1";
--		    RS_4_ack <= "1";
--		    RS_5_ack <= "1";
--		    RS_6_ack <= "1";
--		    RS_7_ack <= "1";		    
		elsif songstatus(1 downto 0) = "11" then
		    nextpausesignal <= "1";  -- testar bara, inget
					     -- noedvaendigt eg?
		    nextstate <= pausemachinestate;
		else
		    if req0 = "1" and active(0) = "1" then
-- songstatus(15 downto 8) = active(0-7) ar sampleisplaying for kanal 0-7
			nextlookup <= "00";
			nextreadaddress <= samaddrpos(0);
			nextrd <= "1";
			nextactivechannel <= 0;
--			if ack = "1" then
--			    nextstate <= samdatawaitstate;
--			    nextlookup <= "11";
--			    nextrd <= "0";
--			end if;
			nexttempstate <= samdatawaitstate;
			nextstate <= readstate;
		    end if;
		    if req1 = "1" and active(1) = "1" then
			nextlookup <= "00";
			nextreadaddress <= samaddrpos(1);
			nextrd <= "1";
			nextactivechannel <= 1;
			nexttempstate <= samdatawaitstate;
			nextstate <= readstate;
		    end if;
		    if req2 = "1" and active(2) = "1" then
			nextlookup <= "00";
			nextreadaddress <= samaddrpos(2);
			nextrd <= "1";
			nextactivechannel <= 2;
			nexttempstate <= samdatawaitstate;
			nextstate <= readstate;
		    end if;
		    if req3 = "1" and active(3) = "1" then
			nextlookup <= "00";
			nextreadaddress <= samaddrpos(3);
			nextrd <= "1";
			nextactivechannel <= 3;
			nexttempstate <= samdatawaitstate;
			nextstate <= readstate;
		    end if;
		    if req4 = "1" and active(4) = "1" then
			nextlookup <= "10";
			nextreadaddress <= samaddrpos(4);
			nextrd <= "1";
			nextactivechannel <= 4;
			nexttempstate <= samdatawaitstate;
			nextstate <= readstate;
		    end if;
		    if req5 = "1" and active(5) = "1" then
			nextlookup <= "10";
			nextreadaddress <= samaddrpos(5);
			nextrd <= "1";
			nextactivechannel <= 5;
			nexttempstate <= samdatawaitstate;
			nextstate <= readstate;
		    end if;
		    if req6 = "1" and active(6) = "1" then
			nextlookup <= "10";
			nextreadaddress <= samaddrpos(6);
			nextrd <= "1";
			nextactivechannel <= 6;
			nexttempstate <= samdatawaitstate;
			nextstate <= readstate;
		    end if;
		    if req7 = "1" and active(7) = "1" then
			nextlookup <= "10";
			nextreadaddress <= samaddrpos(7);
			nextrd <= "1";
			nextactivechannel <= 7;
			nexttempstate <= samdatawaitstate;
			nextstate <= readstate;
		    end if;

		    if countexpired="1" and req0="0" and req1="0" and req2="0" and req3="0" and req4="0" and req5="0" and req6="0" and req7="0" then
			nextsongstatus(3 downto 3) <= "0";  -- nollstaller countexpired
			if tickcount = 1 then
			    nexttickcount <= songspeed;
			    nextstate <= updaterowstate;
			else
			    nexttickcount <= tickcount-1;
			    -- do tickfx here
			    nextch <= 0;
			    nextstate <= dotickfxstate;
			end if;			    
		    end if;
		end  if;

	    when dotickfxstate =>
		case fxreg(ch) is
		    when X"01" =>
			nextamiganote(ch) <= amiganote(ch) - portaspeed(ch);
			nextstate <= dotickreadsetup;
		    when X"02" =>
			nextamiganote(ch) <= amiganote(ch) + portaspeed(ch);
			nextstate <= dotickreadsetup;
		    when X"03" =>
			if slide_dir = "1" then  -- note++
			    nextamiganote(ch) <= amiganote(ch) + portaspeed(ch);
			    if amiganote(ch) >= note_to_slide_to(ch) then
				nextamiganote(ch) <= note_to_slide_to(ch);
				nextfxreg(ch) <= (others => '0');
			    end if;
			else
			    nextamiganote(ch) <= amiganote(ch) - portaspeed(ch);
			    if amiganote(ch) <= note_to_slide_to(ch) then
				nextamiganote(ch) <= note_to_slide_to(ch);
				nextfxreg(ch) <= (others => '0');  -- stop slide when dest reached
			    end if;
			end if;
			nextstate <= dotickreadsetup;
		    when X"05" =>
			if slide_dir = "1" then  -- note++
			    nextamiganote(ch) <= amiganote(ch) + portaspeed(ch);
			    if amiganote(ch) >= note_to_slide_to(ch) then
				nextamiganote(ch) <= note_to_slide_to(ch);
				nextfxreg(ch) <= (others => '0');
			    end if;
			else
			    nextamiganote(ch) <= amiganote(ch) - portaspeed(ch);
			    if amiganote(ch) <= note_to_slide_to(ch) then
				nextamiganote(ch) <= note_to_slide_to(ch);
				nextfxreg(ch) <= (others => '0');
			    end if;
			end if;
			if paramreg(ch)(7 downto 4) > "0000" then
			    nextvolume(ch) <= volume(ch)+paramreg(ch)(7 downto 4);
			elsif paramreg(ch)(3 downto 0) > "0000" then
			    nextvolume(ch) <= volume(ch)-paramreg(ch)(3 downto 0);
			end if;
			nextstate <= dotickreadsetup;
		    when X"06" =>  	-- (06 = volslide + vibr, just do volside)
			if paramreg(ch)(7 downto 4) > "0000" then
			    nextvolume(ch) <= volume(ch)+paramreg(ch)(7 downto 4);
			elsif paramreg(ch)(3 downto 0) > "0000" then
			    nextvolume(ch) <= volume(ch)-paramreg(ch)(3 downto 0);
			end if;
			nextstate <= tickfxloopstate;
		    when X"0A" =>
			if paramreg(ch)(7 downto 4) > "0000" then
			    nextvolume(ch) <= volume(ch)+paramreg(ch)(7 downto 4);
			elsif paramreg(ch)(3 downto 0) > "0000" then
			    nextvolume(ch) <= volume(ch)-paramreg(ch)(3 downto 0);
			end if;
			nextstate <= tickfxloopstate;
		    when others =>
			nextstate <= tickfxloopstate;
		end case;

	    when dotickreadsetup =>
		nexttempstate <= tickfxreadstate;
		nextrd <= "1";
		nextlookup <= "01";
		nextreadaddress <= "0000000000000"&amiganote(ch);
		nextstate <= readstate;

	    when tickfxreadstate =>
		nextfreq(ch) <= data(15 downto 0);
		nextstate <= tickfxloopstate;

	    when tickfxloopstate =>
		if ch = 3 then
		    nextch <= 0;
		    nextstate <= mainwaitstate;
		else
		    nextch <= ch+1;
		    nextstate <= dotickfxstate;
		end if;
		
		
	    when samdatawaitstate =>
--		state<="0100";
--		if ack = "1" then
--			nextlookup <= "11";
--			nextrd <= "0";
		    case activechannel is
			when 0 =>
			    if songstatus(23 downto 23) = "1" then
				mult_0_datain <= data;  -- defaulttilldelad 0, blir alltsaa 0 om Muted
			    end if;
			    RS_0_ack <= "1";
			when 1 =>
			    if songstatus(22 downto 22) = "1" then
				mult_1_datain <= data;
			    end if;
			    RS_1_ack <= "1";
			when 2 =>
			    if songstatus(21 downto 21) = "1" then
				mult_2_datain <= data;
			    end if;
			    RS_2_ack <= "1";
			when 3 =>
			    if songstatus(20 downto 20) = "1" then
				mult_3_datain <= data;
			    end if;
			    RS_3_ack <= "1";
			when 4 =>
			    if songstatus(19 downto 19) = "1" then
				mult_4_datain <= data;
			    end if;
			    RS_4_ack <= "1";
			when 5 =>
			    if songstatus(18 downto 18) = "1" then
				mult_5_datain <= data;
			    end if;
			    RS_5_ack <= "1";
			when 6 =>
			    if songstatus(17 downto 17) = "1" then
				mult_6_datain <= data;
			    end if;
			    RS_6_ack <= "1";
			when 7 =>
			    if songstatus(16 downto 16) = "1" then
				mult_7_datain <= data;
			    end if;
			    RS_7_ack <= "1";
			when others => null;			    
		    end case;
		    if samloopend(activechannel) /= 0 and samaddrpos(activechannel) >= samloopend(activechannel) then
				nextsamaddrpos(activechannel) <= samloopstart(activechannel);
		    else
				nextsamaddrpos(activechannel) <= samaddrpos(activechannel)+1;
		    end if;
		    if samloopend(activechannel) = 0 and samaddrpos(activechannel) > samendaddr(activechannel) then
				nextactive(activechannel) <= "0";
		    end if;
		    nextstate <= extramainwaitstate;
--		end if;
		
	    when extramainwaitstate => 
		nextstate <= mainwaitstate;
		
	    when updaterowstate =>
--		state<="0101";
		nextbreakflag <= "0";
		nextjumpflag <= "0";
		localpataddress := (others => '0');
		localpataddress(14 downto 8) := curpat;
		localpataddress(7 downto 2) := patrow;
--	        temppataddr <= localpataddress;
		nextpataddr <= localpataddress+157;
--	        temppataddr(23 downto 0) <= (others => '0');
--		temppataddr(15 downto 8) <= curpat;  --curpat*patternsize(64*4words)
--		temppataddr(7 downto 2) <= patrow;
		nextch <= 0;
		nextstate <= updaterowstate_1_A;

	    when updaterowstate_1_A =>
		    nextlookup <= "00";
		    nextreadaddress <= pataddr;
		    nextrd <= "1";
--		    if ack = "1" then
--			nextstate <= updaterowstate_1_B;
--			nextlookup <= "11";
--			nextrd <= "0";
--		    end if;
		    nexttempstate <= updaterowstate_1_B;
		    nextstate <= readstate;
	    when updaterowstate_1_B =>
--		state<="0110";
--		    if ack="1" then
--			nextlookup <= "11";
--			nextrd <= "0";
			nexttempdata <= data;  -- tempdata(31 downto 27)-> samplinstr,
					        -- tempdata(26 downto 16)-> 
					        -- amiganote=0-> no note,
					        -- tempdata(15 downto 8)-> effekt,
					        -- tempdata(7 downto 0)-> parameter.
--			if data(26 downto 16) > 0 then
--			   nextamiganote <= data(26 downto 16);  -- kollen
--			end if;    				  -- behovs
								  -- nog inte
			if data(31 downto 27)>0 then
			   nextlastinst(ch) <= data(31 downto 27);
			   nextlookup <= "00";
			   nextreadaddress <= "00000000000000000"&(data(31 downto 27)-1)&"00"; --
			   nextrd <= "1";
			   nextactive(ch) <= "1";
--			   if ack = "1" then
--			       nextreadaddress <= readaddress+1;
--			       nextstate <= updaterowstate_1_C;
--			       nextlookup <= "11";
--			       nextrd <= "0";
--			   end if;
			   nexttempstate <= updaterowstate_1_C;   -- samplelookupstate
			   nextstate <= readstate;

			elsif lastinst(ch) > 0 then
			   nextlookup <= "00";
			   nextreadaddress <= "00000000000000000"&(lastinst(ch)-1)&"00"; -- justeras om WIDTH andras fran 24
			   nextrd <= "1";
			   nextactive(ch) <= "1";
--			   if ack = "1" then
--			       nextreadaddress <= readaddress+1;
--			       nextstate <= updaterowstate_1_C;
--			       nextlookup <= "11";
--			       nextrd <= "0";
--			   end if;
			   nexttempstate <= updaterowstate_1_C;   -- samplelookupstate
			   nextstate <= readstate;
			   
			elsif data(26 downto 16) > 0 then
			    if data(15 downto 8)/=X"03" then
				nextamiganote(ch) <= data(26 downto 16);
			    end if;
			   nextlookup <= "01";
			   nextreadaddress <= "0000000000000"&data(26 downto 16);
			   nextrd <= "1";
			   nextactive(ch) <= "1";
--			   if ack = "1" then
--			       nextstate <= updaterowstate_1_G;
--			       nextlookup <= "11";
--			       nextrd <= "0";
--			   end if;
			   nexttempstate <= updaterowstate_1_G;   -- notelookup
			   nextstate <= readstate;
			   
		        else
			   nextstate <= rowfx_1;   -- borja radeffekthantering
			end if;

--		    end if;
-------------------------------------------------------------------------------
-- to do: indexering av alla kanalreg, provkompilera, skriva fardigt
-- updaterowstate_1, notelookupfil och testmod
-- timing?
-------------------------------------------------------------------------------
	    
	    when updaterowstate_1_C =>
--		state<="0111";
--		if ack="1" then
		if tempdata(26 downto 16)>0  and tempdata(15 downto 8) /= "00000011" and
		    tempdata(15 downto 8) /= "00000101" then   -- reset sample
							      -- if note
 							      -- present  & note
							      -- eff 3 or 5
		    nextamiganote(ch) <= tempdata(26 downto 16);
		    nextsamaddrpos(ch) <= data(25 downto 2);  -- wordpekare till start
					 	      -- paa sample
		end if;
		nextlookup <= "00";
		nextreadaddress <= readaddress+1;
		nextrd <= "1";
--		if ack = "1" then
--		nextreadaddress <= readaddress+1;
--		    nextstate <= updaterowstate_1_D;
--		    nextlookup <= "11";
--		    nextrd <= "0";
--		end if;
		nexttempstate <= updaterowstate_1_D;
		nextstate <= readstate;
--		end if;
	    when updaterowstate_1_D =>
--		state<="1000";
--		if ack="1" then
		if tempdata(31 downto 27)>0 then  --  ONLY RESET VOLUME IF THERE IS AN INSTRUMENT NUMBER
		    nextvolume(ch) <= data(30 downto 24);
		end if;
		nextsamendaddr(ch) <= "00"&data(23 downto 2);
		nextlookup <= "00";
		
		nextrd <= "1";
--		if ack = "1" then
		nextreadaddress <= readaddress+1;
--		    nextstate <= updaterowstate_1_E;
--		    nextlookup <= "11";
--		    nextrd <= "0";
--		end if;
		nexttempstate <= updaterowstate_1_E;
		nextstate <= readstate;
--		end if;
	    when updaterowstate_1_E =>

--		if ack="1" then
		nextsamloopstart(ch) <= data(25 downto 2);
		nextlookup <= "00";
		
		nextrd <= "1";
--		if ack = "1" then
		nextreadaddress <= readaddress+1;
--		    nextstate <= updaterowstate_1_F;
--		    nextlookup <= "11";
--		    nextrd <= "0";
--		end if;    
		nexttempstate <= updaterowstate_1_F;
		nextstate <= readstate;
--		end if;
		
-- vanta med freqlookup till effecterna ar behandlade, utifallatt den andras dar
	    when updaterowstate_1_F =>
--		if ack="1" then
--			nextlookup <= "11";
--			nextrd <= "0";
		    nextsamloopend(ch) <= data(25 downto 2);
		    nextstate <= rowfx_1;
--		end if;
-------------------------------------------------------------------------------
-- vanta med freqlookup till effecterna ar behandlade, utifallatt den andras dar
	   

	    when rowfx_1 =>
--		state<="1001";
--		if tempdata(15 downto 0) /= 0 then
--	        nextfxreg(ch) <= tempdata(15 downto 8);
--		    nextsongstatus(ch+8 downto ch+8)="1";
--		end if;
--		if tempdata(7 downto 0) /= 0 then
--	        nextparamreg(ch) <= tempdata(7 downto 0);
--		   nextsongstatus(ch+8 downto ch+8)="1";		   
--		end if;
	        nextfxreg(ch) <= tempdata(15 downto 8);
	        nextparamreg(ch) <= tempdata(7 downto 0);

		case tempdata(15 downto 8) is
		    
		when X"01" =>
			nextportaspeed(ch) <= tempdata(7 downto 0);
		    
		when X"02" =>
			nextportaspeed(ch) <= tempdata(7 downto 0);
		    
		when X"03" =>
			if tempdata(7 downto 0) /= "00000000" then
				nextportaspeed(ch) <= tempdata(7 downto 0);
			end if;
			if tempdata(26 downto 16) /= "00000000000" then
				nextnote_to_slide_to(ch) <= tempdata(26 downto 16);	
			end if;			
			if amiganote(ch) < tempdata(26 downto 16) then
			    nextslide_dir <= "1";  -- if 1 note++
			else
			    nextslide_dir <= "0";  -- note --
			end if;

--		    when X"04" =>
--			if vibratocontrol(ch) < 4 then  -- retrigg vibrato
--			    nextvibratopos(ch) <= (others => '0');
--			end if;
--		    when X"07" =>
--			if tremolocontrol(ch) < 4 then
--			    nexttremolopos(ch) <= (others => '0');
--			end if;
			
		when X"0B" =>
			if jumpflag = "0" then			    
			    nextpatrow <= (others => '0');
			    nextjumpflag <= "1";
			    nextsongpos <= tempdata(6 downto 0);
			end if;

	    when X"0C" =>
			nextvolume(ch) <=  tempdata(6 downto 0);

		when X"0D" =>
			if breakflag = "0" then 
			   nextpatrow <= tempdata(5 downto 0);
			   nextbreakflag <= "1";
			   if jumpflag = "0" then
			       nextsongpos <= songpos + 1;
			   end if;			    
			end if;

	    when X"0E" =>
			case tempdata(7 downto 4) is
			    when X"1" =>
				nexttempdata(26 downto 16) <=
				    tempdata(26 downto 16)-tempdata(3 downto 0);
			    when X"2" =>
				nexttempdata(26 downto 16) <=
				    tempdata(26 downto 16)+tempdata(3 downto 0);
--			    when X"4" =>
--				nextvibratocontrol(ch) <= tempdata(2 downto 0);
--			    when X"7" =>
--				nexttremolocontrol(ch) <= tempdata(2 downto 0);
			    when X"A" => 
				nextvolume(ch) <= volume(ch)+tempdata(3 downto 0);
			    when X"B" =>
--				if volume(ch) >= "000"&tempdata(3 downto 0) then
				nextvolume(ch) <= volume(ch)-tempdata(3 downto 0);
--				else
--				    nextvolume(ch) <= (others => '0');
--				end if;
			    when others => null;
			end case;
	
	    when X"0F" =>
			if tempdata(7 downto 0) < 32 then
			    nextsongspeed <= tempdata(4 downto 0);
			end if;
			-- else set tempo <= ?
	    when others => null;
		end case;
		nextstate <= updaterowstate_1_G;

	    when updaterowstate_1_G =>
--		state<="1010";
		if  tempdata(26 downto 16) > 0 then   -- fanns note, lookup freq
		    nextlookup <= "01";
		    nextreadaddress <= "0000000000000"&tempdata(26 downto 16);
		    nextrd <= "1";
--		    if ack = "1" then
--			nextstate <= updaterowstate_1_H;
--			nextlookup <= "11";
--			nextrd <= "0";
--		    end if;
		    nexttempstate <= updaterowstate_1_H;  -- sampleheadern ar
							  -- fardig, las freq
		    nextstate <= readstate;
		else
		    nextstate <= loopchstate;
			nextlookup <= "11";
			nextrd <= "0";
		end if;

	    when updaterowstate_1_H =>
--		state<="1011";
--		if ack="1" then
--			nextlookup <= "11";
--			nextrd <= "0";
		    nextfreq(ch) <= data(15 downto 0);
		    nextstate <= loopchstate;
--		end if;

	    when loopchstate =>
--		state<="1100";
		nextpataddr <= pataddr+1;
		
		if ch = 3 then
		    nextch <= 0;
		    nextstate <= increaserowstate;  
		else
		    nextch <= ch+1;
		    nextstate <= updaterowstate_1_A;
		end if;

	    when increaserowstate =>
--		state<="1101";
		if jumpflag="0" and breakflag="0" then
				
		    if  patrow = 63 then
			nextpatrow <= (others => '0');
			nextsongpos <= songpos+1;
			nextstate <= checksongendstate;
		    else
			nextpatrow <= patrow+1;
			nextstate <= mainwaitstate;
		    end if;
		else
		    nextstate <= checksongendstate;
		end if;

	    when checksongendstate =>
		if songpos >= songlength then
		    if songstatus(2 downto 2) = "1" then
			nextsongpos <= (others => '0');   -- loopa songen
			nextstate <= getpattnumstate;
		    else
			nextstopsignal <= "1";
			nextactive(0) <= "0";
			nextactive(1) <= "0";
			nextactive(2) <= "0";
			nextactive(3) <= "0";
			nextactive(4) <= "0";
			nextactive(5) <= "0";
			nextactive(6) <= "0";
			nextactive(7) <= "0";
			nextstate <= startmachinestate;
		    end if;
		else
		    nextstate <= getpattnumstate;
		end if;
			
	    when readstate =>
		
		if ack = "1" then
		    nextstate <= tempstate;
		    nextlookup <= "11";
		    nextrd <= "0";
		end if;

	    when getpattnumstate =>
--		state<="1110";
		nextlookup <= "00";
		temp := (others => '0');
		temp := "0000000000000000000"& songpos(6 downto 2);
		temp := temp+125;
			
		nextreadaddress <= temp;
		
		nextrd <= "1";
--		if ack = "1" then
--		    nextstate <= updaterowstate_1_B;
--		    nextlookup <= "11";
--		    nextrd <= "0";
--		end if;
		nexttempstate <= getpattnumstate_B;
		nextstate <= readstate;
		
	    when getpattnumstate_B =>
--		if ack="1" then
--		    nextlookup <= "11";
--		    nextrd <= "0";
		case songpos(1 downto 0) is
		    when "00" =>
			nextcurpat <= data(6 downto 0);
		    when "01" =>
			nextcurpat <= data(14 downto 8);
		    when "10" =>
			nextcurpat <= data(22 downto 16);
		    when "11" =>
			nextcurpat <= data(30 downto 24);
		    when others =>
			nextcurpat <= (others => '0');
		end case;
		nextstate <= mainwaitstate;
--		end if;

	    when pausemachinestate =>
		if songstatus(1 downto 0) = "01" then
		    nextstate <= mainwaitstate;
		    nextpausesignal <= "0";
		end if;
		
	    when endmachine =>
--		state<="1111";
--		doneflag <= "1";

	    when others => 
--		state<="1111";
		nextstate <= startmachinestate;
	end case;
	
    end process;

updatemachine:    process(clk,reset--,nextrd,nextstate,nextsongspeed,nextsongpos,nextsongtempo,
--			  nexttickcount,nextpatrow,nextreadaddress,nextsonglength,nextnumchan,
--			  nextcurpat,nextpataddr,nexttempdata,nextlastinst,nextamiganote,
--			  nextsamaddrpos,nextvolume,nextsamendaddr,nextsamloopstart,
--			  nextsamloopend,nextfreq,nextoffset,nextnotelookupaddress,nextsongstatus,
--			  nextregsongstatus,nextchanstatus,
--			  nextfxreg,nextparamreg,nextvibratopos,nextvibratocontrol,nexttremolocontrol,
--			  nexttremolopos,nextportaspeed,nextnote_to_slide_to,nextbreakflag,
--			  nextjumpflag,nextch,nextwaitcount,nextcountexpired,nextactivechannel,nextstopsignal
			  )
    begin
	if reset="0" then
	    -- initiering och nollning av variabler

	   samaddrpos(0) <= (others => '0');
	   samaddrpos(1) <= (others => '0');
	   samaddrpos(2) <= (others => '0');
	   samaddrpos(3) <= (others => '0');
	   samaddrpos(4) <= (others => '0');
	   samaddrpos(5) <= (others => '0');
	   samaddrpos(6) <= (others => '0');
	   samaddrpos(7) <= (others => '0');
	   volume(0) <= "1000000";
	   volume(1) <= "1000000";
	   volume(2) <= "1000000";
	   volume(3) <= "1000000";
	   volume(4) <= "1000000";
	   volume(5) <= "1000000";
	   volume(6) <= "1000000";
	   volume(7) <= "1000000";
	   samloopstart(0) <= (others => '0');
	   samloopstart(1) <= (others => '0');
	   samloopstart(2) <= (others => '0');
	   samloopstart(3) <= (others => '0');
	   samloopstart(4) <= (others => '0');
	   samloopstart(5) <= (others => '0');
	   samloopstart(6) <= (others => '0');
	   samloopstart(7) <= (others => '0');
	   samloopend(0) <= (others => '0');
	   samloopend(1) <= (others => '0');
	   samloopend(2) <= (others => '0');
	   samloopend(3) <= (others => '0');
	   samloopend(4) <= (others => '0');
	   samloopend(5) <= (others => '0');
	   samloopend(6) <= (others => '0');
	   samloopend(7) <= (others => '0');
	   samendaddr(0) <= (others => '0');
	   samendaddr(1) <= (others => '0');
	   samendaddr(2) <= (others => '0');
	   samendaddr(3) <= (others => '0');
	   samendaddr(4) <= (others => '0');
	   samendaddr(5) <= (others => '0');
	   samendaddr(6) <= (others => '0');
	   samendaddr(7) <= (others => '0');
	   freq(0) <= X"2000";
	   freq(1) <= X"2000";
	   freq(2) <= X"2000";
	   freq(3) <= X"2000";
	   freq(4) <= X"2b11";
	   freq(5) <= X"2b11";
	   freq(6) <= X"2b11";
	   freq(7) <= X"2b11";
	   songlength <= (others => '0');
	   readaddress <= (others => '0');
	   romaddress <= (others => '0');
--	   romutaddress <= (others => '0');
	   rd <= "0";
	   tempdata <= (others => '0');
	   songpos <= (others => '0');
	   songspeed <= (others => '0');
	   patrow <= (others => '0');
	   pataddr <= (others => '0');
	   curpat <= (others => '0');
	   tickcount <= (others => '0');
	   slide_dir <= "0";
	   
	   chanstatus <= (others => '1'); 
	   songstatus <= (others => '0');   -- song stopped
	   regsongstatus <= (others => '0');
	   offset <= (others => '0');
	   notelookupaddress <= (others => '0');
	   thestate <= stallstate;
	   tempstate <= startmachinestate;
	   lastinst(0) <= (others => '0');
	   lastinst(1) <= (others => '0');
	   lastinst(2) <= (others => '0');
	   lastinst(3) <= (others => '0');
--	   vibratocontrol(0) <= (others => '0');
--	   tremolocontrol(0) <= (others => '0');
--	   vibratocontrol(1) <= (others => '0');
--	   tremolocontrol(1) <= (others => '0');
--	   vibratocontrol(2) <= (others => '0');
--	   tremolocontrol(2) <= (others => '0');
--	   vibratocontrol(3) <= (others => '0');
--	   tremolocontrol(3) <= (others => '0');
	   fxreg(0) <= (others => '0');
	   fxreg(1) <= (others => '0');
	   fxreg(2) <= (others => '0');
	   fxreg(3) <= (others => '0');
	   paramreg(0) <= (others => '0');
	   paramreg(1) <= (others => '0');
	   paramreg(2) <= (others => '0');
	   paramreg(3) <= (others => '0');
--	   vibratopos(0) <= (others => '0');   -- ska kanske vara 0 lr -32
--	   vibratopos(1) <= (others => '0');
--	   vibratopos(2) <= (others => '0');
--	   vibratopos(3) <= (others => '0');
--	   tremolopos(0) <= (others => '0');   -- ska kanske vara 0 lr -32
--	   tremolopos(1) <= (others => '0');
--	   tremolopos(2) <= (others => '0');
--	   tremolopos(3) <= (others => '0');
	   portaspeed(0) <= (others => '0');
	   portaspeed(1) <= (others => '0');
	   portaspeed(2) <= (others => '0');
	   portaspeed(3) <= (others => '0');
	   note_to_slide_to(0) <= (others => '0');
	   note_to_slide_to(1) <= (others => '0');
	   note_to_slide_to(2) <= (others => '0');
	   note_to_slide_to(3) <= (others => '0');
	   active(0) <= (others => '0');
	   active(1) <= (others => '0');
	   active(2) <= (others => '0');
	   active(3) <= (others => '0');
	   active(4) <= (others => '0');
	   active(5) <= (others => '0');
	   active(6) <= (others => '0');
	   active(7) <= (others => '0');
	   breakflag <= (others => '0');
	   jumpflag <= (others => '0');
	   ch <= 0;
	   countexpired <= "1";
	   activechannel <= 8;
	   stopsignal <= "0";
	   pausesignal <= "0";
--	   waitclock <= conv_std_logic_vector(1000,16);
	   waitclock <= X"4E200";   -- 320.000 = 50 ticks/s @ 16MHz
	   stepclock <= X"001E8";  	-- 488 = 32 768 Hz @ MHz
	   waitcount <= (others => '0');
	   stepcount <= X"00010";
	   lookup <= "11";
	   muxselect <= (others => '0');
	   amiganote(0) <= (others => '0');
	   amiganote(1) <= (others => '0');
	   amiganote(2) <= (others => '0');
	   amiganote(3) <= (others => '0');

	   mastervolreg<=X"FFFFFF";
	   autoset <= "0";

	elsif rising_edge(clk) then
	    -- uppdatering av variabler
	    -- ickenext <= next
	    slide_dir <= nextslide_dir;
	    muxselect <= nextmuxselect;
	    rd <= nextrd;
		lookup <= nextlookup;
	    thestate <= nextstate;
		tempstate <= nexttempstate;
	    songspeed <= nextsongspeed;
	    songpos <= nextsongpos;
	    songtempo <= nextsongtempo;
	    tickcount <= nexttickcount;
	    patrow <= nextpatrow;
	    readaddress <= nextreadaddress;
	    romaddress <= nextromaddress;
--	    romutaddress <= nextromaddress;
	    songlength <= nextsonglength;
	    numchan <= nextnumchan;
	    curpat <= nextcurpat;
	    pataddr <= nextpataddr;
	    tempdata <= nexttempdata;
	    lastinst <= nextlastinst;
	    amiganote <= nextamiganote;
	    samaddrpos <= nextsamaddrpos;
	    volume <= nextvolume;
	    samendaddr <= nextsamendaddr;
	    samloopstart <= nextsamloopstart;
	    samloopend <= nextsamloopend;
	    freq <= nextfreq;

	    offset <= nextoffset;
	    notelookupaddress <= nextnotelookupaddress;
	    chanstatus <= nextchanstatus;
	    songstatus <= nextsongstatus;
	    active <= nextactive;
	    regsongstatus <= nextregsongstatus;
	    							 	
	    fxreg <= nextfxreg;
	    paramreg <= nextparamreg;
--	    vibratopos <= nextvibratopos;
--	    vibratocontrol <= nextvibratocontrol;
--	    tremolocontrol <= nexttremolocontrol;
--	    tremolopos <= nexttremolopos;
	    portaspeed <= nextportaspeed;
	    note_to_slide_to <= nextnote_to_slide_to;
	    breakflag <= nextbreakflag;
	    jumpflag <= nextjumpflag;
	    ch <= nextch;
	    
	    waitcount <= nextwaitcount;
	    waitclock <= nextwaitclock;
	    stepcount <= nextstepcount;
	    stepclock <= nextstepclock;
	    
	    countexpired <= nextcountexpired;
	    activechannel <= nextactivechannel;
	    stopsignal <= nextstopsignal;
	    pausesignal <= nextpausesignal;
		
	    mastervolreg<=nextmastervolreg;
	    autoset <= nextautoset;
	end if;
	
    end process;

end mymainunit;


