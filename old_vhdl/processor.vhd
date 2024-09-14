
library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.std_logic_unsigned.all;

entity pro is
    
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
end pro;


architecture structure_pro of pro is

    component pcadd1
	port (pc : in std_logic_vector(31 downto 0);
	      stall : in std_logic_vector(0 downto 0);
	      imem_arb_in : in std_logic_vector(0 downto 0);
	      res : out std_logic_vector(31 downto 0));
    end component;

    component pcmux1 
        port (in0 : in std_logic_vector(31 downto 0);
	      in1 : in std_logic_vector(31 downto 0);
	      sel : in std_logic_vector(0 downto 0);
	      out0 : out std_logic_vector(31 downto 0));
    end component;

    component pcmux2 
    	port (in0 : in std_logic_vector(31 downto 0);
	      in1 : in std_logic_vector(31 downto 0);
	      sel : in std_logic_vector(0 downto 0);
	      out0 : out std_logic_vector(31 downto 0));
    end component;
    
    component noplogic
	 port (imem_arb_in, global_stall_in : in std_logic_vector(0 downto 0);
	       pc_stall_out : out std_logic_vector(0 downto 0));
    end component;
    
    component imem
	port (from_proc_addr_in : in std_logic_vector(23 downto 0);
	      to_proc_data_out : out std_logic_vector(31 downto 0);
	      from_bus_data_in : in std_logic_vector(31 downto 0);
	      to_bus_addr_out : out std_logic_vector(23 downto 0);
	      arb_in : in std_logic_vector(0 downto 0);
	      stall_in : in std_logic_vector(0 downto 0));
    end	component;

    component signandshift
	port (in0 : in std_logic_vector(25 downto 0);
	      out0 : out std_logic_vector(31 downto 0));
    end component;

    component ctrl
	port (opcode,func : in std_logic_vector(5 downto 0);
	      ife : out std_logic_vector(0 downto 0);
	      id : out std_logic_vector(1 downto 0);
	      ex : out std_logic_vector(7 downto 0);
	      mem : out std_logic_vector(4 downto 0);
	      wb : out std_logic_vector(2 downto 0));
    end component;

    component reg
	port (reset : in std_logic_vector(0 downto 0);
	      rr1,rr2,wr : in std_logic_vector(4 downto 0);
	      wd : in std_logic_vector(31 downto 0);
	      debug_reg1 : out std_logic_vector(31 downto 0);
	      clk: in std_logic;
	      rw : in std_logic_vector(0 downto 0);
	      rd1,rd2 : out std_logic_vector(31 downto 0));
    end component;

    component signext
	port (in0 : in std_logic_vector(15 downto 0);
	      ctrin : in std_logic_vector(1 downto 0);
	      out0 : out std_logic_vector(31 downto 0));
    end component;

    component pcadd2
	port (in0,in1 : in std_logic_vector(31 downto 0);
	      out0 : out std_logic_vector(31 downto 0));
    end component;

    component fwmux1
	port (in0,in1,in2 : in std_logic_vector(31 downto 0);
	      sel : in std_logic_vector(1 downto 0);
	      out0 : out std_logic_vector(31 downto 0));
    end component;

    component fwmux2
	port (in0,in1,in2 : in std_logic_vector(31 downto 0);
	      sel : in std_logic_vector(1 downto 0);
	      out0 : out std_logic_vector(31 downto 0));
    end component;

    component immux
	port (in0,in1 : in std_logic_vector(31 downto 0);
	      sel : in std_logic_vector(0 downto 0);
	      out0 : out std_logic_vector(31 downto 0));
    end component;

    component alu
	port (in0,in1 : in std_logic_vector(31 downto 0);
	      alucontrol : in std_logic_vector(4 downto 0);
	      grafix : in std_logic_vector(31 downto 0);
	      joystick : in std_logic_vector(7 downto 0);
	      modplayer : in std_logic_vector(31 downto 0);
	      clk : in std_logic;
	      reset : in std_logic_vector(0 downto 0);
	      zero : out std_logic_vector(0 downto 0);
	      out0 : out std_logic_vector(31 downto 0);
	      overflowout : out std_logic_vector(0 downto 0));
    end component;

    component regdestmux
	port (in0,in1: in std_logic_vector(4 downto 0);
	      sel : in std_logic_vector(1 downto 0);
	      out0 : out std_logic_vector(4 downto 0));
    end component;

    component fwunit
	port (rt,rs,memregdest,wbregdest : in std_logic_vector(4 downto 0);
	      memregwr,wbregwr : in std_logic_vector(0 downto 0);
	      sel1,sel2 : out std_logic_vector(1 downto 0));
    end component;

    component pcmux3
	port (in0,in1 : in std_logic_vector(31 downto 0);
	      sel : in std_logic_vector(0 downto 0);
	      out0 : out std_logic_vector(31 downto 0));
    end component;

    component branchlogic
	port (zero : in std_logic_vector(0 downto 0);
	      instr : in std_logic_vector(2 downto 0);
	      overflow: in std_logic_vector(0 downto 0);
	      ctrpcmux1,ctrpcmux3 : out std_logic_vector(0 downto 0));
    end component;


    component ex_dmem
	port (from_proc_read_in : in std_logic_vector(0 downto 0);
	      from_proc_write_in : in std_logic_vector(0 downto 0);
	      stall_out : out std_logic_vector(0 downto 0);
	      internal_arb_out : out std_logic_vector(0 downto 0);
	      arb_in : in std_logic_vector(0 downto 0);
	      bus_req : out std_logic_vector(0 downto 0);
	      dmem_pre_write : out std_logic_vector(0 downto 0);
	      dmem_pre_read : out std_logic_vector(0 downto 0));
    end component;

    component mem_dmem
	 port (
	  to_proc_stall: out std_logic_vector(0 downto 0);
	  from_proc_read_in : in std_logic_vector(0 downto 0);
	  from_proc_write_in : in std_logic_vector(0 downto 0);
	  clk : in std_logic;
	  reset : in std_logic_vector(0 downto 0);
	  to_bus_write : out std_logic_vector(0 downto 0);
	  internal_arb_in : in std_logic_vector(0 downto 0);
	  to_arb_dmemwrite : out std_logic_vector(0 downto 0));
    end component;
    
    component datamux
	port (in0,in1,in2 : in std_logic_vector(31 downto 0);
	      sel : in std_logic_vector(1 downto 0);
	      out0 : out std_logic_vector(31 downto 0));
    end component;

    component pipereg
	generic (N : integer);
	port (in0 : in  std_logic_vector(N downto 0);
	      clk : in std_logic;
	      out0 : out std_logic_vector(N downto 0);
	      update : in std_logic_vector(0 downto 0);
	      reset : in std_logic_vector(0 downto 0));
    end component;

    component s_unit
	port (dmem_stall : in std_logic_vector(0 downto 0);
	      other_stall_1 : in std_logic_vector(0 downto 0);
	      other_stall_2 : in std_logic_vector(0 downto 0);
	      proc_stall : out std_logic_vector(0 downto 0));
	
    end component;
    
    signal stall : std_logic_vector(0 downto 0);
    signal clock : std_logic;
    signal reset : std_logic_vector(0 downto 0);
    signal
	s_if_pc1,
	s_if_pc2,
	s_if_pc3,
	s_if_pc4,
	s_if_pc5,
	s_if_pc6,
	s_if_instr : std_logic_vector(31 downto 0);
    signal
	s_if_ctrl1,
	s_if_ctrl2 : std_logic_vector(0 downto 0);
    signal
	s_memdmem_databus_in,
	s_memdmem_databus_out : std_logic_vector(31 downto 0);
    signal s_id_instr : std_logic_vector(31 downto 0);
    signal s_id_pc1 : std_logic_vector(31 downto 0);
    signal s_id_ctrlwb : std_logic_vector(2 downto 0);
    signal s_id_ctrlmem : std_logic_vector(4 downto 0);
    signal s_id_ctrlex : std_logic_vector(7 downto 0);
    signal s_id_ctrlid : std_logic_vector(1 downto 0);
    signal
	s_id_data1,
	s_id_data2,
	s_id_data3 : std_logic_vector(31 downto 0);
    signal
	s_id_sel1,
	s_id_sel2 : std_logic_vector(1 downto 0);
    signal s_ex_ctrlwb : std_logic_vector(2 downto 0);
    signal s_ex_ctrlmem : std_logic_vector(4 downto 0);
    signal
	s_ex_pc1,
	s_ex_pc7 : std_logic_vector(31 downto 0);
    signal s_ex_ctrlex : std_logic_vector(7 downto 0);
    signal
	s_ex_data1,
	s_ex_data2,
	s_ex_data3,
	s_ex_alu0,
	s_ex_alu1,
	s_ex_bengt : std_logic_vector(31 downto 0);
    signal s_ex_zero : std_logic_vector(0 downto 0);
    signal s_ex_res : std_logic_vector(31 downto 0);
    signal
	s_ex_rt,
	s_ex_rd,
	s_ex_regdest : std_logic_vector(4 downto 0);
    signal
	s_ex_sel1,
	s_ex_sel2 : std_logic_vector(1 downto 0);
    signal s_ex_overflow : std_logic_vector(0 downto 0);
    signal s_mem_ctrlwb : std_logic_vector(2 downto 0);
    signal
	s_mem_pc1,
	s_mem_pc7 : std_logic_vector(31 downto 0);
    signal s_mem_ctrlmem : std_logic_vector(4 downto 0);
    signal s_mem_res : std_logic_vector(31 downto 0);
    signal s_mem_zero : std_logic_vector(0 downto 0);
    signal s_mem_data2 : std_logic_vector(31 downto 0);
    signal s_mem_regdest : std_logic_vector(4 downto 0);
    signal s_mem_data4 : std_logic_vector(31 downto 0);
    signal s_mem_ctrl2 : std_logic_vector(0 downto 0);
    signal s_mem_overflow : std_logic_vector(0 downto 0);
    signal s_wb_regdest2 : std_logic_vector(4 downto 0);
    signal s_wb_data : std_logic_vector(31 downto 0);
    signal s_wb_ctrlwb : std_logic_vector(2 downto 0);
    signal s_wb_pc1 : std_logic_vector(31 downto 0);
    signal
	s_wb_data4,
	s_wb_res : std_logic_vector(31 downto 0);
    signal s_addrbus  : std_logic_vector(23 downto 0);
    signal
	s_dmem_stall,
	s_dmem_stall2 : std_logic_vector(0 downto 0);
    signal s_constant_not_stall : std_logic_vector(0 downto 0);
    signal
	s_ex_internal_arb,
	s_mem_internal_arb,
	s_preif_imem_arb,
	s_if_imem_arb : std_logic_vector(0 downto 0);
    
