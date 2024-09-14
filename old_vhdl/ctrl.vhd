 -- updaterad av JP 2000-11-25

library IEEE;
use IEEE.STD_LOGIC_1164.all;
entity ctrl is
    
    port (opcode : in std_logic_vector(5 downto 0);
	  func : in std_logic_vector(5 downto 0);
	  ife : out std_logic_vector(0 downto 0);
	  id : out std_logic_vector(1 downto 0);
	  ex : out std_logic_vector(7 downto 0);
	  mem : out std_logic_vector(4 downto 0);
	  wb : out std_logic_vector(2 downto 0) );

end ctrl;


-- purpose: processorns kontroll
architecture ctrl_behavioral of ctrl is
begin 
    process (opcode, func)
	
    begin  -- process
	-- ife: pcmux2.sel
	-- id: signext.ctrin
	-- ex: 7:6 regdestmux, 5:5 imux, 4:0 alu.control
	-- mem: 4:2 branchlogic.intr , 1:1 mem.re, 0:0 mem.we
	-- wb: 2:1 dmux.sel 2:2 jalmux.sel, 0:0 registerwrite
	ife<="0";
	id<="00";
	ex<="00000000";
	mem<="00000";
	wb<="000";
	case opcode is
	    when "000000" => case func is
				 when "000000" => ife<="0";  --nop,sll
						  id<="00";
						  ex<="01101000";  -- ändrat010227mchmsv
						  mem<="00000";
						  wb<="001";
				 when "100001" => ife<="0";  --addu
						  id<="00";
						  ex<="01010001";
						  mem<="00000";
						  wb<="001";
		                 when "100100" => ife<="0";  --and
						  id<="00";
						  ex<="01010100";
						  mem<="00000";
						  wb<="001";
				 when "100000" => ife<="0";  --add
						  id<="00";
						  ex<="01010000";
						  mem<="00000";
						  wb<="001";
				 when "100111" => ife<="0";  --nor
						  id<="00";
						  ex<="01010111";
						  mem<="00000";
						  wb<="001";
				 when "100101" => ife<="0";  --or
						  id<="00";
						  ex<="01010101";
						  mem<="00000";
						  wb<="001";
--				 when "000000" => ife<="0";  --sll
	--					  id<="11";
		--				  ex<="011XXXXX";
		--				  mem<="00000";
			--			  wb<="001";
				 when "000100" => ife<="0";  --sllv
						  id<="00";
						  ex<="01001100";
						  mem<="00000";
						  wb<="001";
				 when "000011" => ife<="0";  --sra
						  id<="11";
						  ex<="01101011";
						  mem<="00000";
						  wb<="001";
				 when "000111" => ife<="0";  --srav
						  id<="00";
						  ex<="01000111";
						  mem<="00000";
						  wb<="001";
				 when "000010" => ife<="0";  --srl
						  id<="11";
						  ex<="01101010";
						  mem<="00000";
						  wb<="001";
				 when "000110" => ife<="0";  --srlv
						  id<="00";
						  ex<="01001110";
						  mem<="00000";
						  wb<="001";
				 when "100010" => ife<="0";  --sub
						  id<="00";
						  ex<="01010010";
						  mem<="00000";
						  wb<="001";
				 when "100011" => ife<="0";  --subu
						  id<="00";
						  ex<="01010011";
						  mem<="00000";
						  wb<="001";
				 when "100110" => ife<="0";  --xor
						  id<="00";
						  ex<="01010110";
						  mem<="00000";
						  wb<="001";
				 when "101010" => ife<="0";  --slt
						  id<="00";
						  ex<="01011010";
						  mem<="00000";
						  wb<="001";
				 when "101011" => ife<="0";  --sltu
						  id<="00";
						  ex<="01011011";
						  mem<="00000";
						  wb<="001";
				 when "001001" => ife<="0";  --jalr
						  id<="00";
						  ex<="10000011";
						  mem<="01100";
						  wb<="101";
				 when "001000" => ife<="0";  --jr
						  id<="00";
						  ex<="01000011";
						  mem<="01100";
						  wb<="000";
		
				 when others  => null; 
			     end case;
	    when "001000" => ife<="0";  --addi
			     id<="00";
			     ex<="00110000";
			     mem<="00000";
			     wb<="001";
	    when "001001" => ife<="0";  --addiu
			     id<="01";
			     ex<="00110001";
			     mem<="00000";
			     wb<="001";
	    when "001100" => ife<="0";  --andi
			     id<="10";
			     ex<="00110100";
			     mem<="00000";
			     wb<="001";
	    when "001101" => ife<="0";  --ori
			     id<="11";
			     ex<="00110101";
			     mem<="00000";
			     wb<="001";
	    when "001110" => ife<="0";  --xori
			     id<="11";
			     ex<="00110110";
			     mem<="00000";
			     wb<="001";
	    when "001111" => ife<="0";  --lui
			     id<="11";
			     ex<="00101111";
			     mem<="00000";
			     wb<="001";
	    when "001010" => ife<="0";  --slti
			     id<="00";
			     ex<="00111010";
			     mem<="00000";
			     wb<="001";
	    when "001011" => ife<="0";  --sltiu
			     id<="01";  
			     ex<="00111011";
			     mem<="00000";
			     wb<="001";
	    when "000100" => ife<="0";  --beq
			     id<="00";  
			     ex<="00010010";
			     mem<="00100";
			     wb<="000";
	    when "000001" => ife<="0";  --bge
			     id<="00";  
			     ex<="00010010";
			     mem<="10100";
			     wb<="000";
	    when "000111" => ife<="0";  --bgt
			     id<="00";  
			     ex<="00010010";
			     mem<="11000";
			     wb<="000";			    
	    when "000101" => ife<="0";  --bne not completed
			     id<="00";  
			     ex<="00010010";
			     mem<="01000";
			     wb<="000";
	    when "000010" => ife<="1";  --j
			     id<="01";
			     ex<="00000000";
			     mem<="00000";
			     wb<="000";
	    when "000011" => ife<="1";  --jal
			     id<="01";
			     ex<="10000000";
			     mem<="00000";
			     wb<="101";  
	    when "010000" => ife<="0";   --mfc0
			     id<="00";
			     ex<="01011100";  -- rd är destinationen
			     mem<="00000";
			     wb<="001";
	    when "010001" => ife<="0";  	--mfc1
			     id<="00";
			     ex<="01011101";
			     mem<="00000";
			     wb<="001";
	    when "010010" => ife<="0";  	--mfc2
			     id<="00";
			     ex<="01011110";
			     mem<="00000";
			     wb<="001";
	    when "010011" => ife<="0";  	--mfc3
			     id<="00";
			     ex<="01011111";
			     mem<="00000";
			     wb<="001";
	    when "100011" => ife<="0";  --lw
			     id<="01";
			     ex<="00110000";
			     mem<="00010";
			     wb<="011";
	    when "101011" => ife<="0";  --sw
			     id<="01";
			     ex<="00110000";
			     mem<="00001";
			     wb<="000";  
	    when others => null;
	end case;
    end process;
end ctrl_behavioral;


