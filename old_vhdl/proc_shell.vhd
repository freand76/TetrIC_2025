library IEEE;
use IEEE.std_logic_1164.all;

entity proc_shell is
    port (p_clock : in std_logic;
	  p_reset : in std_logic_vector(0 downto 0);
	  p_extern_stall : in std_logic_vector(0 downto 0);
	  p_debug_out : out std_logic_vector(0 downto 0);
	  p_databus : inout std_logic_vector(31 downto 0);
	  p_addrbus : out std_logic_vector(23 downto 0);
	  p_csync : out std_logic_vector(0 downto 0);
	  p_addr_flash : out std_logic_vector(21 downto 0);
	  p_data_flash : inout std_logic_vector(7 downto 0);
	  p_oe_flash   : out std_logic_vector(0 downto 0);
	  p_ram_rw : out std_logic_vector(0 downto 0);
	  p_joy : in std_logic_vector(7 downto 0);
	  p_ram_oe : out std_logic_vector(0 downto 0);
	  p_sound_addr : out std_logic_vector(0 downto 0);
	  p_sound_wr : out std_logic_vector(0 downto 0));
end proc_shell;

architecture arch_proc_shell of proc_shell is

    component pro
	port (p_databus_in : in std_logic_vector(31 downto 0);
	      p_memdmem_databus_out : out std_logic_vector(31 downto 0);
	      p_imem_addr_out : out std_logic_vector(23 downto 0);
	      p_dmem_addr_out : out std_logic_vector(23 downto 0);
	      install_1:in std_logic_vector(0 downto 0);
	      inclock:in std_logic;
	      inreset: in std_logic_vector(0 downto 0);
	      dmem_arb_in, imem_arb_in : in std_logic_vector(0 downto 0);
	      dmem_bus_req : out std_logic_vector(0 downto 0);
	      dmemendbrq : out std_logic_vector(0 downto 0);
	      dmem_w_out : out std_logic_vector(0 downto 0);
	      gfx_to_alu : in std_logic_vector(31 downto 0);
	      joy_to_alu : in std_logic_vector(7 downto 0);
	      music_to_alu : in std_logic_vector(31 downto 0);
	      dmem_pre_write : out std_logic_vector(0 downto 0);
	      dmem_pre_read : out std_logic_vector(0 downto 0);
-- debug ----------------------------------------------------------------------
	      debug_pc,
	      debug_reg,
	      debug_alu1in,
	      debug_alu2in,
	      debug_aluut,
	      debug_instr : out std_logic_vector(31 downto 0);
	      debug_ctrl  : out std_logic_vector(18 downto 0)); 
    end component;
    
    component mainunit
   	port (addrbus : in std_logic_vector(23 downto 0); 
	      databus : in std_logic_vector(31 downto 0); 
	      grw   : in std_logic_vector(0 downto 0);
	      cs : in std_logic_vector(0 downto 0);
	      ack : in std_logic_vector(0 downto 0);  		
	      data : in std_logic_vector(31 downto 0); 
	      reset : in std_logic_vector(0 downto 0);
	      clk : in std_logic;
	      romutaddress : out std_logic_vector(23 downto 0);
	      rdout : out std_logic_vector(0 downto 0);  
	      step : out std_logic_vector(0 downto 0);
	      rightsample : out std_logic_vector(7 downto 0);
	      leftsample : out std_logic_vector(7 downto 0);
	      status_out : out std_logic_vector(31 downto 0);
	      stall_in : in std_logic_vector(0 downto 0));
    end component;

    component ljudxbox
	port(clk :in std_logic;
	     reset :in std_logic_vector(0 downto 0);
	     stall :in std_logic_vector(0 downto 0);
	     stepin :in std_logic_vector(0 downto 0);
	     rightin :in std_logic_vector(7 downto 0);
	     leftin : in std_logic_vector(7 downto 0);
	     soundwr : out std_logic_vector(0 downto 0);
	     soundaddr : out std_logic_vector(0 downto 0);
	     sounddata : out std_logic_vector(7 downto 0));
    end component;
    
    component fakebox
	port (data_ram : out std_logic_vector(31 downto 0);
	      addr_ram : out  std_logic_vector(23 downto 0);
	      write_ram : out std_logic_vector(0 downto 0);
	      data_flash : in std_logic_vector(7 downto 0);
	      addr_flash : out std_logic_vector(21 downto 0);
	      oe_flash : out std_logic_vector(0 downto 0);
	      stall_out : out std_logic_vector(0 downto 0);
	      clock : in std_logic;
	      reset : in std_logic_vector(0 downto 0));
    end component;

    component gfxbox
	port (addrbus : out std_logic_vector(23 downto 0);
	      addrin : in std_logic_vector(3 downto 0);
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
    end component;

    component memctrl
	 port (ramadr : in std_logic_vector(23 downto 0);
	       fbw,procdmemw : in std_logic_vector(0 downto 0);
	       ljudcs, bildcs, ramrw, globalrw: out std_logic_vector(0 downto 0);
	       clk : in std_logic);
    end component;

    component joyctrl
	 port (clk	: in std_logic;
	       reset : in std_logic_vector(0 downto 0);
	       joyin : in std_logic_vector(7 downto 0);
	       ctrlout : out std_logic_vector(7 downto 0));
    end component;

    component arb
	port (bildreq,procdmemreq, procdmemreqend, ljudreq : in std_logic_vector(0 downto 0) ;
	  bildarb,procdmemarb,procdmemarbend, procimemarb, ljudarb : out std_logic_vector(0 downto 0));
    end component;

    component debugbox
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
    end component;

    signal
	s_debug_pc,
	s_debug_reg,
	s_debug_alu1in,
	s_debug_alu2in,
	s_debug_aluut,
	s_debug_instr,
	s_debug_ctrl_total : std_logic_vector(31 downto 0);
    signal
	s_debug_ctrl_pro : std_logic_vector(18 downto 0);
    signal
	s_ram_addr,
	s_imem_addr_out,
	s_dmem_addr_out,
	s_gfx_addr_out,
	s_ljud_addr_out,
	s_fake_addr_out: std_logic_vector(23 downto 0);
    signal
	s_dmem_data_out,
	s_fake_data_out : std_logic_vector(31 downto 0);
-------------------------------------------------------------------------------
    signal s_addr_flash : std_logic_vector(21 downto 0);
    signal s_colors : std_logic_vector(15 downto 0);
    signal
	s_gfx_to_alu,
	s_ljud_to_proc : std_logic_vector(31 downto 0);
    signal s_instr : std_logic_vector(15 downto 0);
    signal s_prog_count : std_logic_vector(23 downto 0);
    signal s_reg_one : std_logic_vector(31 downto 0);
    signal s_joy_to_proc : std_logic_vector(7 downto 0);
    signal s_clocked_ctrl : std_logic_vector(5 downto 0);
    signal
	s_ljud_data,
	s_ljud_rs,
	s_ljud_ls : std_logic_vector(7 downto 0);
    signal s_ljud_step : std_logic_vector(0 downto 0);
     -- signals ----------------------------------------------------------------
    signal
        s_stall,       
	s_proc_reset,
	s_dmem_pre_write,
	s_dmem_pre_read,
	-- arb signals ------------------------------------------------------------
	s_bild_arb,
	s_dmem_arb,
	s_dmem2_arb,
	s_imem_arb,
	s_ljud_arb,
        -- bus req signals --------------------------------------------------------
	s_bild_brq,
	s_dmem_brq,
	s_procdmemendreq,
	s_ljud_brq,
	-- rw signals -------------------------------------------------------------
	s_globalrw,
	s_fb_write,
	s_dmem_read,
	s_dmem_write,
	s_imem_read,
	-- cs signals -------------------------------------------------------------
	s_bild_cs,
	s_ljud_cs
	:	std_logic_vector(0 downto 0);


-------------------------------------------------------------------------------
      
begin  -- arch_proc_shell

    thememctrl : memctrl
	port map (ramadr => s_dmem_addr_out,
		  fbw => s_fb_write,
		  procdmemw => s_dmem_write,
		  ljudcs => s_ljud_cs,
		  bildcs => s_bild_cs,
		  ramrw => p_ram_rw,
		  globalrw => s_globalrw,
		  clk => p_clock);
    
    thefakebox : fakebox
	port map (data_ram=>s_fake_data_out,
		  addr_ram=>s_fake_addr_out,
		  write_ram=>s_fb_write,
		  data_flash => p_data_flash,
		  addr_flash => s_addr_flash,
		  oe_flash => p_oe_flash,
		  stall_out=>s_stall,
		  clock=>p_clock,
		  reset=>p_reset);
    
    thegfxbox : gfxbox
	port map (addrbus=>s_gfx_addr_out,
		  addrin => s_dmem_addr_out(3 downto 0),
		  databus=>p_databus,
		  cs=>s_bild_cs,
		  grw=>s_globalrw,
		  copreg=>s_gfx_to_alu,
		  arbask=>s_bild_brq,
		  arbin=>s_bild_arb,
		  stop=>s_stall,
		  csync=>p_csync,
		  colors=>s_colors,
		  reset=>p_reset,
		  clk=>p_clock);

    theprocessor:pro
	port map (p_databus_in => p_databus,
		  p_memdmem_databus_out => s_dmem_data_out,
		  p_imem_addr_out => s_imem_addr_out,
		  p_dmem_addr_out => s_dmem_addr_out,
		  install_1=>p_extern_stall,
		  inclock=>p_clock,
		  inreset=>s_proc_reset,
		  dmem_arb_in=>s_dmem_arb,
		  imem_arb_in=>s_imem_arb,
		  dmem_bus_req=>s_dmem_brq,
		  dmemendbrq => s_procdmemendreq,
		  dmem_w_out=>s_dmem_write,
		  gfx_to_alu=>s_gfx_to_alu,
		  joy_to_alu => s_joy_to_proc,
		  music_to_alu => s_ljud_to_proc,
		  dmem_pre_write => s_dmem_pre_write,
		  dmem_pre_read => s_dmem_pre_read,

		  debug_pc => s_debug_pc,
		  debug_reg => s_debug_reg,
		  debug_alu1in => s_debug_alu1in,
		  debug_alu2in => s_debug_alu2in,
		  debug_aluut => s_debug_aluut,
		  debug_instr => s_debug_instr,
		  debug_ctrl => s_debug_ctrl_pro);
    
    MU1: mainunit
	port map (addrbus => s_dmem_addr_out,
	          databus => p_databus,
		  grw => s_globalrw,
		  cs => s_ljud_cs,
		  ack => s_ljud_arb,
		  data => p_databus,
		  reset => p_reset,
		  clk => p_clock,
		  romutaddress=> s_ljud_addr_out,
		  rdout => s_ljud_brq,
		  step => s_ljud_step,
		  rightsample => s_ljud_rs,
		  leftsample => s_ljud_ls,
		  status_out => s_ljud_to_proc,
		  stall_in => s_stall);
    
    theljudxbox: ljudxbox
	port map (clk => p_clock,
		  reset => p_reset,
		  stall => s_stall,
		  stepin => s_ljud_step,
		  rightin => s_ljud_rs,
		  leftin => s_ljud_ls,
		  soundwr => p_sound_wr,
		  soundaddr => p_sound_addr,
		  sounddata => s_ljud_data);
        
    thearbitrator : arb
	port map (bildreq => s_bild_brq,
		  procdmemreq => s_dmem_brq,
		  procdmemreqend => s_procdmemendreq,
		  ljudreq => s_ljud_brq,
		  bildarb => s_bild_arb,
		  procdmemarb => s_dmem_arb,
		  procdmemarbend => s_dmem2_arb,
		  procimemarb => s_imem_arb,
		  ljudarb => s_ljud_arb);

    the_joyctrl : joyctrl
	 port map(clk => p_clock,
		  reset => p_reset,
		  joyin => p_joy,
		  ctrlout => s_joy_to_proc);
    
    thedebugbox : debugbox
	port map (clk => p_clock,
		  reset => p_reset,
		  load => p_extern_stall,
		  debug_pc => s_debug_pc,
		  debug_reg => s_debug_reg,
		  debug_alu1in => s_debug_alu1in,
		  debug_alu2in => s_debug_alu2in,
		  debug_aluut => s_debug_aluut,
		  debug_instr => s_debug_instr,
		  debug_ctrl => s_debug_ctrl_total,
		  serialout => p_debug_out);

    s_debug_ctrl_total <= s_clocked_ctrl & "0000000" & s_debug_ctrl_pro;
    
    s_proc_reset <= "0" when p_reset = "0" or s_stall = "0" else "1";

    p_addr_flash <= s_addr_flash when s_stall="0" else
                    "000000"&s_colors(10 downto 5)&s_colors(15 downto 11)&s_colors(4 downto 0);
    
    p_data_flash <= s_ljud_data when s_stall = "1" else (others => 'Z');
    
    -- port assignments -----------------------------------------------------------
    p_addrbus <= s_ram_addr;
    -------------------------------------------------------------------------------

    p_databus <= s_fake_data_out when s_clocked_ctrl(0 downto 0)="1" else
    			 s_dmem_data_out when s_clocked_ctrl(1 downto 1)="1" else (others=>'Z');
        
    s_ram_addr <= s_fake_addr_out when s_clocked_ctrl(0 downto 0)="1" else (others=>'Z');
    s_ram_addr <= s_gfx_addr_out when s_clocked_ctrl(4 downto 4)="1" else (others=>'Z'); 
    s_ram_addr <= s_dmem_addr_out when s_clocked_ctrl(3 downto 3)="1" else (others=>'Z');
    s_ram_addr <= s_imem_addr_out when s_clocked_ctrl(2 downto 2)="1" else (others=>'Z');
    s_ram_addr <= s_ljud_addr_out when s_clocked_ctrl(5 downto 5)="1" else (others=>'Z');
    
    process (p_clock, p_reset)
    begin  -- process
	-- activities triggered by asynchronous reset (active low)
	if p_reset = "0" then
	    s_clocked_ctrl <= "000000";
	    p_ram_oe <= "1";
	    -- activities triggered by rising edge of clock
	elsif rising_edge(p_clock) then
		s_clocked_ctrl(0 downto 0)<=not s_stall;
		s_clocked_ctrl(1 downto 1)<=s_stall and (s_dmem_pre_write or s_dmem2_arb);
		s_clocked_ctrl(2 downto 2)<=s_stall and not s_bild_arb and not s_dmem_arb and not s_dmem2_arb and not s_ljud_arb;
		s_clocked_ctrl(3 downto 3)<=s_stall and (s_dmem_arb or s_dmem2_arb);
		s_clocked_ctrl(4 downto 4)<=s_stall and s_bild_arb;
		s_clocked_ctrl(5 downto 5)<=s_stall and s_ljud_arb;		--	Ljud
		p_ram_oe <= not(s_stall) or not(s_bild_arb or s_imem_arb or s_dmem_pre_read or s_ljud_arb);
	end if;
    end process;
end arch_proc_shell;