begin  					--structure_pro
	thepcmux1:pcmux1
	    port map (in0=>s_if_pc1, in1=>s_if_pc6, out0=>s_if_pc4, sel=>s_if_ctrl1);

	thepcmux2:pcmux2
	    port map (in0=>s_if_pc4, in1=>s_if_pc5, out0=>s_if_pc3, sel=>s_if_ctrl2);

	preififreg: pipereg
	    generic map (N=>0)
	    port map (in0 => s_preif_imem_arb, out0 => s_if_imem_arb, clk => clock, update => s_constant_not_stall, reset => reset);

	pc: pipereg
	    generic map (N=>31)
	    port map (in0=>s_if_pc3, out0=>s_if_pc2, clk=>clock, update=>s_constant_not_stall, reset=>reset);

	thepcadd1:pcadd1
	    port map (pc=>s_if_pc2, stall => stall, imem_arb_in => s_if_imem_arb, res=>s_if_pc1);
	
	theimem : imem
	    port map (from_proc_addr_in=>s_if_pc2(23 downto 0), to_proc_data_out=>s_if_instr, from_bus_data_in=>p_databus_in, to_bus_addr_out=>p_imem_addr_out, arb_in=>s_if_imem_arb, stall_in=>stall);

	thesunit : s_unit
	    port map (dmem_stall=>s_dmem_stall, other_stall_1=>install_1,other_stall_2=>s_dmem_stall2, proc_stall=>stall);
	
	thesignandshift:signandshift
	    port map (in0=>s_id_instr(25 downto 0), out0=>s_if_pc5);

	ifidreg1:pipereg
	    generic map (N=>31)
	    port map (in0=>s_if_instr, clk=>clock, out0=>s_id_instr, update=>stall, reset=>reset);

	ifidreg2:pipereg
	    generic map (N=>31)
	    port map (in0=>s_if_pc1, clk=>clock, out0=>s_id_pc1, update=>stall, reset=>reset);

	thectrl:ctrl
	    port map (opcode=>s_id_instr(31 downto 26), func=>s_id_instr(5 downto 0), ife=>s_if_ctrl2, wb=>s_id_ctrlwb, mem=>s_id_ctrlmem, ex=>s_id_ctrlex, id=>s_id_ctrlid);

	thereg:reg
	    port map (reset => reset, rr1=>s_id_instr(25 downto 21), rr2=>s_id_instr(20 downto 16), wr=>s_wb_regdest2, wd=>s_wb_data, rw=>s_wb_ctrlwb(0 downto 0), rd1=>s_id_data1, rd2=>s_id_data2,debug_reg1=>debug_reg, clk=>clock);

	thesignext:signext
	    port map (in0=>s_id_instr(15 downto 0), ctrin=>s_id_ctrlid, out0=>s_id_data3);

	idexreg2:pipereg
	    generic map (N=>4)
	    port map (in0=>s_id_instr(15 downto 11), clk=>clock, out0=>s_ex_rd, update=>stall, reset=>reset);

	idexreg3:pipereg
	    generic map (N=>4)
	    port map (in0=>s_id_instr(20 downto 16), clk=>clock, out0=>s_ex_rt, update=>stall, reset=>reset);

	idexreg4:pipereg
	    generic map (N=>31)
	    port map (in0=>s_id_data3, clk=>clock, out0=>s_ex_data3, update=>stall, reset=>reset);

	idexreg5:pipereg
	    generic map (N=>31)
	    port map (in0=>s_id_data2, clk=>clock, out0=>s_ex_data2, update=>stall, reset=>reset);

	idexreg6:pipereg
	    generic map (N=>31)
	    port map (in0=>s_id_data1, clk=>clock, out0=>s_ex_data1, update=>stall, reset=>reset);

	idexreg7:pipereg
	    generic map (N=>31)
	    port map (in0=>s_id_pc1, clk=>clock, out0=>s_ex_pc1, update=>stall, reset=>reset);

	idexreg8:pipereg
	    generic map (N=>7)
	    port map (in0=>s_id_ctrlex, clk=>clock, out0=>s_ex_ctrlex, update=>stall, reset=>reset);

	idexreg9:pipereg
	    generic map (N=>4)
	    port map (in0=>s_id_ctrlmem, clk=>clock, out0=>s_ex_ctrlmem, update=>stall, reset=>reset);

	idexreg10:pipereg
	    generic map (N=>2)
	    port map (in0=>s_id_ctrlwb, clk=>clock, out0=>s_ex_ctrlwb, update=>stall, reset=>reset);
	
	idexreg11 : pipereg
	    generic map (N=>1)
	    port map (in0=>s_id_sel2, clk=>clock, out0=>s_ex_sel2, update=>stall, reset=>reset);
        
        idexreg12 : pipereg
          generic map (N=>1)
          port map (in0=>s_id_sel1, clk=>clock, out0=>s_ex_sel1, update=>stall, reset=>reset);
	
	thepcadd2:pcadd2
	    port map (in0=>s_ex_pc1, in1=>s_ex_data3, out0=>s_ex_pc7);

	thefwmux1:fwmux1
	    port map (in0=>s_ex_data1, in1=>s_wb_data, in2=>s_mem_res, sel=>s_ex_sel1, out0=>s_ex_alu0);

	thefwmux2:fwmux2
	    port map (in0=>s_ex_data2, in1=>s_wb_data, in2=>s_mem_res, sel=>s_ex_sel2, out0=>s_ex_bengt);

	theimmux:immux
	    port map (in0=>s_ex_bengt, in1=>s_ex_data3, sel=>s_ex_ctrlex(5 downto 5), out0=>s_ex_alu1);

	thealu:alu
	    port map (in0=>s_ex_alu0, in1=>s_ex_alu1, alucontrol=>s_ex_ctrlex(4 downto 0), grafix=>gfx_to_alu, joystick=>joy_to_alu, modplayer=>music_to_alu, clk=>clock, reset=>inreset, zero=>s_ex_zero, out0=>s_ex_res, overflowout=>s_ex_overflow);
	
	theregdestmux:regdestmux
	    port map (in0=>s_ex_rt, in1=>s_ex_rd, sel=>s_ex_ctrlex(7 downto 6), out0=>s_ex_regdest);

	thefwunit:fwunit
	    port map (rt=>s_id_instr(20 downto 16), rs=>s_id_instr(25 downto 21), memregdest=>s_ex_regdest, wbregdest=>s_mem_regdest, memregwr=>s_ex_ctrlwb(0 downto 0), wbregwr=>s_mem_ctrlwb(0 downto 0), sel1=>s_id_sel1, sel2=>s_id_sel2);

	theemdmem : ex_dmem
	    port map (from_proc_read_in => s_ex_ctrlmem(1 downto 1),
		      from_proc_write_in => s_ex_ctrlmem(0 downto 0),
		      stall_out => s_dmem_stall,
		      internal_arb_out => s_ex_internal_arb,
		      arb_in => dmem_arb_in,
		      bus_req => dmem_bus_req,
		      dmem_pre_write => dmem_pre_write,
		      dmem_pre_read => dmem_pre_read);
	
	exmemreg1:pipereg
	    generic map (N=>4)
	    port map (in0=>s_ex_regdest, clk=>clock, out0=>s_mem_regdest, update=>stall, reset=>reset);

	exmemreg2:pipereg
	    generic map (N=>31)
	    port map (in0=>s_ex_data2, clk=>clock, out0=>s_mem_data2, update=>stall, reset=>reset);

	exmemreg3:pipereg
	    generic map (N=>31)
	    port map (in0=>s_ex_res, clk=>clock, out0=>s_mem_res, update=>stall, reset=>reset);

	exmemreg4:pipereg
	    generic map (N=>0)
	    port map (in0=>s_ex_zero, clk=>clock, out0=>s_mem_zero, update=>stall, reset=>reset);

	exmemreg5:pipereg
	    generic map (N=>31)
	    port map (in0=>s_ex_pc7, clk=>clock, out0=>s_mem_pc7, update=>stall, reset=>reset);

	exmemreg6:pipereg
	    generic map (N=>4)
	    port map (in0=>s_ex_ctrlmem, clk=>clock, out0=>s_mem_ctrlmem, update=>stall, reset=>reset);

	exmemreg7:pipereg
	    generic map (N=>31)
	    port map (in0=>s_ex_pc1, clk=>clock, out0=>s_mem_pc1, update=>stall, reset=>reset);

	exmemreg8:pipereg
	    generic map (N=>2)
	    port map (in0=>s_ex_ctrlwb, clk=>clock, out0=>s_mem_ctrlwb, update=>stall, reset=>reset);
	
	exmemreg9:pipereg
	    generic map (N=>0)
	    port map (in0=>s_ex_overflow, clk=>clock, out0=>s_mem_overflow, update=>stall, reset=>reset);

	exmemreg10 : pipereg
	    generic map (N=>0)
	    port map (in0 => s_ex_internal_arb, clk => clock, out0 => s_mem_internal_arb, update => stall, reset => reset);
	
	thepcmux3:pcmux3
	    port map (in0=>s_mem_pc7, in1=>s_mem_res, sel=>s_mem_ctrl2, out0=>s_if_pc6);

	thebranchlogic:branchlogic
	    port map (zero=>s_mem_zero, instr=>s_mem_ctrlmem(4 downto 2), ctrpcmux1=>s_if_ctrl1, ctrpcmux3=>s_mem_ctrl2, overflow=>s_mem_overflow);

	thememdmem : mem_dmem
	    port map (to_proc_stall => s_dmem_stall2,
		      from_proc_read_in => s_mem_ctrlmem(1 downto 1),
		      from_proc_write_in => s_mem_ctrlmem(0 downto 0),
		      clk => clock,
		      reset => reset,
		      to_bus_write => dmem_w_out,
		      internal_arb_in => s_mem_internal_arb,
		      to_arb_dmemwrite => dmemendbrq);
	
	memwbreg1:pipereg
	    generic map (N=>4)
	    port map (in0=>s_mem_regdest, clk=>clock, out0=>s_wb_regdest2, update=>stall, reset=>reset);

	memwbreg2:pipereg
	    generic map (N=>31)
	    port map (in0=>s_mem_res, clk=>clock, out0=>s_wb_res, update=>stall, reset=>reset);

	memwbreg3:pipereg
	    generic map (N=>31)
	    port map (in0=>s_mem_data4, clk=>clock, out0=>s_wb_data4, update=>stall, reset=>reset);

	memwbreg4:pipereg
	    generic map (N=>31)
	    port map (in0=>s_mem_pc1, clk=>clock, out0=>s_wb_pc1, update=>stall, reset=>reset);

	memwbreg5:pipereg
	    generic map (N=>2)
	    port map (in0=>s_mem_ctrlwb, clk=>clock, out0=>s_wb_ctrlwb, update=>stall, reset=>reset);

	
	thedatamux:datamux
	    port map (in0=>s_wb_res, in1=>s_wb_data4, in2=>s_wb_pc1, sel=>s_wb_ctrlwb(2 downto 1), out0=>s_wb_data);

	debug_pc  <= s_if_pc2;
	debug_instr <= s_id_instr;
	debug_alu1in <= s_ex_alu0;
	debug_alu2in <= s_ex_alu1;
	debug_aluut <= s_ex_res;
	debug_ctrl <= s_if_ctrl2 & s_id_ctrlwb & s_id_ctrlmem & s_id_ctrlex & s_id_ctrlid;
		      
	
	s_constant_not_stall <= "1";
	s_preif_imem_arb <= imem_arb_in;
		
	clock<=inclock;
	reset<=inreset;

	p_memdmem_databus_out <= s_mem_data2;
	p_dmem_addr_out<=s_mem_res(23 downto 0);
	s_mem_data4<=p_databus_in;		
		   	
end structure_pro;










