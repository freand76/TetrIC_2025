library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

entity gfxbox is
    port (addrbus : out std_logic_vector(23 downto 0);
	  addrin  : in std_logic_vector(3 downto 0);
	  databus : in std_logic_vector(31 downto 0);
	  cs      : in std_logic_vector(0 downto 0);
	  grw     : in std_logic_vector(0 downto 0);
	  copreg  : out std_logic_vector(31 downto 0);
	  arbask  : out std_logic_vector(0 downto 0);
	  arbin   : in std_logic_vector(0 downto 0);
	  stop    : in std_logic_vector(0 downto 0);  	
	  csync   : out std_logic_vector(0 downto 0);
	  colors  : out std_logic_vector(15 downto 0);
	  reset   : in std_logic_vector(0 downto 0);
	  clk     : in std_logic);
end gfxbox;

architecture mygfxbox of gfxbox is

    constant SWEEP1B : integer := 6;
    constant SWEEP1E : integer := 309;
    constant SWEEP2B : integer := 319;
    constant SWEEP2E : integer := 622;
    
    -- Statemachine
    type statemachinetype is (startpage,firstarbask,firstlineread,firsttopipe,startline,askforarb,readmem,movetopipe,pageorline);
    signal thestate,nextthestate : statemachinetype;

    -- Skrivbara register
    signal toppos,nexttoppos         : std_logic_vector(15 downto 0);
    signal leftpos,nextleftpos       : std_logic_vector(15 downto 0);
    signal pixperline,nextpixperline : std_logic_vector(15 downto 0);
    signal lineperimg,nextlineperimg : std_logic_vector(15 downto 0);
    signal pixread,nextpixread       : std_logic_vector(3 downto 0);
    signal gfxaddr,nextgfxaddr       : std_logic_vector(23 downto 0);
    signal deltaaddr,nextdeltaaddr   : std_logic_vector(23 downto 0);

    signal ROWLENGTH,NEXTROWLENGTH   : std_logic_vector(15 downto 0);
    signal HSYNCLEN,NEXTHSYNCLEN     : std_logic_vector(15 downto 0);
    signal ESYNCLEN,NEXTESYNCLEN     : std_logic_vector(15 downto 0);
    signal VSYNCLEN,NEXTVSYNCLEN     : std_logic_vector(15 downto 0);
    
    -- Räknare
    signal vcount,nextvcount : std_logic_vector(9 downto 0);
    signal pixstart,nextpixstart : std_logic_vector(15 downto 0);
    signal hcount,nexthcount : std_logic_vector(10 downto 0);
    signal addrptr,nextaddrptr : std_logic_vector(23 downto 0);
    signal pixcount,nextpixcount : std_logic_vector(10 downto 0);
    signal framecount,nextframecount : std_logic_vector(11 downto 0);
    
    -- Färgregister
    signal colreg,nextcolreg : std_logic_vector(15 downto 0);
    signal pixreg,nextpixreg : std_logic_vector(31 downto 0);
    signal pipereg,nextpipereg : std_logic_vector(31 downto 0);

    -- Signaleringsignaler
    signal linecount : std_logic_vector(8 downto 0);
    signal moredata,newdata,newpipe,newleft,newright,blanking : std_logic_vector(0 downto 0);
    signal countctrl  : std_logic_vector(1 downto 0);
begin  -- mygfxbox

    -- Synchräknare
    countproc:
    process(vcount,hcount,framecount,ROWLENGTH)
    begin
	nextvcount<=vcount;
	nexthcount<=hcount+1;
	nextframecount<=framecount;
	
	if (hcount = ROWLENGTH-1) then    
	    nextvcount<=vcount+1;
	    nexthcount<=(others=>'0');
	    if (vcount >= 625) then 
	       nextvcount<="0000000001";
	    end if;

	    if (vcount=1 or vcount=313) then
		nextframecount<=framecount+1;
	    end if;
	    
	end if;
    end process;

    -- Synchskapare, csync
    syncproc:
    process(vcount,hcount,linecount,ROWLENGTH,VSYNCLEN,HSYNCLEN,ESYNCLEN)
	variable tevcount : integer range 0 to 1023;
	variable tecsync  : std_logic_vector(0 downto 0);
	variable templine : std_logic_vector(9 downto 0);
	variable HALFLINE : std_logic_vector(10 downto 0);
    begin
	
	tevcount:=conv_integer(vcount);
	HALFLINE:=ROWLENGTH(11 downto 1);
	
	case tevcount is
	    when 1 | 2 | 314 | 315 =>
		-- V V ________XX________XX
		if ( ((hcount>=VSYNCLEN) and (hcount<HALFLINE)) or (hcount>=HALFLINE+VSYNCLEN)) then
		    tecsync:="1";
		else
		    tecsync:="0";
		end if;
	    when 3 =>
		-- V E ________XX_XXXXXXXXX
		if ( ((hcount>=VSYNCLEN) and (hcount<HALFLINE)) or (hcount>=HALFLINE+ESYNCLEN)) then
		    tecsync:="1";
		else
		    tecsync:="0";
		end if;
	    when 4 | 5 | 311 | 312 | 316 | 317 | 624 | 625 =>
		-- E E _XXXXXXXXX_XXXXXXXXX
		if ( ((hcount>=ESYNCLEN) and (hcount<HALFLINE)) or (hcount>=HALFLINE+ESYNCLEN)) then
		    tecsync:="1";
		else
		    tecsync:="0";
		end if;
	    when 313 =>
		-- E V _XXXXXXXXX________XX
	        if ( ((hcount>=ESYNCLEN) and (hcount<HALFLINE)) or (hcount>=HALFLINE+VSYNCLEN)) then
		    tecsync:="1";
		else
		    tecsync:="0";
		end if;
	    when 318 =>
		-- E   _XXXXXXXXXXXXXXXXXXX
		if (hcount<ESYNCLEN) then
		    tecsync:="0";
		else
		    tecsync:="1";
		end if;
	    when 623 =>
		-- H E __XXXXXXXX_XXXXXXXXX
		if (((hcount>=HSYNCLEN) and (hcount<HALFLINE)) or (hcount>=HALFLINE+ESYNCLEN)) then
		    tecsync:="1";
		else
		    tecsync:="0";
		end if;
	    when others =>
		-- H   __XXXXXXXXXXXXXXXXXX
		if (hcount<HSYNCLEN) then
		    tecsync:="0";
		else
		    tecsync:="1";
		end if;		
	end case;

	if vcount>SWEEP1B and vcount<SWEEP1E then
	    templine:=vcount(9 downto 0)-conv_std_logic_vector(SWEEP1B,10);
	elsif vcount>SWEEP2B and vcount <SWEEP2E then
	    templine:=vcount(9 downto 0)-conv_std_logic_vector(SWEEP2B,10);
	else
	    templine:=(others=>'0');
	end if;
	
	linecount<=templine(8 downto 0);
	csync<=not tecsync;

    end process;

    -- Registerskrivning
    writeproc:
    process(toppos,leftpos,
	    pixperline,
	    lineperimg,pixread,
	    gfxaddr,deltaaddr,
	    addrin,databus,grw,cs,
	    ROWLENGTH,HSYNCLEN,ESYNCLEN,VSYNCLEN)

	variable tempaddr : std_logic_vector(3 downto 0);
    begin
	-- Defaulttilldelningar

	nexttoppos<=toppos;  		-- 16 bitar
	nextleftpos<=leftpos;  		-- 16 bitar
	nextpixperline<=pixperline;  	-- 16 bitar
	nextlineperimg<=lineperimg;  	-- 16 bitar
	nextpixread<=pixread;  		-- 4 bitar
	nextgfxaddr<=gfxaddr;  		-- 24 bitar
	nextdeltaaddr<=deltaaddr;  	-- 24 bitar

	NEXTROWLENGTH <= ROWLENGTH;  	-- 16 bitar
	NEXTHSYNCLEN <= HSYNCLEN;  	-- 16 bitar
	NEXTESYNCLEN <= ESYNCLEN;  	-- 16 bitar
	NEXTVSYNCLEN <= VSYNCLEN;  	-- 16 bitar
	
	if (grw="0" and cs="0")  then
	    tempaddr:=addrin(3 downto 0);
	    case tempaddr is
		when "0000"  => nexttoppos<=databus(15 downto 0);
		when "0001"  => nextleftpos<=databus(15 downto 0);		
		when "0010"  => nextpixperline<=databus(15 downto 0);
		when "0011"  => nextlineperimg<=databus(15 downto 0);
		when "0100"  => nextpixread<=databus(3 downto 0);
		when "0101"  => nextgfxaddr<=databus(23 downto 0);
		when "0110"  => nextdeltaaddr<=databus(23 downto 0);
		when "0111"  => NEXTROWLENGTH<=databus(15 downto 0);
		when "1000"  => NEXTHSYNCLEN<=databus(15 downto 0);
		when "1001"  => NEXTESYNCLEN<=databus(15 downto 0);
		when "1010"  => NEXTVSYNCLEN<=databus(15 downto 0);
		    
		when others => null;
	    end case;
	end if;
    end process;

    -- Blankingcontrol
    blankproc:
    process(pixstart,pixread,hcount,leftpos)
    begin
	if (pixstart>0 and pixstart<=pixread&"0" and hcount>=leftpos) then
	    blanking<="0";
	else
	    blanking<="1";
	end if;
    end process;

    -- Ny Data från minnet
    nextpixreg <= databus when newdata="1" else pixreg;

    -- Ny Pixdata till piperegister
    nextpipereg <=nextpixreg when newpipe="1" else pipereg;

    -- Vänsterpixel
    newleft<="1" when pixstart="00000"&pixread&"0" else "0";
    
    -- Högerpixel
    newright<="1" when pixstart="000000"&pixread else "0";

    -- Mer data från minnet
    moredata<="1" when pixstart="000000000001" else "0";
    
    -- Ny Pixel från pixreg
    nextcolreg <= pipereg(31 downto 16) when newleft="1" else
		  pipereg(15 downto 0) when newright="1" else
		  colreg;
    
    -- Färger ut på skärmen
    colors <= colreg when blanking="0" else (others=>'0');

    -- Diverse data som processorn kan tänkas vilja ha
    copreg <= framecount(11 downto 0)&hcount(10 downto 0)&linecount(8 downto 0);

    nextpixcount<=(others=>'0') when countctrl="01" else
		   pixcount+1 when (newleft="1" or newright="1") else
		   pixcount;

    nextpixstart<=pixstart-1 when countctrl="00" else
		  leftpos-1 when countctrl="01" else
		  "00000000000"&pixread&"0" when countctrl="10" else
		  pixstart;

    -- Datahämtning/Skrivning till skärm
    gfxproc:
    process(hcount,toppos,lineperimg,pixperline,moredata,
	    arbin,stop,addrptr,gfxaddr,deltaaddr,linecount,pixcount,
	    thestate)
    begin
	-- Defaulttilldelningar
	arbask<="0";
	addrbus<=addrptr;
	nextthestate<=thestate;
	nextaddrptr<=addrptr;

	newdata<="0";
	newpipe<="0";
	countctrl<="00";
	case thestate is
	
	-----------------------------------------------------------------------
        -- Start Page
        -----------------------------------------------------------------------
	    when startpage =>
		if stop="1" then
		    nextaddrptr<=gfxaddr;
		    nextthestate<=firstarbask;		    
		end if;
	-----------------------------------------------------------------------
        -- Arbitreringsförfrågan
        -----------------------------------------------------------------------
	    when firstarbask =>
		arbask<="1";
		if arbin="1" then
		    nextthestate<=firstlineread;
		end if;
	-----------------------------------------------------------------------
        -- Minnesläsning innan linjestart
        -----------------------------------------------------------------------
	    when firstlineread =>
		newdata<="1";
		nextthestate<=firsttopipe;
		nextaddrptr<=addrptr+1;
	-----------------------------------------------------------------------
        -- Move to pipe
        -----------------------------------------------------------------------
	    when firsttopipe =>
		newpipe<="1";
		nextthestate<=startline;
	-----------------------------------------------------------------------
        -- Start Line
        -----------------------------------------------------------------------
	    when startline =>
		countctrl<="01";
		if (linecount>toppos) and (linecount<= (lineperimg+toppos)) and hcount=0 then
		    nextthestate<=askforarb;
		end if;
	-----------------------------------------------------------------------
        -- Arbitreringsförfrågan
        -----------------------------------------------------------------------
            when askforarb =>
		arbask<="1";
		if arbin="1" then
		    nextthestate<=readmem;
		end if;
	-----------------------------------------------------------------------
	-- Minnesläsning
	-----------------------------------------------------------------------
	    when readmem =>
		newdata<="1";
		nextthestate<=movetopipe;
		nextaddrptr<=addrptr+1;
	-----------------------------------------------------------------------
        -- Move to pipe again
        -----------------------------------------------------------------------
	    when movetopipe =>
		if moredata="1" then
		    newpipe<="1";
		    countctrl<="10";
		    if pixcount>=pixperline-2 then
			nextthestate<=pageorline;
		    else
			nextthestate<=askforarb;
		    end if;
		end if;
	-----------------------------------------------------------------------
        -- Ny sida eller ny linje
        -----------------------------------------------------------------------
	    when pageorline =>
		if (linecount >= (lineperimg+toppos)) then
		    nextthestate<=startpage;
		else
		    nextthestate<=firstarbask;
		    nextaddrptr<=addrptr+deltaaddr;
		end if;
	end case;
        
    end process;

    -- Klockad process
    clkproc:
    process(clk,reset)
    begin
	if reset="0" then
	    -- Resettilldelningar

	    -- Tillståndmaskin i startläge
	    thestate<=startpage;

	    -- Första synliga pixeln på varje rad ligger på mellan 200-225
	    -- 265 verkar vara bra för att få centrerad bild
	    leftpos<=X"0109";
	    -- Antal klockcykler per pixel
	    pixread<=X"2";
	    -- Radlängd och syncsignalslängder
	    ROWLENGTH <= X"0400";
	    HSYNCLEN <= X"004B";
	    ESYNCLEN <= X"0025";
	    VSYNCLEN <= X"01B4";
            -- Första synliga linje på bildsvepet
	    -- Ungefär 30 verkar vara bra
	    toppos<=X"001E";
	    -- Antal pixlar per rad (320 default)
	    pixperline<=X"0140";
	    -- Antal linjer per bild (256 default)
	    lineperimg<=X"0100";
	    -- Startaddress för grafikdata
	    gfxaddr<=X"008000";
	    -- deltaaddresshopp efter varje linje
	    deltaaddr<=(others=>'0');
	    -- vsyncräknare
	    vcount<="0000000001";
	    -- hsyncräknare
	    hcount<=(others=>'0');
	    -- Nuvarande address
	    addrptr<=(others=>'0');
	    -- Färger ut
	    colreg<=(others=>'0');
	    -- Piperegister
	    pipereg<=(others=>'0');
	    -- Nuvarande pixlar
	    pixreg<=(others=>'0');
	    -- Klockpulser till nästa pixel
	    pixstart<=(others=>'0');
	    -- Antal pixlar utritade på denna linje
	    pixcount<=(others=>'0');
	    -- Antal bilder uppritade
	    framecount<=(others=>'0');
	elsif rising_edge(clk) then

	    -- Uppdatering vid klockflank
	    toppos<=nexttoppos;
	    leftpos<=nextleftpos;
	    thestate<=nextthestate;
	    pixperline<=nextpixperline;
	    lineperimg<=nextlineperimg;
	    pixread<=nextpixread;
	    gfxaddr<=nextgfxaddr;
	    deltaaddr<=nextdeltaaddr;
	    vcount<=nextvcount;
	    hcount<=nexthcount;
	    addrptr<=nextaddrptr;
	    colreg<=nextcolreg;
	    pixreg<=nextpixreg;
	    pipereg<=nextpipereg;
	    pixstart<=nextpixstart;
	    pixcount<=nextpixcount;
	    framecount<=nextframecount;
	    ROWLENGTH <= NEXTROWLENGTH;
	    HSYNCLEN <= NEXTHSYNCLEN;
	    ESYNCLEN <= NEXTESYNCLEN;
	    VSYNCLEN <= NEXTVSYNCLEN;
	end if;
	
    end process;

end mygfxbox;
